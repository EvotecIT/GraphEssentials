function Get-GraphEssentialsAutopilotLookup {
    [CmdletBinding()]
    param()

    $byManagedDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $byAzureAdDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $bySerialNumber = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $serialNumberCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)

    try {
        $properties = @(
            'id', 'groupTag', 'serialNumber', 'enrollmentState', 'lastContactedDateTime',
            'userPrincipalName', 'resourceName', 'azureActiveDirectoryDeviceId', 'managedDeviceId'
        )
        $autopilotDevices = [System.Collections.Generic.List[object]]::new()
        Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All -Property $properties -ErrorAction Stop | ForEach-Object {
            $autopilotDevices.Add([PSCustomObject] @{
                    Id                           = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('Id', 'id')
                    GroupTag                     = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('GroupTag', 'groupTag')
                    SerialNumber                 = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('SerialNumber', 'serialNumber')
                    EnrollmentState              = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('EnrollmentState', 'enrollmentState')
                    LastContactedDateTime        = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('LastContactedDateTime', 'lastContactedDateTime')
                    UserPrincipalName            = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('UserPrincipalName', 'userPrincipalName')
                    ResourceName                 = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('ResourceName', 'resourceName')
                    AzureActiveDirectoryDeviceId = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('AzureAdDeviceId', 'azureAdDeviceId', 'AzureActiveDirectoryDeviceId', 'azureActiveDirectoryDeviceId')
                    ManagedDeviceId              = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('ManagedDeviceId', 'managedDeviceId')
                    DisplayName                  = Get-GraphEssentialsObjectProperty -InputObject $_ -Name @('DisplayName', 'displayName')
                })
        }
    } catch {
        Write-Warning -Message "Get-GraphEssentialsAutopilotLookup - Failed to get Windows Autopilot devices. Error: $($_.Exception.Message)"
        return [PSCustomObject] @{
            InventoryLoaded   = $false
            ByManagedDeviceId = $byManagedDeviceId
            ByAzureAdDeviceId = $byAzureAdDeviceId
            BySerialNumber    = $bySerialNumber
        }
    }

    foreach ($autopilotDevice in $autopilotDevices) {
        $serialNumber = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('SerialNumber', 'serialNumber')
        if ($serialNumber -and (Test-GraphEssentialsAutopilotSerialNumber -SerialNumber $serialNumber)) {
            if ($serialNumberCounts.ContainsKey($serialNumber)) {
                $serialNumberCounts[$serialNumber]++
            } else {
                $serialNumberCounts[$serialNumber] = 1
            }
        }
    }

    foreach ($autopilotDevice in $autopilotDevices) {
        $managedDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('ManagedDeviceId', 'managedDeviceId')
        $azureAdDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('AzureAdDeviceId', 'azureAdDeviceId', 'AzureActiveDirectoryDeviceId', 'azureActiveDirectoryDeviceId')
        $serialNumber = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('SerialNumber', 'serialNumber')

        if ($managedDeviceId -and -not $byManagedDeviceId.ContainsKey($managedDeviceId)) {
            $byManagedDeviceId[$managedDeviceId] = $autopilotDevice
        }
        if ($azureAdDeviceId -and -not $byAzureAdDeviceId.ContainsKey($azureAdDeviceId)) {
            $byAzureAdDeviceId[$azureAdDeviceId] = $autopilotDevice
        }
        if ($serialNumber -and $serialNumberCounts.ContainsKey($serialNumber) -and $serialNumberCounts[$serialNumber] -eq 1 -and -not $bySerialNumber.ContainsKey($serialNumber)) {
            $bySerialNumber[$serialNumber] = $autopilotDevice
        }
    }

    [PSCustomObject] @{
        InventoryLoaded   = $true
        ByManagedDeviceId = $byManagedDeviceId
        ByAzureAdDeviceId = $byAzureAdDeviceId
        BySerialNumber    = $bySerialNumber
    }
}
