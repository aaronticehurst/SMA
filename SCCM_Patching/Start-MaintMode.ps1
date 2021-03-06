Workflow Start-MaintMode {

    <#
.Synopsis
   Start maint mode for server in SCOM
.DESCRIPTION
   Start maint mode for server in SCOM, reason is a predeined mandatory list tab to cycle through the list.
.EXAMPLE
   Start-MaintMode -ComputerName COMPUTERNAME -Reason SecurityIssue -Comment "Maint 48837" -Hours 3
#>

    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,
            Position=0)]
            
        [String[]]$ComputerName,
        [parameter(Mandatory=$true,
            Position=1)]
        [String]$Reason,
        [parameter(Mandatory=$true,
            Position=2)]
        [String]$Comment,
        [parameter(Mandatory=$true,
            Position=3)]
        [INT]$Hours
    )

    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'
    [String[]]$SCOMServer = 'scom server'

    Foreach ($Computer in $ComputerName) {
        #
        $FQDN = [System.Net.Dns]::GetHostByName(($Computer)).HostName.ToString() 

        InlineScript {
            $FQDN = $Using:FQDN
            $Hours = $USING:Hours
            $Reason = $USING:Reason
            $Comment = $Using:Comment

            Invoke-Command -Scriptblock {
                Param($FQDN, $Hours, $Reason, $Comment)
            
                Import-Module "C:\Program Files\Microsoft System Center 2012 R2\Operations Manager\Powershell\OperationsManager\OperationsManager.psm1"
                $Instance = Get-SCOMClassInstance -Name $FQDN
                $Time = ((Get-Date).AddHours($Hours))                                                                                      
                Start-SCOMMaintenanceMode -Instance $Instance -EndTime $Time -Reason $Reason -Comment $Comment 
            

            } -ComputerName $Using:SCOMServer -ArgumentList $FQDN, $Hours, $Reason, $Comment -Credential $USING:Patching_Creds
        }
    }

}
