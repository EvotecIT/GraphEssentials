function Get-GraphEssentialsDelegatedPermissions {
    param(
        [string]$GraphSpId # The Object ID of the Microsoft Graph Service Principal
    )
    Write-Verbose "Get-GraphEssentialsDelegatedPermissions: Fetching OAuth2 Delegated Permissions for Graph SP ($GraphSpId)..."
    # Note: Requires Policy.Read.PermissionGrant
    $AllDelegatedPermissions = @{}
    if (-not $GraphSpId) {
        Write-Warning "Get-GraphEssentialsDelegatedPermissions: Graph Service Principal ID not provided. Cannot fetch permissions."
        return $AllDelegatedPermissions
    }

    try {
        $coreDelegatedPermissions = @()

        # Tenant-wide grants (admin consent)
        $uriAll = "v1.0/oauth2PermissionGrants?`$filter=consentType eq 'AllPrincipals' and resourceId eq '$GraphSpId'&`$top=999"
        $response = Invoke-MgGraphRequest -Uri $uriAll -Method GET -OutputType PSObject -ErrorAction Stop
        if ($response.value) { $coreDelegatedPermissions += $response.value }
        $NextLink = $response.'@odata.nextLink'
        while ($NextLink) {
            Write-Verbose "Get-GraphEssentialsDelegatedPermissions: Fetching next page for delegated permissions (AllPrincipals)..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -OutputType PSObject -ErrorAction Stop
            if ($response.value) { $coreDelegatedPermissions += $response.value }
            $NextLink = $response.'@odata.nextLink'
        }

        # Per-user grants (self-consent). Can be numerous; we only need app-level scope list.
        $uriUser = "v1.0/oauth2PermissionGrants?`$filter=consentType eq 'Principal' and resourceId eq '$GraphSpId'&`$top=999"
        $response = Invoke-MgGraphRequest -Uri $uriUser -Method GET -OutputType PSObject -ErrorAction Stop
        if ($response.value) { $coreDelegatedPermissions += $response.value }
        $NextLink = $response.'@odata.nextLink'
        while ($NextLink) {
            Write-Verbose "Get-GraphEssentialsDelegatedPermissions: Fetching next page for delegated permissions (Principal)..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -OutputType PSObject -ErrorAction Stop
            if ($response.value) { $coreDelegatedPermissions += $response.value }
            $NextLink = $response.'@odata.nextLink'
        }

        if ($coreDelegatedPermissions) {
            # Group by ServicePrincipalId (ClientId in the grant refers to the consuming SP)
            $coreDelegatedPermissions | Group-Object ClientId | ForEach-Object {
                # Scope property contains space-separated scopes
                $scopes = ($_.Group | Select-Object -ExpandProperty Scope) -split ' ' | Where-Object { $_ -ne '' } | Sort-Object -Unique
                $AllDelegatedPermissions[$_.Name] = $scopes
            }
            Write-Verbose "Get-GraphEssentialsDelegatedPermissions: Fetched delegated permissions for $($AllDelegatedPermissions.Count) apps."
        } else {
             Write-Verbose "Get-GraphEssentialsDelegatedPermissions: No delegated permission grants found."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsDelegatedPermissions: Failed to retrieve OAuth2 Permission Grants. Delegated permissions will be unavailable. Error: $($_.Exception.Message)"
        if ($_.Exception.ToString() -like '*Authorization_RequestDenied*' -or $_.Exception.ToString() -like '*Permission*' -or $_.Exception.Message -like '*Forbidden*') {
            Write-Warning "Get-GraphEssentialsDelegatedPermissions: Missing Policy.Read.PermissionGrant (or equivalent) permission."
        }
    }
    return $AllDelegatedPermissions
}
