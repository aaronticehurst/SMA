workflow Invoke-PatchParallelServer {
    <#
.Synopsis
   Patches Servers in parallel
.DESCRIPTION
   Patches Servers in parallel
#>


    [CmdletBinding()]
    param (
				
        [Parameter(Mandatory=$False,
            ValueFromPipelineByPropertyName=$true,
            Position=1)]
        [String]$ConfigPath,            
        [parameter(Position=2)]
        [String]$SuppressRebootAfter = "29 April 2050 12:00:00 PM",
        [parameter(Mandatory=$False,
            Position=3)]
        [String]$Email,
        [Boolean]$Snapshot,
        [Boolean]$PutIntoMaintMode

    )

    [String]$From = 'EmailAddress'
    [String]$SMTPServer = 'MailServer'            
    [INT]$SleepEvaluationCycle=60
    [INT]$SleepScanCycle=60
    [INT]$SleepMonitor=300
    [INT]$MonitorLoop=5
    [INT]$ErrorRetryTime=30


    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'
    $PathToConfig = Import-csv -path $ConfigPath 
    $MaintNo = ($PathToConfig.MaintNo | Select -first 1)
    Write-output $PathToConfig | Foreach-Object { Write-output "$(Get-Date -Format G) Patching $($_.Computername)"}

    $ComputersToPatch =@()
    $ComputersToPatch = $PathToConfig.ComputerName | Foreach-Object {$_ + "`n"}

    Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo Patching commencing" `
            -Body "The following computers are beginning patching, ignore any alerts for the duration or advised otherwise. `n$ComputersToPatch" -SmtpServer $SMTPServer 
             


    If ($Snapshot -eq $True)  {
    
        $VMs = Get-WmiObject win32_ComputerSystem -PSComputerName $PathToConfig.Computername -PSCredential $Patching_Creds |  Where-Object -FilterScript { $_.Manufacturer -match 'VMware'}
        Write-OutPut "$(Get-Date -Format G): Start Snapshotting" 
    
        $Snapshots = New-Snapshot -ComputerName $VMs.DNSHostName -SnapShotDescription ($PathToConfig.SnapshotDescription | Select -first 1)
        #$Snapshots
        If ($Snapshots) {

            Foreach ($Snapshot in $Snapshots) {
                If ($Snapshot.SnapShotSucceeded -eq $True ) {    
                    Write-OutPut "$(Get-Date -Format G) $($SnapShot.VM): snapshotting succeeded"
                    
                }
                        
                Else {
                    Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo Patching workflow suspended" `
        -Body "A server has not been snapshotted, suspending workflow, resolve and resume the workflow." -SmtpServer $SMTPServer  

                    Suspend-Workflow

                }
            }

        }
        Else {    
            Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo Patching workflow suspended" `
                -Body "Snapshotting has failed, suspending workflow, resolve and resume the workflow." -SmtpServer $SMTPServer  
            Suspend-Workflow  
        }

                      
    }
    

  
    Else {
        Write-Output "$(Get-Date -Format G) Did not snapshot as requested"
    }
 
    Checkpoint-Workflow

    If ($PutIntoMaintMode -eq $True) {
        Write-OutPut "$(Get-Date -Format G) Starting maint mode" 
        Start-MaintMode -ComputerName $PathToConfig.ComputerName -Reason ($PathToConfig.Reason | select -first 1) -Comment ($PathToConfig.Comment | select -first 1) -Hours ($PathToConfig.Hours | select -first 1) #-SCOMServer $SCOMServer 

        #Check is in maint mode.
    
        Foreach ($MaintComputer in $PathToConfig.ComputerName) {
            $IsInMaintMode = $Null
            $IsInMaintMode = Get-MaintMode -ComputerName $MaintComputer 
    
            If ( $IsInMaintMode.InMaintenanceMode -ne $True ) { 
                Write-output "$(Get-Date -format G) Maint mode has failed on $MaintComputer; suspending the workflow" 
                Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo Patching workflow suspended" `
                                -Body "Starting Maint mode has failed on $MaintComputer, suspending workflow, resolve and resume the workflow." -SmtpServer $SMTPServer 
                Suspend-Workflow
            } 
            Else {
                Write-output "$(Get-Date -format G) $($MaintComputer): Putting into maint mode has succeeded"
            }
        }
    
    }

    Else {
        Write-Output "$(Get-Date -Format G) Did not enter maint mode as requested"
    }

    Checkpoint-Workflow
    Write-OutPut "$(Get-Date -Format G) Starting Patching" 
    Foreach -parallel ($PC in $PathToConfig.ComputerName) {
        Invoke-PatchWorkflow -Computername $PC -SleepEvaluationCycle $SleepEvaluationCycle -SleepScanCycle $SleepScanCycle -SleepMonitor $SleepMonitor -MonitorLoop $MonitorLoop -ErrorRetryTime $ErrorRetryTime -SuppressRebootAfter $SuppressRebootAfter -Email $Email -MaintNo ($PathToConfig.MaintNo | Select -first 1) 
    
        Stop-MaintMode -ComputerName $PC 
    }
    Checkpoint-Workflow
    
    Write-Output "$(Get-Date -Format G) Patching is complete."

    Send-MailMessage -To $Email -From $From -Subject "Maint $MaintNo Patching complete" -Body "Following computers have been patched `n$ComputersToPatch" -SmtpServer $SMTPServer 
            
            
}
