function Get-GraphEssentialsAppOwners {
    param(
        [string]$ServicePrincipalObjectId # The Object ID of the Service Principal
    )
    Write-Verbose "Get-GraphEssentialsAppOwners: Fetching owners for Service Principal ObjectId $ServicePrincipalObjectId..."
    # Note: Requires Directory.Read.All or Application.Read.All / AppRoleAssignment.ReadWrite.All
    $OwnersList = @()
    if (-not $ServicePrincipalObjectId) {
        Write-Warning "Get-GraphEssentialsAppOwners: Service Principal Object ID not provided. Cannot fetch owners."
        return $OwnersList
    }

    try {
        # Use Get-MgServicePrincipalOwner cmdlet
        # This cmdlet handles paging
        $rawOwners = Get-MgServicePrincipalOwner -ServicePrincipalId $ServicePrincipalObjectId -ErrorAction Stop

        if ($rawOwners) {
            $OwnersList = $rawOwners | ForEach-Object {
                # Access properties carefully based on object type
                $dispName = if ($_.AdditionalProperties.ContainsKey('displayName')) { $_.AdditionalProperties.displayName } else { $null }
                $upn = if ($_.AdditionalProperties.ContainsKey('userPrincipalName')) { $_.AdditionalProperties.userPrincipalName } else { $null }
                $mail = if ($_.AdditionalProperties.ContainsKey('mail')) { $_.AdditionalProperties.mail } else { $null }
                $ownerString = $dispName
                if ($upn) {
                    $ownerString += " <$upn>"
                } elseif ($mail) {
                    $ownerString += " <$mail>"
                }
                if (-not $ownerString) { $ownerString = $_.Id } # Fallback to ID
                $ownerString
            }
            Write-Verbose "Get-GraphEssentialsAppOwners: Found $($OwnersList.Count) owners for Service Principal $ServicePrincipalObjectId."
        } else {
            Write-Verbose "Get-GraphEssentialsAppOwners: No owners found for Service Principal $ServicePrincipalObjectId."
        }
    } catch {
        # Handle specific error for owners not supported on this object type if needed
        Write-Warning "Get-GraphEssentialsAppOwners: Failed to get owners for SP $ServicePrincipalObjectId. Error: $($_.Exception.Message)"
        $OwnersList = @("Error fetching owners") # Indicate error in output
    }
    return $OwnersList
}