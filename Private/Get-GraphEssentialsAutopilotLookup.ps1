function Get-GraphEssentialsAutopilotLookup {
    [CmdletBinding()]
    param()

    $byManagedDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $byAzureAdDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $bySerialNumber = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $managedDeviceIdCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $azureAdDeviceIdCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $serialNumberCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ambiguousManagedDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ambiguousAzureAdDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ambiguousSerialNumbers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

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
            AmbiguousManagedDeviceIds = $ambiguousManagedDeviceIds
            AmbiguousAzureAdDeviceIds = $ambiguousAzureAdDeviceIds
            AmbiguousSerialNumbers    = $ambiguousSerialNumbers
        }
    }

    foreach ($autopilotDevice in $autopilotDevices) {
        $managedDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('ManagedDeviceId', 'managedDeviceId')
        $azureAdDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('AzureAdDeviceId', 'azureAdDeviceId', 'AzureActiveDirectoryDeviceId', 'azureActiveDirectoryDeviceId')
        $serialNumber = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('SerialNumber', 'serialNumber')
        if ($managedDeviceId) {
            if ($managedDeviceIdCounts.ContainsKey($managedDeviceId)) { $managedDeviceIdCounts[$managedDeviceId]++ } else { $managedDeviceIdCounts[$managedDeviceId] = 1 }
        }
        if ($azureAdDeviceId) {
            if ($azureAdDeviceIdCounts.ContainsKey($azureAdDeviceId)) { $azureAdDeviceIdCounts[$azureAdDeviceId]++ } else { $azureAdDeviceIdCounts[$azureAdDeviceId] = 1 }
        }
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

        if ($managedDeviceId -and $managedDeviceIdCounts[$managedDeviceId] -eq 1) {
            $byManagedDeviceId[$managedDeviceId] = $autopilotDevice
        }
        if ($azureAdDeviceId -and $azureAdDeviceIdCounts[$azureAdDeviceId] -eq 1) {
            $byAzureAdDeviceId[$azureAdDeviceId] = $autopilotDevice
        }
        if ($serialNumber -and $serialNumberCounts.ContainsKey($serialNumber) -and $serialNumberCounts[$serialNumber] -eq 1) {
            $bySerialNumber[$serialNumber] = $autopilotDevice
        }
    }

    foreach ($key in $managedDeviceIdCounts.Keys) {
        if ($managedDeviceIdCounts[$key] -gt 1) { $null = $ambiguousManagedDeviceIds.Add($key) }
    }
    foreach ($key in $azureAdDeviceIdCounts.Keys) {
        if ($azureAdDeviceIdCounts[$key] -gt 1) { $null = $ambiguousAzureAdDeviceIds.Add($key) }
    }
    foreach ($key in $serialNumberCounts.Keys) {
        if ($serialNumberCounts[$key] -gt 1) { $null = $ambiguousSerialNumbers.Add($key) }
    }

    [PSCustomObject] @{
        InventoryLoaded   = $true
        ByManagedDeviceId = $byManagedDeviceId
        ByAzureAdDeviceId = $byAzureAdDeviceId
        BySerialNumber    = $bySerialNumber
        AmbiguousManagedDeviceIds = $ambiguousManagedDeviceIds
        AmbiguousAzureAdDeviceIds = $ambiguousAzureAdDeviceIds
        AmbiguousSerialNumbers    = $ambiguousSerialNumbers
    }
}
