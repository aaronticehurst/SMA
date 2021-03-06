workflow Invoke-PatchWorkflow   {
    [CmdletBinding()]
    param (
				
        [parameter(Position=0)]
        [String]$ComputerName,
        [parameter(Position=1)]
        [INT]$SleepEvaluationCycle=60,
        [parameter(Position=2)]
        [INT]$SleepScanCycle=60,
        [parameter(Position=3)]
        [INT]$SleepMonitor=60,
        [parameter(Position=4)]
        [INT]$MonitorLoop=20,
        [parameter(Position=5)]
        [INT]$ErrorRetryTime=30,
        [parameter(Position=6)]
        [String]$SuppressRebootAfter = "29 April 2030 12:00:00 PM",
        [parameter(Position=7)]
        [String]$Email,
        [parameter(Position=8)]
        [String]$LogFile,
        [parameter(Position=9)]
        [String]$From = "EmailAddress", 
        [parameter(Position=10)]
        [String]$SMTPServer = "MailServer",
        [parameter(Position=11)]
        [String]$SCOMServer = "SCOMServer",
        [parameter(Position=12)]
        [INT]$MaintNo = 12345


    )


    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'

    $DNSCheck = Get-WmiObject -PSComputerName $ComputerName -Class win32_computersystem -PSCredential $Patching_Creds 

    If ($DNSCheck.DNSHostName -eq ($ComputerName -split '(?=\.)')[0]) {
        Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Is $($DNSCheck.Name)" 
        $PatchesToBeInstalled = Get-WmiObject -PSComputerName $ComputerName -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -PSCredential $Patching_Creds 
        If ($PatchesToBeInstalled.Name -eq $Null) {
            $Patches = "No patches to install"
        }
        Else {
            $Patches = $PatchesToBeInstalled.Name | ForEach-Object {$_ + "`n"} 
        }
        Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $ComputerName is installing the following patches" -Body "$Patches" -SmtpServer $SMTPServer 

        $PatchingFail = $False   

        Try {
            $CountPatchAttempts = 0
            Do {        
                        
                $NoOfPatches = $Null
                Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Scanning and installing patches" 
                Install-NewPatches -ComputerName $ComputerName -SleepEvaluationCycle $SleepEvaluationCycle -SleepScanCycle $SleepScanCycle 

                Write-OutPut -InputObject "$(Get-Date -Format G) $($ComputerName): Monitoring patching" 
                Monitor-Patches -ComputerName $ComputerName -SleepMonitor $SleepMonitor -MonitorLoop $MonitorLoop
                
                $RebootPending = $False
                $RebootPending =  Invoke-WmiMethod -PSComputerName $ComputerName -Class CCM_ClientUtilities -Namespace "ROOT\ccm\ClientSDK" -Name DetermineIfRebootPending -ErrorAction Continue -PSCredential $Patching_Creds  
                Write-OutPut -InputObject "$(Get-Date -Format G) $($ComputerName): Reboot pending is $($RebootPending.RebootPending)"
                       
                If ($RebootPending.RebootPending -eq $True) {
                    If ((Get-Date) -lt $SuppressRebootAfter){
                        Try {
                            Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Restarting" 
                            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $($ComputerName) rebooting" -Body "$($ComputerName) is rebooting." -SmtpServer $SMTPServer
                                       
                            Restart-Computer -PSComputerName $ComputerName -Wait:$True -For WMI -Timeout 3600 -Force:$True -ErrorAction Stop -PSCredential $Patching_Creds 
                                        
                            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Sleeping for 180 seconds after reboot has completed"
                                        
                            Start-Sleep -Seconds 180

                            InlineScript {    
                                $Running = $False
                                $TestCount = 0
                                While ($Running -eq $False -or $TestCount -eq 50) {
                                    Try {
                                        Write-Verbose -Message "$(Get-Date -Format G) $($USING:ComputerName): Testing SCCM WMI"
                                        $TestIfUp = Get-WmiObject -ComputerName $USING:ComputerName -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -ErrorAction Stop -Credential $USING:Patching_Creds  | measure-object 
                                        
                                             
                                        If ($TestIfUp) {
                                            $Running = $True 
                                        }
                                    }
                                    Catch {
                                        Write-Warning -Message "$(Get-Date -Format G) $($USING:ComputerName): $($Error[0]) Error caught sleeping 30 seconds"
                                        Start-Sleep -seconds 30
                                        Continue 
                                    }
                                    Finally {
                                        Write-Verbose -Message "$(Get-Date -Format G) $($USING:ComputerName): Running check = $Running "
                                        $TestCount++ 
                                    }


                                }                                                           


                            }

                        }
                        Catch [Microsoft.PowerShell.Commands.RestartComputerTimeoutException]{
                            Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Failed to restart in time $($error[0])"
                            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $($ComputerName) has taken too long to reboot" -Body "Please see if there is a problem with $($ComputerName) `n $($error[0])." -SmtpServer $SMTPServer 
                            $PatchingFail = $True                                    
                        }
                        Catch {
                            Write-Output "$(Get-Date -Format G) $($ComputerName): has had an error rebooting $($error[0]) $r"
                            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $($ComputerName) has had an error rebooting" -Body "Please see if there is a problem with $($ComputerName) `n $($error[0]) $r." -SmtpServer $SMTPServer
                            $PatchingFail = $True  
                                    
                        }
                                       
                        Finally {
                        }
                                
                                            
                    }
                                                                    
                    Else {
                        Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Reboot has been suppressed"
                    }  

                             
                                           
                }
                
                $NoOfPatches = Get-WmiObject -PSComputerName $ComputerName -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -ErrorAction Continue -PSCredential $Patching_Creds | measure | select -expand count
                If ($NoOfPatches -eq $null) {
                    $NoOfPatches = 0
                }
                Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Number of patches left: $NoOfPatches"

                $CountPatchAttempts++
                If ($CountPatchAttempts -eq 5) {
                    $PatchingFail = $True 
                }
            } #End Do loop
            Until ($NoOfPatches -eq 0 -or $PatchingFail -eq $True )
        }                
        Catch {
            Throw
            Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Caught error, sleeping and retrying in $ErrorRetryTime seconds"
            Start-Sleep -Seconds $ErrorRetryTime
        }
        Finally{ 
        }


        If ($PatchingFail -eq $False) {
            Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): Finished patching" 
            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $($ComputerName) finished patching" -Body "Please take a look over it for completeness or to do post patch work" -SmtpServer $SMTPServer
        }

        ElseIf ($PatchingFail -eq $True) {
            Write-Output -InputObject "$(Get-Date -Format G) $($ComputerName): A problem has occurred, aborted further patching" 
            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo $($ComputerName) has had a problem" -Body "Further patching has been aborted please check the server" -SmtpServer $SMTPServer
        }

    }  ###End Patching
    Else {
        Write-Warning -Message "$(Get-Date -Format G) $($ComputerName): Could not validate or reach server, check DNS and network connectivity" 
      
    }
}
