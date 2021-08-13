$rgName = 'test-rg1'
$vmName = [System.Net.Dns]::GetHostName()

Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"} -UseBasicParsing

Connect-AzAccount -Identity
Select-AzSubscription -SubscriptionId $subscriptionID

$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName
Update-AzVM -VM $vm -ResourceGroupName $rgName
 

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