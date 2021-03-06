WorkFlow Install-NewPatches {
    [CmdletBinding()]
    param (
				
        [parameter(Position=0)]
        [String[]]$ComputerName,
        [parameter(Position=1)]
        [INT]$SleepEvaluationCycle=60,
        [parameter(Position=2)]
        [INT]$SleepScanCycle=60,
        [parameter(Position=3)]
        [INT]$ErrorRetryTime=30
    )

    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'

    Try {
        # Machine Policy Evaluation Cycle
        If ($SleepEvaluationCycle -gt 0 ) {
            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Invoke Machine Policy Evaluation Cycle" 
            $NULL = Invoke-WmiMethod -PSComputerName $ComputerName -Namespace "Root\CCM" -Class SMS_Client -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000022}" -ErrorAction Continue -PSCredential $Patching_Creds
            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Sleeping for $SleepEvaluationCycle seconds" 
            Start-Sleep -Seconds $SleepEvaluationCycle
        }
        Elseif ($SleepEvaluationCycle -eq 0 ) {
            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Skipping Invoke Machine Policy Evaluation Cycle"  
        }

        # Software Updates Scan Cycle
        If ($SleepScanCycle -gt 0) {
            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Software Updates Scan Cycle" 
            $NULL = Invoke-WmiMethod -PSComputerName $ComputerName -Namespace "Root\CCM" -Class SMS_Client -Name TriggerSchedule -ArgumentList "{00000000-0000-0000-0000-000000000113}" -ErrorAction Continue -PSCredential $Patching_Creds
            Write-Verbose "$(Get-Date -Format G) $($ComputerName): Sleeping for $SleepScanCycle seconds" 
            Start-Sleep -Seconds $SleepScanCycle
        }
        ElseIf ($SleepScanCycle -eq 0 ) {
            Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Skipping Software Updates Scan Cycle" 
        }

        $NoOfPatches = Get-WmiObject -PSComputerName $ComputerName  -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -ErrorAction Continue -PSCredential $Patching_Creds| measure-object | select -expand count
        If ($NoOfPatches -eq $null) {
            $NoOfPatches = 0
        }

        If ($NoOfPatches -gt 0){
            #Install
            Write-OutPut -InputObject "$(Get-Date -Format G) $($ComputerName): Installing $NoOfPatches patches" 
            InlineScript {
                [System.Management.ManagementBaseObject[]]$Updates = Get-WmiObject -ComputerName $USING:ComputerName -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -Impersonation Impersonate -ErrorAction Continue -Credential $USING:Patching_Creds| 
                Where-Object -FilterScript {($_.ComplianceState -eq '0') -and ($_.EvaluationState -match "0$|1$|13$")} 
                                                                                                                                                                
                If ($Updates) {
                    $NULL = Invoke-WmiMethod -ComputerName $USING:ComputerName  -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList (, $Updates) -Namespace root\ccm\clientsdk -Impersonation Impersonate -ErrorAction Continue -Credential $USING:Patching_Creds
                }
            }
                                        

        }
    }

    Catch {
        Write-Warning -Message "$(Get-Date -Format G) $($ComputerName): Install-NewPatches Caught error, sleeping and retrying in $ErrorRetryTime seconds `n$($error[0])" 
        Start-Sleep -Seconds $ErrorRetryTime
                       
    }
    Finally {
    }
                   

}
