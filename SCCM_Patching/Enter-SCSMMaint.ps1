workflow Enter-SCSMMaint {
    $Patching_Creds = Get-AutomationPSCredential -Name 'Patching_Creds'
    $SCSMManagementServer = 'scsm management server'
    
    InlineScript {
        Invoke-Command {
            Import-Module Smlets
                   
            $PublishStatus = Get-SCSMEnumeration -Name System.Offering.StatusEnum | Get-SCSMChildEnumeration | Where-Object {$_.DisplayName -eq "Published"}
            $PublishProp = @{"Status" = $PublishStatus}
            $DraftStatus = Get-SCSMEnumeration -Name System.Offering.StatusEnum | Get-SCSMChildEnumeration | Where-Object {$_.DisplayName -eq "Draft"}
            $DraftProp = @{"Status" = $DraftStatus}
                   
            #Get properties
            $MaintAnnounce = Get-SCSMServiceOffering | where {$_.title -match 'Self Service under maintenance'}
            $Published = Get-SCSMServiceOffering | where {$_.status -match 'Published'}
            $Published | select -ExpandProperty title | out-file c:\files\SCSM_Published.txt -force

            #Publish maint announce
            $MaintAnnounce |Set-SCSMObjectProjection -PropertyValues $PublishProp -Verbose

            #Convert Offerings from Published to Draft
            $Published | Set-SCSMObjectProjection -PropertyValues $DraftProp -Verbose
        } 
    } -PSComputerName $SCSMManagementServer -PSCredential $Patching_Creds

}
