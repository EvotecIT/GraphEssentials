function Get-MyApp {
    <#
    .SYNOPSIS
    Retrieves Azure AD application (Service Principal) information from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed information about Azure AD/Entra Service Principals (Enterprise Apps) including display names, owners,
    client IDs, credential details (for owned apps), source, sign-in activity, and permissions.
    Uses helper functions in the Private folder for data retrieval steps.
    Can optionally include detailed credential information in the output objects.

    .PARAMETER ApplicationName
    Optional. The display name of a specific Service Principal (Enterprise App) to retrieve. If not specified, all are returned.
    Note: Filtering is applied *after* retrieving all SPs due to the need for expanded properties.

    .PARAMETER IncludeCredentials
    Switch parameter. When specified, includes detailed credential information (from Get-MyAppCredentials, requires corresponding Application object) in the output objects under the 'Keys' property.

    .EXAMPLE
    Get-MyApp
    Returns all Azure AD Service Principals (Enterprise Apps) with enhanced information.

    .EXAMPLE
    Get-MyApp -ApplicationName "MyAPI"
    Returns enhanced information for a specific Service Principal named "MyAPI".

    .EXAMPLE
    Get-MyApp -IncludeCredentials
    Returns all Service Principals with detailed credential information included under the 'Keys' property.

    .NOTES
    This function requires the Microsoft.Graph.Applications, Microsoft.Graph.ServicePrincipal, and potentially Microsoft.Graph.Reports modules and appropriate permissions.
    Requires Application.Read.All, AuditLog.Read.All, Directory.Read.All, Policy.Read.PermissionGrant policies.
    Focuses on Service Principals (Enterprise Apps) as the primary data source.
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
    $LastSignInMethodReport = Get-GraphEssentialsSignInLogsReport

    # --- Pre-fetch Service Principals with expanded assignments ---
    # This is now the primary list we'll iterate over.
    $allServicePrincipals = Get-GraphEssentialsSpDetailsAndAppRoles -GraphSpId $graphSpId -GraphAppRoles $graphAppRoles

    if (-not $allServicePrincipals) {
        Write-Warning "Get-MyApp: Failed to retrieve Service Principals. Report will be empty."
        return
    }

    # --- Optionally Fetch Application details for owned SPs (for credentials/notes) ---
    $OwnedApplicationDetails = @{}
    if ($IncludeCredentials -and $TenantId) {
        $ownedSpAppIds = $allServicePrincipals | Where-Object { $_.AppOwnerOrganizationId -eq $TenantId -and $_.AppId } | Select-Object -ExpandProperty AppId -Unique
        if ($ownedSpAppIds.Count -gt 0) {
            Write-Verbose "Get-MyApp: Found $($ownedSpAppIds.Count) owned Service Principals. Fetching corresponding Application objects for credentials..."
            # Build filter string for AppIds - handle potential large number of IDs
            $batchSize = 15 # Max IDs per filter clause recommended by MS Graph docs
            $numBatches = [Math]::Ceiling($ownedSpAppIds.Count / $batchSize)
            $appProperties = @('Id', 'AppId', 'Notes', 'PasswordCredentials', 'KeyCredentials') # Only properties needed
            $selectClause = "`$select=$(($appProperties -join ',' ))"

            for ($i = 0; $i -lt $numBatches; $i++) {
                $currentAppIds = $ownedSpAppIds | Select-Object -Skip ($i * $batchSize) -First $batchSize
                $appIdFilterPart = ($currentAppIds | ForEach-Object { "'$_'" }) -join ','
                $appFilter = "appId in ($appIdFilterPart)"
                $appUri = "/v1.0/applications?`$filter=$appFilter&$selectClause"
                Write-Verbose "Get-MyApp: Fetching Application batch $($i+1)/$numBatches..."
                try {
                    $appResponse = Invoke-MgGraphRequest -Uri $appUri -Method GET -ErrorAction Stop
                    # No paging expected/handled here as we filter by specific IDs
                    if ($appResponse -and $appResponse.value) {
                        $appResponse.value | ForEach-Object { $OwnedApplicationDetails[$_.AppId] = $_ }
                    }
                } catch {
                     Write-Warning "Get-MyApp: Failed to retrieve Application batch $($i+1). Credentials/Notes for some owned apps might be missing. Error: $($_.Exception.Message)"
                }
            }
            Write-Verbose "Get-MyApp: Finished fetching Application details. Found $($OwnedApplicationDetails.Count) matching applications."
        } else {
             Write-Verbose "Get-MyApp: No owned Service Principals found, skipping Application object fetch."
        }
    }

    # --- Filter Service Principals if ApplicationName is specified ---
    $ServicePrincipalsToProcess = $allServicePrincipals
    if ($ApplicationName) {
        Write-Verbose "Get-MyApp: Filtering Service Principals for DisplayName '$ApplicationName'..."
        $ServicePrincipalsToProcess = $allServicePrincipals | Where-Object { $_.DisplayName -eq $ApplicationName }
        Write-Verbose "Get-MyApp: Found $($ServicePrincipalsToProcess.Count) matching Service Principals."
        if ($ServicePrincipalsToProcess.Count -eq 0) {
            Write-Warning "Get-MyApp: No Service Principal found matching DisplayName '$ApplicationName'."
            return
        }
    }

    # --- Process Each Service Principal ---
    Write-Verbose "Get-MyApp: Converting $($ServicePrincipalsToProcess.Count) Service Principals to report objects..."
    $OutputApplications = foreach ($sp in $ServicePrincipalsToProcess) {
        # Get the optional merged Application details
        $appDetails = $OwnedApplicationDetails[$sp.AppId]

        # Pass SP and optional App details to the conversion function
        Convert-GraphEssentialsAppToReportObject -ServicePrincipal $sp `
            -ApplicationDetails $appDetails `
            -TenantId $TenantId `
            -AllDelegatedPermissions $AllDelegatedPermissions `
            -SignInActivityReport $SignInActivityReport `
            -LastSignInMethodReport $LastSignInMethodReport `
            -GraphSpId $graphSpId `
            -GraphAppRoles $graphAppRoles -IncludeCredentials:$IncludeCredentials
    }

    Write-Verbose "Get-MyApp: Finished processing Service Principals."
    return $OutputApplications
}