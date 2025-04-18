# Ensure private functions are loaded if this script is run directly
# Get-ChildItem -Path $PSScriptRoot\..\Private\*.ps1 | ForEach-Object { . $_.FullName }

function Get-MyApp {
    <#
    .SYNOPSIS
    Retrieves Azure AD application information from Microsoft Graph API, including sign-in activity and permissions.

    .DESCRIPTION
    Gets detailed information about Azure AD/Entra applications including display names, owners,
    client IDs, credential details, source (first/third party/Microsoft), sign-in activity, and permissions.
    Uses helper functions in the Private folder for data retrieval steps.
    Can optionally include detailed credential information in the output objects.

    .PARAMETER ApplicationName
    Optional. The display name of a specific application to retrieve. If not specified, all applications are returned.

    .PARAMETER IncludeCredentials
    Switch parameter. When specified, includes detailed credential information (from Get-MyAppCredentials) in the output objects under the 'Keys' property.

    .EXAMPLE
    Get-MyApp
    Returns all Azure AD applications with enhanced information.

    .EXAMPLE
    Get-MyApp -ApplicationName "MyAPI"
    Returns enhanced information for a specific application named "MyAPI".

    .EXAMPLE
    Get-MyApp -IncludeCredentials
    Returns all applications with detailed credential information included under the 'Keys' property.

    .NOTES
    This function requires the Microsoft.Graph.Applications, Microsoft.Graph.ServicePrincipal, and potentially Microsoft.Graph.Reports modules and appropriate permissions.
    Requires Application.Read.All, AuditLog.Read.All, Directory.Read.All, Policy.Read.PermissionGrant policies.
    Fetching permissions and sign-in logs can be time-consuming for large tenants.
    Depends on helper functions in the Private folder.
    #>
    [cmdletBinding()]
    param(
        [string] $ApplicationName,
        [switch] $IncludeCredentials
    )

    Write-Verbose "Get-MyApp: Starting data retrieval using private helper functions..."

    # --- Pre-fetch common data using Private functions ---
    $TenantId = Get-GraphEssentialsTenantId
    $graphSpInfo = Get-GraphEssentialsGraphSpInfo
    $graphSpId = if ($graphSpInfo) { $graphSpInfo.Id } else { $null }
    $graphAppRoles = if ($graphSpInfo) { $graphSpInfo.AppRoles } else { $null }

    $AllDelegatedPermissions = if ($graphSpId) {
        Get-GraphEssentialsDelegatedPermissions -GraphSpId $graphSpId
    } else {
        Write-Warning "Get-MyApp: Skipping delegated permission fetch because Graph SP Info was not found."
        @{}
    }

    $SignInActivityReport = Get-GraphEssentialsSignInActivityReport
    $LastSignInMethodReport = Get-GraphEssentialsSignInLogsReport # Defaults to 30 days

    # --- Pre-fetch Service Principals and Application Permissions ---
    $SpDetailsByAppId = @{}
    $AppPermissionsBySpId = @{}
    Write-Verbose "Get-MyApp: Fetching all Service Principals with App Role Assignments..."
    try {
        # Fetch SPs using Invoke-MgGraphRequest to allow $expand
        $spUri = "/v1.0/servicePrincipals?`$select=id,appId,displayName,appOwnerOrganizationId&`$expand=appRoleAssignments&`$top=999"
        $response = Invoke-MgGraphRequest -Uri $spUri -Method GET -ErrorAction Stop
        $allServicePrincipals = $response.value
        $NextLink = $response.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-MyApp: Fetching next page for service principals..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            $allServicePrincipals += $response.value
            $NextLink = $response.'@odata.nextLink'
        }

        Write-Verbose "Get-MyApp: Processing $($allServicePrincipals.Count) service principals..."
        foreach ($sp in $allServicePrincipals) {
            if (-not $sp.AppId) { continue } # Skip SPs without an AppId
            # Store SP details for lookup
            $SpDetailsByAppId[$sp.AppId] = [PSCustomObject]@{ SPId = $sp.Id; OwnerOrgId = $sp.AppOwnerOrganizationId }

            # Process and store Graph App Role assignments for this SP
            if ($graphSpId -and $graphAppRoles -and $sp.AppRoleAssignments) {
                $graphAssignments = $sp.AppRoleAssignments | Where-Object { $_.ResourceId -eq $graphSpId }
                if ($graphAssignments) {
                    $appRoles = $graphAssignments.AppRoleId | ForEach-Object { $graphAppRoles[$_].Value } | Sort-Object -Unique
                    if ($appRoles) {
                        $AppPermissionsBySpId[$sp.Id] = $appRoles
                    }
                }
            }
        }
        Write-Verbose "Get-MyApp: Finished processing SPs. Found details for $($SpDetailsByAppId.Count) AppIds and App Permissions for $($AppPermissionsBySpId.Count) SPs."

    } catch {
        Write-Warning "Get-MyApp: Failed to pre-fetch service principals or app role assignments. Source and Application permissions might be inaccurate. Error: $($_.Exception.Message)"
        # Depending on severity, might want to exit here
    }

    # --- Get Applications ---
    Write-Verbose "Get-MyApp: Fetching Applications..."
    $appFilter = ""
    $ApplicationsRaw = [System.Collections.Generic.List[object]]::new()
    $appProperties = @('Id', 'AppId', 'DisplayName', 'CreatedDateTime', 'Notes', 'PasswordCredentials', 'KeyCredentials')
    $selectClause = "`$select=$(($appProperties -join ',' ))"

    try {
        if ($ApplicationName) {
            $escapedAppName = $ApplicationName.Replace("'", "''")
            $appFilter = "displayName eq '$escapedAppName'"
            Write-Verbose "Get-MyApp: Filtering for ApplicationName: $ApplicationName"
            $uri = "/v1.0/applications?`$filter=$appFilter&$selectClause"
        } else {
            Write-Verbose "Get-MyApp: Fetching all applications."
            $uri = "/v1.0/applications?$selectClause"
        }

        # Manual Paging for Applications
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        if ($response -and $response.value) { $ApplicationsRaw.AddRange($response.value) }
        $NextLink = $response.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-MyApp: Fetching next page for applications..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            if ($response -and $response.value) { $ApplicationsRaw.AddRange($response.value) }
            $NextLink = $response.'@odata.nextLink'
        }
    } catch {
        Write-Warning "Get-MyApp: Failed to retrieve applications. Error: $($_.Exception.Message)"
        if ($ApplicationsRaw.Count -eq 0) {
            Write-Warning "Get-MyApp: No applications could be retrieved."
            return
        }
    }

    if (-not $ApplicationsRaw) {
        Write-Warning "Get-MyApp: No applications found or failed to retrieve applications."
        return
    }

    Write-Verbose "Get-MyApp: Processing $($ApplicationsRaw.Count) applications..."
    $Applications = foreach ($App in $ApplicationsRaw) {
        Write-Verbose "Get-MyApp: Processing App: $($App.DisplayName) ($($App.AppId))"

        # --- Look up pre-fetched SP data ---
        $spDetails = $SpDetailsByAppId[$App.AppId]
        $spId = $spDetails?.SPId
        $appOwnerOrganizationId = $spDetails?.OwnerOrgId
        $ApplicationScopes = if ($spId) { $AppPermissionsBySpId[$spId] } else { $null }

        # --- Determine Source (Improved Logic) ---
        $Source = "Unknown"
        if ($TenantId) {
            if ($appOwnerOrganizationId -eq $TenantId) {
                $Source = "First Party"
            } elseif ($null -eq $appOwnerOrganizationId) {
                 # Check common Microsoft tenant IDs if needed, otherwise assume internal/Microsoft
                 # For simplicity, classifying null OwnerOrgId as Microsoft when TenantId is known
                 $Source = "Microsoft"
            } else {
                $Source = "Third Party"
            }
        } else {
             # Fallback if TenantId couldn't be determined
             $Source = if ($null -ne $appOwnerOrganizationId) { "Third Party (Assumed)" } else { "First Party (Assumed)" }
        }

        # --- Get Credentials Details ---
        Write-Verbose "Get-MyApp: Getting credentials details for $($App.DisplayName)"
        [Array] $AppCredentialsDetails = Get-MyAppCredentials -ApplicationList $App

        # --- Get Owners (using private function) ---
        $Owners = Get-GraphEssentialsAppOwners -ApplicationObjectId $App.Id

        # --- Look up other pre-fetched data ---
        $SignInInfo = $SignInActivityReport[$App.AppId]
        $LastSignInMethod = $LastSignInMethodReport[$App.AppId]
        $DelegatedScopes = if ($spId) { $AllDelegatedPermissions[$spId] } else { $null }

        # Determine Combined Permission Type
        $PermissionType = "None"
        if ($DelegatedScopes -and $ApplicationScopes) {
            $PermissionType = "Delegated & Application"
        } elseif ($DelegatedScopes) {
            $PermissionType = "Delegated"
        } elseif ($ApplicationScopes) {
            $PermissionType = "Application"
        }

        # --- Credential Summary Calculation ---
        $DaysToExpireOldest = $null
        $DaysToExpireNewest = $null
        $KeysExpired = 'Not available'
        $KeysTypes = @()
        $KeysDescription = @()
        $DescriptionWithEmail = $false
        $KeysCount = 0
        $KeysDateOldest = $null
        $KeysDateNewest = $null
        if ($AppCredentialsDetails) {
            $KeysCount = $AppCredentialsDetails.Count
            $KeysTypes = $AppCredentialsDetails.Type | Sort-Object -Unique
            $KeysDescription = $AppCredentialsDetails.KeyDisplayName | Sort-Object -Unique
            $DaysToExpire = $AppCredentialsDetails.DaysToExpire | Where-Object { $_ -ne $null } | Sort-Object
            if ($DaysToExpire.Count -gt 0) {
                $DaysToExpireOldest = $DaysToExpire[0]
                $DaysToExpireNewest = $DaysToExpire[-1]
            }

            if ($AppCredentialsDetails.Expired -contains $true) {
                $KeysExpired = 'Yes'
                if (-not ($AppCredentialsDetails.Expired -contains $false)) {
                    $KeysExpired = 'All Yes'
                }
            } elseif ($AppCredentialsDetails.Expired -contains $false) {
                $KeysExpired = 'No'
            }

            foreach ($CredentialName in $AppCredentialsDetails.KeyDisplayName) {
                if ($CredentialName -like '*@*') {
                    $DescriptionWithEmail = $true
                    break
                }
            }
            [Array] $DatesSorted = $AppCredentialsDetails.StartDateTime | Where-Object { $_ -ne $null } | Sort-Object
            if ($DatesSorted.Count -gt 0) {
                $KeysDateOldest = $DatesSorted[0]
                $KeysDateNewest = $DatesSorted[-1]
            }
        }

        # --- Build Final Output Object ---
        $AppInformation = [ordered] @{
            # Core App Info
            ApplicationName       = $App.DisplayName
            ApplicationId         = $App.Id # ObjectId
            AppId                 = $App.AppId # ClientID
            CreatedDate           = $App.CreatedDateTime
            Source                = $Source # Updated Logic
            # Owners
            Owners                = $Owners
            # Permissions
            PermissionType        = $PermissionType # Should now be more accurate
            DelegatedPermissions  = $DelegatedScopes
            ApplicationPermissions= $ApplicationScopes # Should now be populated
            # Sign-in Activity
            DelegatedLastSignIn   = if ($SignInInfo -and $SignInInfo.PSObject.Properties['delegatedClientSignInActivity']) { $SignInInfo.delegatedClientSignInActivity.lastSignInDateTime } else { $null } # Standard null check
            ApplicationLastSignIn = if ($SignInInfo -and $SignInInfo.PSObject.Properties['applicationAuthenticationClientSignInActivity']) { $SignInInfo.applicationAuthenticationClientSignInActivity.lastSignInDateTime } else { $null } # Standard null check
            LastSignInMethod      = $LastSignInMethod
            # Credentials Summary
            KeysCount             = $KeysCount
            KeysTypes             = $KeysTypes
            KeysExpired           = $KeysExpired
            DaysToExpireOldest    = $DaysToExpireOldest
            DaysToExpireNewest    = $DaysToExpireNewest
            KeysDateOldest        = $KeysDateOldest
            KeysDateNewest        = $KeysDateNewest
            KeysDescription       = $KeysDescription
            DescriptionWithEmail  = $DescriptionWithEmail
            # Other
            Notes                 = $App.Notes
        }
        if ($IncludeCredentials) {
            $AppInformation['Keys'] = $AppCredentialsDetails
        }
        [PSCustomObject] $AppInformation
    } # End foreach ($App in $ApplicationsRaw)

    Write-Verbose "Get-MyApp: Finished processing applications."
    $Applications
}