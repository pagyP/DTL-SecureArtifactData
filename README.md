# Overview
This solution allows DevTest Lab artifacts access to secrets secured in Key Vaults outside of the lab.
This uses several different Azure resources including:
-	DevTest Lab
-	Function Apps
-	Event Grid
-	Key Vault
The Azure DevTest Lab will include a custom artifact that will access the secrets in the Key Vault via the Azure manage system identity.  The execution of this artifact will trigger a custom script extension event.  The Function app is connected to an event grid when the app receives the event it will enable the identity on the VM and add that identity to the access policy of the key vault.  After a set time (4 minutes) the function app will disable the VM identity and remove the identity from the access policy.  During this time span the artifact will be able to get the appropriate token and access the key vault secrets, then execute the necessary installation or domain-join with the data.  

# Setup
## Subscription
The subscription will need to be setup so that the owners and contributor roles are users that need access to the key vault data.  Owner and contributor roles will be able to modify the access policy on the key vault to gain access.  The subscription owner needs to deploy this solution to the subscription as it requires granting access to different resources, which cannot be done by the contributor role.  The users will be part of the DevTest Lab user roles within the lab.
## Lab
The lab will need to be setup with the users in the DevTest lab user role and will need to be configured to have all the virtual machines in a common resource group, the resource group that the lab is located in.  The lab owner will need to have the owner role on the resource group which will allow them to grant access to the other users, manage the lab, and grant the function app access to the resource group.  Having the lab owner have owner access on the resource group does not allow them owner access at the subscription level, they would not have access to the key vault access policy.
## Key Vault
An independent resource group will need to be setup where the Key vault will be created.  The Access control (IAM) for the Key Vault will need to include the Function App identity in the contributor role.  This will allow the Function app to add and remove the different VM Identities from the access policy of the secrets.
## Function App
The Function app will be created in the same resource group as the Key vault to keep these two resources together as a unit.  The Function app can be either consumption or app service based but will need to have the Manage System identity enabled to allow it access to the lab resource group and the key vault access control.  The Function app will be connected to an event grid.
## Event grid
If you are using a single lab you can setup the event grid to the single resource group for the lab and VMs.  If you are going to have more than one lab, create the Event grid to the subscription level and enable subject filtering where the end of the subject is the artifact folder name.  In this example that would be windows-domain-join-secure.  This will reduce the number to events that the function app will need to handle.

# Coding
## DevTest lab artifact
The DevTest lab artifact is a PowerShell script that has a do-while with a try catch block where an Invoke-WebRequest tries to get the identity token for the VM.  Once the token is returned, it is used to get the different secrets from the Key Vault.  The reason for the looping is that when the artifact is executed an Azure event is created which initiates the Function App but the artifact needs to wait for the Function app to enable the identity and add it to the key vault.  In this example the artifact is to domain join the VM.
## Function App code
The Function app identifies the correct custom script event based on the event type, the operation name, and the resource uri.  As the DevTest Lab doesn’t have specific events determining the most appropriate event is difficult.  In this example the artifact is executed as a custom script extension which can be used as the trigger event. The function determines the VM(s) that the artifact is being installed on and enables the identity on that VM(s).  Once the identity is returned this is added to the Key Vault access policy allowing access to get the secret information.  After a delay the VM identity is disabled and the Key Vault access policy is updated to remove the identity.
# Finally
## Customizations
While this example has been specific to a domain join scenario, the pattern, of using the Function App as the access manager, can be used in other scenarios depending of your needs.  The artifact can be easily customized to install other software, gain access to secure locations, or modify Azure resources.

The master branch uses a Service principal that has contributor access to the subscription
The NoServicePrincipal branch uses the Managed Identity of that Function App that has contributor access to the resource group(s) where the VMs are located.