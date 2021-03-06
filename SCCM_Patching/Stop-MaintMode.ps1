WorkFlow Stop-MaintMode {

    <#
.Synopsis
   Stop maint mode for server in SCOM
.DESCRIPTION
   Stop maint mode for server in SCOM, reason is a predeined mandatory list tab to cycle through the list.
.EXAMPLE
   Stop-MaintMode -ComputerName COMPUTERNAME
#>

    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true,
            Position=0)]
        [String[]]$ComputerName
    )

    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'
    [String[]]$SCOMServer = 'isp-osb-scom2'

    Foreach ($Computer in $ComputerName) {

        $FQDN = [System.Net.Dns]::GetHostByName(($Computer)).HostName.ToString() 
        InlineScript {
            $FQDN = $Using:FQDN
            Invoke-Command {
                Param($FQDN)
        
                Import-Module "C:\Program Files\Microsoft System Center 2012 R2\Operations Manager\Powershell\OperationsManager\OperationsManager.psm1"
                $class = get-scomclass -name:’Microsoft.Windows.Computer’
                $ComputerInstance = get-scomclassinstance -class $class | where{$_.name -eq $FQDN}
                $ComputerInstance.StopMaintenanceMode([DateTime]::Now.ToUniversalTime(),[Microsoft.EnterpriseManagement.Common.TraversalDepth]::Recursive);
                        
                                                                            

            } -ComputerName $Using:SCOMServer -ArgumentList $FQDN -Credential $USING:Patching_Creds
        }
    }



}


