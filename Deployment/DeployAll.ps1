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
.NOTES
The script assumes that a lab exists

#>

Param(
    [string] $subscriptionId = 'da8f3095-ac12-4ef2-9b35-fcd24842e207',
    [string] $subscriptionName = 'RBEST - Microsoft Internal Consumption', 
    [string] $devTestLabName = 'DomainJoinLab', 
    [string] $baseSystemName = 'dtljoin',
    [string] $systemLocation = 'Westus2',
    [string] $servicePrincipalPassword = 'thisIsATest$$4'

)


#Install-Module -Name Az -AllowClobber -Force
#Install-Module -Name Az.Resources -AllowClobber -Force

Import-Module -Name Az
Import-Module -Name Az.Resources

#Connect-AzAccount

$subInformation = Set-AzContext -Subscription $subscriptionName

# Create Service Principal
$SecureStringPassword = ConvertTo-SecureString -String $servicePrincipalPassword  -AsPlainText -Force
$app = New-AzADApplication -DisplayName $($baseSystemName + "service") -IdentifierUris "http://$($baseSystemName)/service" -Password $SecureStringPassword
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $app.ApplicationId

# Create the resource group 
New-AzResourceGroup -Name $baseSystemName -Location $systemLocation
New-AzResourceGroup -Name $devTestLabName -Location $systemLocation

$systemlocalFile = Join-Path $PSScriptRoot -ChildPath "DeploySystem.json"

$lablocalFile = Join-Path $PSScriptRoot -ChildPath "DeployDTLab.json"

$gridlocalFile = Join-Path $PSScriptRoot -ChildPath "DeployEventGrid.json"

$keyVaultName = $baseSystemName + "kv"


$deployName = $baseSystemName + "lab"

$labDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $devTestLabName -TemplateFile $lablocalFile -devTestLabName $devTestLabName

$deployName = $baseSystemName + "system"

$systemDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $baseSystemName -TemplateFile $systemlocalFile -devTestLabName $devTestLabName -keyVaultName $keyVaultName -appName $($baseSystemName + 'app') -servicePrincipalAppId $($app.ApplicationId.Guid.ToString()) -servicePrincipalAppKey $servicePrincipal.Secret  # $(ConvertTo-SecureString -String $password -AsPlainText -Force)

$deployName = $baseSystemName + "eventgrid"

$systemDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $baseSystemName -TemplateFile $gridlocalFile -eventSubname $($devTestLabName + "grid") -endpoint $($baseSystemName + 'app.azurewebsites.net/runtime/webhooks/EventGrid')


New-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName "Contributor" -Scope /subscriptions/$($subInformation.Subscription.Id)


Write-Output $vmDeployResult

