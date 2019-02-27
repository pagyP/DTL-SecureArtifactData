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
The script assumes that a lab does not exists

#>


Param(
    [Parameter(Mandatory=$true)][string] $subscriptionId,
    [Parameter(Mandatory=$true)][string] $devTestLabName,
    [Parameter(Mandatory=$true)][string] $devTestLabRG,
    [Parameter(Mandatory=$true)][string] $targetVMRG
)

# Assumes Azure CLI installed https://aka.ms/installazurecliwindows
az login

az account set --subscription $subscriptionId

#Set the new resource group Id
$rgId = "/subscriptions/"+$subscriptionId+"/resourceGroups/"+$targetVMRG

az resource update -g $devTestLabRG -n $devTestLabName --resource-type "Microsoft.DevTestLab/labs" --api-version 2018-10-15-preview --set properties.vmCreationResourceGroupId=$rgId

Write-Host "Done. New virtual machines will now be created in the resource group '$targetVMRG'."

