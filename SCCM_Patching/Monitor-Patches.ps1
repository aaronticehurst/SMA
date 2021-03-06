WorkFlow Monitor-Patches {

        [CmdletBinding()]
            param (				
			    [parameter(Position=0)]
			    [String[]]$ComputerName, 
                [parameter(Position=1)]
                [INT]$SleepMonitor=60,
                [parameter(Position=2)]
                [INT]$MonitorLoop=20
            )


$Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'

Try {
                        [INT]$Loops=0

                        Do {
                        $Loops++

                        Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Monitor-patches: Sleeping for $SleepMonitor seconds" 
                        Start-Sleep -Seconds $SleepMonitor

                        Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Monitor-patches Checking need to reboot and number of patches" 
                        $RebootPending = Invoke-WmiMethod -PSComputerName $ComputerName  -Class CCM_ClientUtilities -Namespace "ROOT\ccm\ClientSDK" -Name DetermineIfRebootPending -ErrorAction Stop -PSCredential $Patching_Creds
                        Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Reboot Pending is $(($RebootPending).RebootPending)" 
                    
                        $NoOfPatches = Get-WmiObject -PSComputerName $ComputerName -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -Namespace root\CCM\ClientSDK -ErrorAction Stop -PSCredential $Patching_Creds | measure-object
                        If (($NoOfPatches).count -eq $null) {$NoOfPatches = 0}
                        Write-Verbose -Message "$(Get-Date -Format G) $($ComputerName): Monitor-patches Number of patches left $(($NoOfPatches).count)" 
                    
                        }

                        Until ( ($RebootPending).RebootPending -eq $True -or ($NoOfPatches).count -eq 0 -or $Loops -eq $MonitorLoop -or $PatchingFail -eq $True )
                    

                            }  

Catch   {  
            Throw
            Write-output -InputObject "Monitor-patches Caught error" 
        }    
Finally{}
}