# DTL-SecureArtifactData
System to allow DTL artifact access to keyvault data

## EnableVmMSI
Contains the function app code to enable the VM identity and add the Key Vault access policy

## Deployment
Contains different deployment scripts
- DeployAll - NoSP.ps1 : Uses AZ modules to deploy all the necessary resources using
    - DeploySystem - NoSP.json : ARM template for the Key Vault and Function App.
    - DeployDTLab - NoSP.json : ARM template for the DevTest Lab.
    - DeployEventGrid.json : ARM template for the Event Grid.
- DeploySystem - NoSP.ps1 : Uses AZ modules to deploy just the Key Vault and Function App.
- DeploySingleLab - NoSP.ps1 : Uses AZ modules to deploy a DevTest Lab.
- UpdateDTLCommonRG.ps1 : Update and existing DevTest Lab to use a common Resource group for VMs.
- Other ARM Templates
    - DeployDTLab - NoSP - DiffRG.json : Deploy a DevTest Lab to use a different Resource group for VMs other than the Lab RG.
    - DeployDTLabExistingVNet - NoSP.json : Deploy a DevTest Lab using an existing VNet.

## Artifacts
Contains the DevTest Lab custom artifact for doing a domain join using the credentials from the KeyVault secrets.
