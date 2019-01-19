<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

.SYNOPSIS
This script creates a new environment in the lab using an existing environment template.
.PARAMETER SubscriptionId
The subscription ID that is to be deployed to.
.PARAMETER LabName
The name of the DevTest Lab.
.PARAMETER BaseSystemName
The name of the Domain join system
.PARAMETER SystemLocation
The location for the Domain join system
.PARAMETER ServicePrincipalPassword
The password for the service principal
.PARAMETER ArtifactRepo
The DevTest Lab artifact repository uri.
.PARAMETER ArtifactRepoPAT
The access token for the DevTest Lab artifact repository
.NOTES
The script assumes that a lab exists

#>


Param(
    [string] $subscriptionId,
    [string] $subscriptionName, 
    [string] $devTestLabName, 
    [string] $baseSystemName,
    [string] $systemLocation,
    [string] $servicePrincipalPassword,
    [string] $ArtifactRepo,
    [string] $ArtifactRepoPAT
)


#Install-Module -Name Az -AllowClobber -Force
#Install-Module -Name Az.Resources -AllowClobber -Force

Import-Module -Name Az
Import-Module -Name Az.Resources

Connect-AzAccount

$subInformation = Set-AzContext -Subscription $subscriptionName

# Create Service Principal
$SecureStringPassword = ConvertTo-SecureString -String $servicePrincipalPassword  -AsPlainText -Force
$app = New-AzADApplication -DisplayName $($baseSystemName + "service") -IdentifierUris "http://$($baseSystemName)/service" -Password $SecureStringPassword
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $app.ApplicationId
$roleResult = New-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName "Contributor" -Scope /subscriptions/$($subInformation.Subscription.Id)


#PAT token for lab repo connection
$securePAT = ConvertTo-SecureString -String $ArtifactRepoPAT -AsPlainText -Force 

# Create the resource group 
New-AzResourceGroup -Name $baseSystemName -Location $systemLocation
New-AzResourceGroup -Name $devTestLabName -Location $systemLocation

$systemlocalFile = Join-Path $PSScriptRoot -ChildPath "DeploySystem.json"
$lablocalFile = Join-Path $PSScriptRoot -ChildPath "DeployDTLab.json"
$gridlocalFile = Join-Path $PSScriptRoot -ChildPath "DeployEventGrid.json"

$keyVaultName = $baseSystemName + "kv"

$deployName = $baseSystemName + "lab"

# Create Lab
$labDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $devTestLabName -TemplateFile $lablocalFile -devTestLabName $devTestLabName -artifactRepoUri $ArtifactRepo -artifactRepoSecurityToken $securePAT

# Create System
$deployName = $baseSystemName + "system"
$systemDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $baseSystemName -TemplateFile $systemlocalFile -devTestLabName $devTestLabName -keyVaultName $keyVaultName -appName $($baseSystemName + 'app') -servicePrincipalAppId $($app.ApplicationId.Guid.ToString()) -servicePrincipalAppKey $servicePrincipal.Secret  # $(ConvertTo-SecureString -String $password -AsPlainText -Force)

# Get FunctionApp masterkey and create event grid connection.
$deployName = $baseSystemName + "eventgrid"

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($($servicePrincipal.Secret))
$servicePrincipalSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$authUri = "https://login.microsoftonline.com/$($subInformation.Tenant.Id)/oauth2/token?api-version=1.0"
$resourceUri = "https://management.core.windows.net/"

$authRequestBody = @{}
$authRequestBody.grant_type = "client_credentials"
$authRequestBody.resource = $resourceUri
$authRequestBody.client_id = $($servicePrincipal.ApplicationId)
$authRequestBody.client_secret = $servicePrincipalSecret

$auth = Invoke-RestMethod -Uri $authUri -Method Post -Body $authRequestBody

$accessTokenHeader = @{ "Authorization" = "Bearer " + $auth.access_token }

$azureRmBaseUri = "https://management.azure.com"
$azureRmApiVersion = "2016-08-01"
$azureRmResourceId = "/subscriptions/$subscriptionId/resourceGroups/$baseSystemName/providers/Microsoft.Web/sites/$($baseSystemName + 'app')"
$azureRmAdminBearerTokenEndpoint = "/functions/admin/token"
$adminBearerTokenUri = $azureRmBaseUri + $azureRmResourceId + $azureRmAdminBearerTokenEndpoint + "?api-version=" + $azureRmApiVersion

$adminBearerToken = Invoke-RestMethod -Method Get -Uri $adminBearerTokenUri -Headers $accessTokenHeader

$functionAppBaseUri = "https://$($baseSystemName + 'app').azurewebsites.net/admin"
#$functionName = "EnableVmMSIFunction"
#$functionKeysEndpoint = "/functions/$functionName/keys"
#$functionKeysUri = $functionAppBaseUri + $functionKeysEndpoint

#$hostKeysEndpoint = "/host/keys"
#$hostKeysUri = $functionAppBaseUri + $hostKeysEndpoint

$masterKeyEndpoint = "/host/systemkeys/_master"
$masterKeyUri = $functionAppBaseUri + $masterKeyEndpoint

$adminTokenHeader = @{ "Authorization" = "Bearer " + $adminBearerToken }

#$functionKeys = Invoke-RestMethod -Method Get -Uri $functionKeysUri -Headers $adminTokenHeader
#$hostKeys = Invoke-RestMethod -Method Get -Uri $hostKeysUri -Headers $adminTokenHeader
$masterKeys = Invoke-RestMethod -Method Get -Uri $masterKeyUri -Headers $adminTokenHeader

#$funcUri = $('https://' + $baseSystemName + 'app.azurewebsites.net/runtime/webhooks/EventGrid?functionName=EnableVmMSIFunction&code=' + $($hostKeys.keys[0].value))
$funcUri = $('https://' + $baseSystemName + 'app.azurewebsites.net/runtime/webhooks/EventGrid?functionName=EnableVmMSIFunction&code=' + $($masterKeys.value))

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

$deployEventGrid = New-AzDeployment -Name $deployName -Location $systemLocation -TemplateFile $gridlocalFile  -eventSubname $($devTestLabName + "grid") -endpoint $funcUri

