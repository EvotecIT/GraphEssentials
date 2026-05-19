function Get-GraphEssentialsAutopilotLookup {
    [CmdletBinding()]
    param()

    $byManagedDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $byAzureAdDeviceId = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $bySerialNumber = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

    try {
        $properties = @(
            'id', 'groupTag', 'purchaseOrderIdentifier', 'serialNumber', 'manufacturer', 'model',
            'enrollmentState', 'lastContactedDateTime', 'addressableUserName', 'userPrincipalName',
            'resourceName', 'skuNumber', 'systemFamily', 'azureActiveDirectoryDeviceId',
            'managedDeviceId', 'displayName'
        )
        $autopilotDevices = @(Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All -Property $properties -ErrorAction Stop)
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
        $managedDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('ManagedDeviceId', 'managedDeviceId')
        $azureAdDeviceId = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('AzureAdDeviceId', 'azureAdDeviceId', 'AzureActiveDirectoryDeviceId', 'azureActiveDirectoryDeviceId')
        $serialNumber = Get-GraphEssentialsObjectProperty -InputObject $autopilotDevice -Name @('SerialNumber', 'serialNumber')

        if ($managedDeviceId -and -not $byManagedDeviceId.ContainsKey($managedDeviceId)) {
            $byManagedDeviceId[$managedDeviceId] = $autopilotDevice
        }
        if ($azureAdDeviceId -and -not $byAzureAdDeviceId.ContainsKey($azureAdDeviceId)) {
            $byAzureAdDeviceId[$azureAdDeviceId] = $autopilotDevice
        }
        if ($serialNumber -and -not $bySerialNumber.ContainsKey($serialNumber)) {
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
