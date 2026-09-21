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

    $ambiguousMatch = [PSCustomObject] @{
        Id             = $null
        MatchAmbiguous = $true
    }

    if (($ManagedDeviceId -and $Lookup.AmbiguousManagedDeviceIds.Contains($ManagedDeviceId)) -or
        ($AzureAdDeviceId -and $Lookup.AmbiguousAzureAdDeviceIds.Contains($AzureAdDeviceId)) -or
        ($SerialNumber -and $Lookup.AmbiguousSerialNumbers.Contains($SerialNumber))) {
        return $ambiguousMatch
    }

    $matches = [System.Collections.Generic.List[object]]::new()
    if ($ManagedDeviceId -and $Lookup.ByManagedDeviceId.ContainsKey($ManagedDeviceId)) {
        $matches.Add($Lookup.ByManagedDeviceId[$ManagedDeviceId])
    }
    if ($AzureAdDeviceId -and $Lookup.ByAzureAdDeviceId.ContainsKey($AzureAdDeviceId)) {
        $matches.Add($Lookup.ByAzureAdDeviceId[$AzureAdDeviceId])
    }
    if ($SerialNumber -and $Lookup.BySerialNumber.ContainsKey($SerialNumber)) {
        $matches.Add($Lookup.BySerialNumber[$SerialNumber])
    }

    if ($matches.Count -eq 0) {
        return $null
    }

    $matchId = Get-GraphEssentialsObjectProperty -InputObject $matches[0] -Name @('Id', 'id')
    if ([string]::IsNullOrWhiteSpace([string] $matchId)) {
        return $ambiguousMatch
    }
    foreach ($match in $matches) {
        $candidateId = Get-GraphEssentialsObjectProperty -InputObject $match -Name @('Id', 'id')
        if ([string] $candidateId -ine [string] $matchId) {
            return $ambiguousMatch
        }
    }

    $matches[0]
}
