
###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################

#Get VM MetaData
$vmInfo = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET  -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
$rgName = $vmInfo.compute.resourceGroupName
$vmName = $vmInfo.compute.name
$location = $vmInfo.compute.location
$storageType = 'StandardSSD_LRS'
$dataDiskName = $vmName + '_datadisk1'
$dataDiskSize = "128"

#Get full resource ID and split out the subscription ID
$Inputstring = $vmInfo.compute.resourceid
$CharArray =$InputString.Split("/")
$subID = $CharArray[2]


#Get Access Token  - VM must have a managed identity configured       
Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"} -UseBasicParsing


Connect-AzAccount -Identity
Select-AzSubscription -SubscriptionId $subID

$diskConfig = New-AzDiskConfig -SkuName $storageType -Location $location -CreateOption Empty -DiskSizeGB $dataDiskSize
$dataDisk1 = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName 

$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName
Add-AzVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1

Update-AzVM -VM $vm -ResourceGroupName $rgName -AsJob


#When running non-interactively the above Update-Azvm never seemed to complete.  It is now run with -asjob and the below sleep should be enough time for update-azvm to complete
Start-Sleep -Seconds 120


#Get raw disks and format
$disks = Get-Disk | Where-Object partitionstyle -eq 'raw' | Sort-Object number

    $letters = 70..89 | ForEach-Object { [char]$_ }
    $count = 0
    $labels = "data1","data2"

    foreach ($disk in $disks) {
        $driveLetter = $letters[$count].ToString()
        $disk |
        Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$count] -Confirm:$false -Force
	$count++
    }