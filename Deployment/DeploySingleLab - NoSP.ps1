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
.PARAMETER devTestLabName
The name of the DevTest Lab.
.PARAMETER devTestLabRG
The name of the Lab Resource group
.PARAMETER SystemLocation
The location for the lab
.PARAMETER UseExistingVnet
The switch if using an existing VNest
.PARAMETER ExistingVNetId
The existing VNet resource Id
.PARAMETER ExistingSubnetName
The VNet subnet name to connect the lab to.
.NOTES
The script assumes that a lab does not exists

#>


Param(
    [Parameter(Mandatory=$true, ParameterSetName = "New")]
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $subscriptionId,
    [Parameter(Mandatory=$true, ParameterSetName = "New")]
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $devTestLabName,
    [Parameter(Mandatory=$true, ParameterSetName = "New")]
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $devTestLabRG,
    [Parameter(Mandatory=$true, ParameterSetName = "New")]
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $systemLocation,
    [Parameter(Mandatory=$false, ParameterSetName = "New")]
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [switch] $UseExistingVnet,    
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $ExistingVNetId,
    [Parameter(Mandatory=$true, ParameterSetName = "Exist")]
    [string] $ExistingSubnetName
)


Install-Module -Name Az -AllowClobber -Force
Install-Module -Name Az.Resources -AllowClobber -Force

Import-Module -Name Az
Import-Module -Name Az.Resources

Login-AzAccount

$subInformation = Set-AzContext -Subscription $subscriptionId

# Create the resource group 
New-AzResourceGroup -Name $devTestLabRG -Location $systemLocation
$deployName = "deploy-$devTestLabName"

if ($UseExistingVnet) {
    
    $lablocalFile = Join-Path $PSScriptRoot -ChildPath "DeployDTLabExistingVNet - NoSP.json"
    
    # Create Lab
    $labDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $devTestLabRG -TemplateFile $lablocalFile -devTestLabName $devTestLabName -existingVirtualNetworkId $ExistingVNetId -existingSubnetName $ExistingSubnetName


} else {
    $lablocalFile = Join-Path $PSScriptRoot -ChildPath "DeployDTLab - NoSP.json"
    
    # Create Lab
    $labDeployResult = New-AzResourceGroupDeployment -Name $deployName -ResourceGroupName $devTestLabRG -TemplateFile $lablocalFile -devTestLabName $devTestLabName

}

Write-Output "Completed $devTestLabName $($labDeployResult.ProvisioningState)"