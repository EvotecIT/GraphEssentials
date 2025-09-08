function Get-GraphEssentialsSpDetailsAndAppRoles {
    param(
        # Required parameters from Get-GraphEssentialsGraphSpInfo
        [Parameter(Mandatory)]
        [string]$GraphSpId,
        [Parameter(Mandatory)]
        [hashtable]$GraphAppRoles
    )

    $SpDetailsByAppId = @{}
    $AppPermissionsBySpId = @{}
    Write-Verbose "Get-GraphEssentialsSpDetailsAndAppRoles: Fetching all Service Principals with App Role Assignments..."

    if (-not $GraphSpId -or -not $GraphAppRoles) {
        Write-Warning "Get-GraphEssentialsSpDetailsAndAppRoles: Cannot proceed without Graph SP ID and Graph App Roles."
        return [PSCustomObject]@{ SpDetails = $SpDetailsByAppId; AppPermissions = $AppPermissionsBySpId } # Return empty tables
    }

    try {
        # Fetch SPs using Invoke-MgGraphRequest to allow $expand
        $spUri = "/v1.0/servicePrincipals?`$select=id,appId,displayName,appOwnerOrganizationId,servicePrincipalType&`$expand=appRoleAssignments&`$top=999"
        $response = Invoke-MgGraphRequest -Uri $spUri -Method GET -ErrorAction Stop
        $allServicePrincipals = $response.value
        $NextLink = $response.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-GraphEssentialsSpDetailsAndAppRoles: Fetching next page for service principals..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            $allServicePrincipals += $response.value
            $NextLink = $response.'@odata.nextLink'
        }

        Write-Verbose "Get-GraphEssentialsSpDetailsAndAppRoles: Processing $($allServicePrincipals.Count) service principals..."
        foreach ($sp in $allServicePrincipals) {
            if (-not $sp.AppId) { continue } # Skip SPs without an AppId
            # Store SP details for lookup
            $SpDetailsByAppId[$sp.AppId] = [PSCustomObject]@{ SPId = $sp.Id; OwnerOrgId = $sp.AppOwnerOrganizationId }

            # Process and store Graph App Role assignments for this SP
            if ($sp.AppRoleAssignments) {
                $graphAssignments = $sp.AppRoleAssignments | Where-Object { $_.ResourceId -eq $GraphSpId }
                if ($graphAssignments) {
                    $appRoles = $graphAssignments.AppRoleId | ForEach-Object { $GraphAppRoles[$_].Value } | Sort-Object -Unique
                    if ($appRoles) {
                        $AppPermissionsBySpId[$sp.Id] = $appRoles
                    }
                }
            }
        }
        Write-Verbose "Get-GraphEssentialsSpDetailsAndAppRoles: Finished processing SPs. Found details for $($SpDetailsByAppId.Count) AppIds and App Permissions for $($AppPermissionsBySpId.Count) SPs."

    } catch {
        Write-Warning "Get-GraphEssentialsSpDetailsAndAppRoles: Failed to fetch/process service principals or app role assignments. Source and Application permissions might be inaccurate. Error: $($_.Exception.Message)"
        # Return potentially incomplete results
    }

    # Return the list of service principals directly
    return $allServicePrincipals
}