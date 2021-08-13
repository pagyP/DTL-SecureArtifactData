$rgName = 'test-rg1'
$vmName = [System.Net.Dns]::GetHostName()
$location = 'NorthEurope'
$storageType = 'StandardSSD_LRS'
$dataDiskName = $vmName + '_datadisk1'
$subscriptionID = '6d82d6cd-2bcc-4588-8db1-1e2c8c763f56'

#$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"} -UseBasicParsing
 #       Write-Host "Success: " + $(Get-Date)
        Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"} -UseBasicParsing
        #$content = $response.Content | ConvertFrom-Json
        

Connect-AzAccount -Identity
Select-AzSubscription -SubscriptionId $subscriptionID

$diskConfig = New-AzDiskConfig -SkuName $storageType -Location $location -CreateOption Empty -DiskSizeGB 128 
$dataDisk1 = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName 

$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName
 Add-AzVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1

 Update-AzVM -VM $vm -ResourceGroupName $rgName
# Get-ChildItem

#Start-Sleep -Seconds 30