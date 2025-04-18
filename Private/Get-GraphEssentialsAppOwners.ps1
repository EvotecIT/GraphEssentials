function Get-GraphEssentialsAppOwners {
    param(
        [string]$ApplicationObjectId # The Object ID of the Application (not AppId/ClientID)
    )
    Write-Verbose "Get-GraphEssentialsAppOwners: Fetching owners for Application ObjectId $ApplicationObjectId..."
    # Note: Requires Directory.Read.All or Application.Read.All
    $Owners = @()
    if (-not $ApplicationObjectId) {
        Write-Warning "Get-GraphEssentialsAppOwners: Application Object ID not provided. Cannot fetch owners."
        return $Owners
    }

    try {
        # Use Invoke-MgGraphRequest with manual paging
        $uri = "/v1.0/applications/$ApplicationObjectId/owners"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        $rawOwners = $response.value
        $NextLink = $response.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-GraphEssentialsAppOwners: Fetching next page for owners of $ApplicationObjectId..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            $rawOwners += $response.value
            $NextLink = $response.'@odata.nextLink'
        }

        if ($rawOwners) {
            $Owners = $rawOwners | ForEach-Object {
                # Access properties carefully based on object type
                # Prefer UPN for users, DisplayName otherwise, fallback to ID
                $upn = $_.userPrincipalName # Directly available on user objects
                $dispName = $_.displayName # Available on users, groups, SPs
                if ($upn) { $upn } elseif ($dispName) { $dispName } else { $_.Id }
            }
            Write-Verbose "Get-GraphEssentialsAppOwners: Found $($Owners.Count) owners for Application $ApplicationObjectId."
        } else {
            Write-Verbose "Get-GraphEssentialsAppOwners: No owners found for Application $ApplicationObjectId."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsAppOwners: Failed to get owners for App $ApplicationObjectId. Error: $($_.Exception.Message)"
        $Owners = @("Error fetching owners") # Indicate error in output
    }
    return $Owners
}