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
        $rawOwners = Get-MgServicePrincipalOwner -ServicePrincipalId $ServicePrincipalObjectId -Property "id,displayName,userPrincipalName,mail" -All -ErrorAction Stop

        if ($rawOwners) {
            $rawOwners | ForEach-Object {
                # Return a richer object for display
                $ownerDetail = $_ | Select-Object Id,
                    DeletedDateTime,
                    @{n = 'ODataType'; e = { $_.AdditionalProperties.'@odata.type' } },
                    AdditionalProperties,
                    DisplayName,
                    UserPrincipalName,
                    Mail
                $OwnersInfo.Add($ownerDetail)
            }
            Write-Verbose "Get-GraphEssentialsAppOwners: Found $($OwnersInfo.Count) owners (raw) for Service Principal $ServicePrincipalObjectId."
        } else {
            Write-Verbose "Get-GraphEssentialsAppOwners: No owners found for Service Principal $ServicePrincipalObjectId."
        }
    } catch {
        $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Get-GraphEssentialsAppOwners'
        if ($errorInfo.IsNotFound) {
            Write-Verbose "Get-GraphEssentialsAppOwners: Service Principal $ServicePrincipalObjectId no longer resolves while fetching owners."
        } else {
            Write-Warning $errorInfo.FullMessage
        }
    }
    $OwnersInfo
}
