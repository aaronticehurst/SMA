WorkFlow New-Snapshot {
    <#
.Synopsis
    Snapshot servers.
.DESCRIPTION
    Snapshot servers using Microsoft Service Management Austomation.
.PARAMETER  ComputerName
    Computers to snapshot.
.PARAMETER  SnapshotDescription
    Snapshot description.
.PARAMETER  HostServer
    VCenter servers to connect to.
.EXAMPLE
   PS C:\> New-Snapshot -ComputerName COMPUTER -SnapshotDescription "Patching" -HostServer VCENTER
   Snapshots servers.
#>


    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [String[]]$ComputerName,
        [Parameter(Mandatory = $False,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [String]$SnapshotDescription,
        [Parameter(Mandatory = $False,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [String[]]$HostServer
    )
    
    
    
    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'

    InlineScript {
        Import-Module VMware.VimAutomation.Core   
        $VMwareServer = Connect-Viserver -Server $USING:HostServer -Credential $Using:Patching_Creds

        Foreach ($Computer in $USING:ComputerName) {
            If (Get-VM -Name $Computer) {

                $SnapShot = New-Snapshot -VM $Computer -Name "Before Patching" -Description $USING:SnapshotDescription 
                $SnapShotSucceeded = if ($SnapShot) {$True}
                Else {$False}
                [pscustomobject]@{
                    VM = $SnapShot.VM
                    SnapShotName = $SnapShot.name
                    SnapShotDescription = $SnapShot.Description
                    SnapShotSucceeded = $SnapShotSucceeded
                }
             
            }
            Else {Write-output "$(Get-Date -Format G) $($Computer): Not found as a VM, skipping snapshotting" }
    
    
        }
        Disconnect-VIServer -Server $VMwareServer -Confirm:$False
    }

}


