WorkFlow Test-PatchingReadiness {
    <#
CSV is in the right location *
Is each server reachable
Is each server accessible via WMI (including sccm api checks)
Is each server a vm or physical (for snapshotting)
Is each server in scom
#>

    [CmdletBinding()]
    param (
				
        [Parameter(Mandatory=$True,
            ValueFromPipelineByPropertyName=$true,
            Position=1)]
        [String]$ConfigPath
    )


    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'
    [String[]]$HostServer  = 'vcenter servers'
    [String[]]$SCOMServer = 'SCOMServer'


    #CSV is in the right location
    $TestPath = Test-path $ConfigPath -ErrorAction Continue


    If ($TestPath) {
        Write-Output "$(Get-Date -Format G) Test if CSV is reachable: Succeeded" 
        $PathToConfig = Import-csv -path $ConfigPath 

        #Test that the CSV properties are not empty

        if (($PathToConfig.ComputerName | select -first 1) -notmatch '^$') {
            Write-Output "$(Get-Date -Format G) CSV Computername OK"
        } 
        Else {
            Write-Output "$(Get-Date -Format G) WARNING CSV ComputerName NOT OK"
        }
        if (($PathToConfig.SnapShotDescription | select -first 1) -notmatch '^$') {
            Write-Output "$(Get-Date -Format G) CSV SnapShotDescription OK"
        } 
        Else {
            Write-Output "$(Get-Date -Format G) WARNING CSV SnapShotDescription NOT OK"
        }
        if (($PathToConfig.Reason | select -first 1) -notmatch '^$') {
            Write-Output "$(Get-Date -Format G) CSV Reason OK"
        } 
        Else {
            Write-Output "$(Get-Date -Format G) WARNING CSV Reason NOT OK"
        }
        if (($PathToConfig.Comment | select -first 1) -notmatch '^$') {
            Write-Output "$(Get-Date -Format G) CSV Comment OK"
        } 
        Else {
            Write-Output "$(Get-Date -Format G) WARNING CSV Comment NOT OK"
        }
        if (($PathToConfig.MaintNo | select -first 1) -notmatch '^$') {
            Write-Output "$(Get-Date -Format G) CSV MaintNo OK"
        } 
        Else {
            Write-Output "$(Get-Date -Format G) WARNING CSV MaintNo NOT OK"
        }

        Write-output $PathToConfig | Foreach-Object { Write-output "$(Get-Date -Format G) Testing $($_.Computername)"}

        Foreach ($Computer in $PathToConfig.ComputerName )  { 

            #Check that the computer matches what we are targetting. The Name would have been better but does not reset when computer renamed aka isp-osb-navback ->isp-osb-navback1
            $DNSCheck = Get-WmiObject -PSComputerName $Computer -Class win32_computersystem -PSCredential $Patching_Creds 
            If ($DNSCheck.DNSHostName -eq ($Computer -split '(?=\.)')[0]) {
                "$(Get-Date -Format G) $($Computer): DNS response OK"
            }
            Else {
                "$(Get-Date -Format G) $($Computer): FAIL: DNS response NOT OK"
            }

            #Is each server reachable
            Write-Verbose "$(Get-Date -Format G) $($Computer): testing ping and WMI connectivity"
            $PingTest = Test-Connection -ComputerName $Computer -Quiet -ErrorAction Continue
            If ($PingTest)  {
                Write-Output "$(Get-Date -Format G) $($Computer): is pingable"
            }
            Else {
                Write-Output "$(Get-Date -Format G) WARNING $($Computer): is NOT pingable"
            }

            $TestWMI = Get-WmiObject  win32_Computersystem -PSComputerName $Computer -PSCredential $Patching_Creds -ErrorVariable WMIerror -ErrorAction Continue
            If ($WMIerror) {
                Write-Output "$(Get-Date -Format G) $($Computer): WARNING CANNOT connect via WMI"  $($SCCM.Exception[0])
        }
        Else {
            "$(Get-Date -Format G) $($Computer): can connect to WMI"
        }

        #Check for SCCM connectivitiy
        Write-Verbose "$(Get-Date -Format G) Testing ability to connect to computer SCCM WMI"
   
        $TestSCCM = Get-WmiObject -PSComputerName $Computer -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -PSCredential $Patching_Creds -ErrorVariable SCCMerror -ErrorAction Continue
        If ( $SCCMerror) {
            Write-Output "$(Get-Date -Format G) $($Computer): WARNING: CANNOT connect to SCCM WMI; $($SCCM.Exception[0])"
        }
        Else {
            Write-Output "$(Get-Date -Format G) $($Computer): can connect to SCCM WMI"
        }

        #Test ability to snapshot

        Write-Verbose "$(Get-Date -Format G) $($Computer): testing vmware"
        $IsAVM = Get-WmiObject Win32_Bios -PSComputerName $Computer -PSCredential $Patching_Creds -ErrorAction Continue

        If ( $IsAVM.SerialNumber -match 'VMware') {
         
            $VMDetails = InlineScript {
                Import-Module VMware.VimAutomation.Core    
                $Null = Connect-viserver -server $USING:HostServer -Credential $Using:Patching_Creds
                $VM = Get-VM -Name $Using:Computer 
                Write-output $vm
                                                            
            }
            If ( $Computer -match $VMDetails.Name ) {
                Write-Output "$(Get-Date -Format G) $($Computer): is a valid VM"
            }
            Else {
                Write-Output "$(Get-Date -Format G) $($Computer): is NOT a reachable VM, check config in vsphere"
            }
        }

        Else {
            Write-Output "$(Get-Date -Format G) $($Computer): is NOT a vmare vm, skipping"
        }

        #Test if in scom
        Write-Verbose "$(Get-Date -Format G) $($Computer): testing if computer is in SCOM"

        $FQDN = [System.Net.Dns]::GetHostByName(($Computer)).HostName.ToString() 
        $SCOMDetails = InlineScript {
            $FQDN = $Using:FQDN
            Invoke-Command {
                Param($FQDN)
        
                Import-Module "C:\Program Files\Microsoft System Center 2012 R2\Operations Manager\Powershell\OperationsManager\OperationsManager.psm1"
                Get-SCOMmonitoringobject -Name $FQDN |Select Name, InMaintenanceMode, @{name ='SCOMServer';e={$env:COMPUTERNAME}}
            } -ComputerName $Using:SCOMServer -ArgumentList $FQDN -Credential $USING:Patching_Creds -HideComputerName
        }
        If ($SCOMDetails.Name -Match $Computer) {
            Write-Output "$(Get-Date -Format G) $($Computer): is a valid server in SCOM"
        }
        Else {
            Write-Output "$(Get-Date -Format G) $($Computer): is NOT a valid server in SCOM, check SCOM config"
        }
                                                    
    }                                                         
}
Else {
    Write-Output "$(Get-Date -Format G) Test if CSV is reachable: Failed, check the patch is reachable and try again"
}
Write-Output "$(Get-Date -Format G) Tests completed"
}
