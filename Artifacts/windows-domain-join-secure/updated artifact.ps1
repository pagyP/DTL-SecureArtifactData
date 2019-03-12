[CmdletBinding()]
param
(
)


###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    Write-Host 'Artifact failed to apply.'
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#


###################################################################################################
#
# Main execution block.
#
$MaxRetries = 30
$currentRetry = 0
$success = $false
$DomainToJoin = "mydomain.com"
$KeyVaultName = "testkeyvault"

Write-Host "Start: " + $(Get-Date)

$DomainAdminPassword = $null
$DomainAdminUsername = $null


do {
    try
    {
        if ($PSVersionTable.PSVersion.Major -lt 3)
        {
            throw "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
        }
        
        # Get KeyVault token        
        $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"} -UseBasicParsing
        Write-Host "Success: " + $(Get-Date)
        $content = $response.Content | ConvertFrom-Json
        $KeyVaultToken = $content.access_token

        # Get credentials
        $result = (Invoke-WebRequest -Uri "https://$KeyVaultName.vault.azure.net/secrets/TestAccountCredential?api-version=2016-10-01" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"} -UseBasicParsing).content
        $begin = $result.IndexOf("value") + 8
        $endlength = ($result.IndexOf('"',$begin) -10)
        $DomainAdminPassword = $result.Substring($begin,$endlength)

        # Get Account
        $result = (Invoke-WebRequest -Uri "https://$KeyVaultName.vault.azure.net/secrets/TestAccountUser?api-version=2016-10-01" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"} -UseBasicParsing).content
        $begin = $result.IndexOf("value") + 8
        $endlength = ($result.IndexOf('"',$begin) -10)
        $tempname = $result.Substring($begin,$endlength)
        $DomainAdminUsername = $tempname.Replace("\\","\")
        Write-Host "Account Name: $DomainAdminUsername"

        if (($DomainAdminUsername -ne $null) -and ($DomainAdminPassword -ne $null)) {
            $success = $true
        }
        else {
            write-Host "KeyVault requests succeeded, but domain information is null."
        }
    }
    catch {
        $currentRetry = $currentRetry + 1
        Write-Host "In catch $currentRetry $(Get-Date)"
        if ($currentRetry -gt $MaxRetries) {
            #throw "Failed Max retries"
            Write-Host "Failed Max retries"
            break
        } else {
            Start-Sleep -Seconds 60
        }
    }
    
} while (!$success)

# Execute the domain join
if ($success) {
    if (($DomainAdminUsername -ne $null) -and ($DomainAdminPassword -ne $null)) {

        Write-Host "Attempting to join computer $($Env:COMPUTERNAME) to domain $DomainToJoin."
        $securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force

        if ((Get-WmiObject Win32_ComputerSystem).Domain -eq $DomainToJoin)
            {
                Write-Host "Computer $($Env:COMPUTERNAME) is already joined to domain $DomainToJoin."
            }
            else
            {
                
                $credential = New-Object System.Management.Automation.PSCredential($DomainAdminUsername, $securePass)
        
                [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -DomainName $DomainToJoin -Credential $credential -Force -PassThru -Verbose
        
                if (-not $computerChangeInfo.HasSucceeded)
                {
                    throw "Failed to join computer $($Env:COMPUTERNAME) to domain $DomainToJoin."
                }
        
                Write-Host "Computer $($Env:COMPUTERNAME) successfully joined domain $DomainToJoin."
            }

        Write-Host 'Artifact applied.'

        }
    else {
        throw "Missing Domain join information."
    }

} else {
    throw "Domain Join Artiffact failed to retrieve Domain information."
}
