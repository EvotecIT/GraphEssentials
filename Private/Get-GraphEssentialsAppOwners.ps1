function Get-GraphEssentialsAppOwners {
    param(
        [string]$ServicePrincipalObjectId # The Object ID of the Service Principal
    )
    Write-Verbose "Get-GraphEssentialsAppOwners: Fetching owners for Service Principal ObjectId $ServicePrincipalObjectId..."
    $OwnersInfo = [System.Collections.Generic.List[object]]::new()
    if (-not $ServicePrincipalObjectId) {
        Write-Warning "Get-GraphEssentialsAppOwners: Service Principal Object ID not provided. Cannot fetch owners."
        return $OwnersInfo
    }

    try {
        $rawOwners = Get-MgServicePrincipalOwner -ServicePrincipalId $ServicePrincipalObjectId -ErrorAction Stop

        if ($rawOwners) {
            $rawOwners | ForEach-Object {
                # Return a richer object for debugging
                $ownerDetail = $_ | Select-Object Id, DeletedDateTime, @{n = 'ODataType'; e = { $_.AdditionalProperties.'@odata.type' } }, AdditionalProperties
                $OwnersInfo.Add($ownerDetail)
            }
            Write-Verbose "Get-GraphEssentialsAppOwners: Found $($OwnersInfo.Count) owners (raw) for Service Principal $ServicePrincipalObjectId."
        } else {
            Write-Verbose "Get-GraphEssentialsAppOwners: No owners found for Service Principal $ServicePrincipalObjectId."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsAppOwners: Failed to get owners for SP $ServicePrincipalObjectId. Error: $($_.Exception.Message)"
        $OwnersInfo.Add([PSCustomObject]@{ Error = "Error fetching SP owners: $($_.Exception.Message)" })
    }
    $OwnersInfo
}