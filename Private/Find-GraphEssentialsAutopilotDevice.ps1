function Find-GraphEssentialsAutopilotDevice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Lookup,

        [string] $ManagedDeviceId,
        [string] $AzureAdDeviceId,
        [string] $SerialNumber
    )

    if (-not $Lookup -or -not $Lookup.InventoryLoaded) {
        return $null
    }

    if ($ManagedDeviceId -and $Lookup.ByManagedDeviceId.ContainsKey($ManagedDeviceId)) {
        return $Lookup.ByManagedDeviceId[$ManagedDeviceId]
    }
    if ($AzureAdDeviceId -and $Lookup.ByAzureAdDeviceId.ContainsKey($AzureAdDeviceId)) {
        return $Lookup.ByAzureAdDeviceId[$AzureAdDeviceId]
    }
    if ($SerialNumber -and $Lookup.BySerialNumber.ContainsKey($SerialNumber)) {
        return $Lookup.BySerialNumber[$SerialNumber]
    }

    $null
}
