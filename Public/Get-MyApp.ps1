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
    $graphAppRoles = if ($graphSpInfo) { $graphSpInfo.AppRoles } else { $null } # Needed for SP processing

    $AllDelegatedPermissions = if ($graphSpId) {
        Get-GraphEssentialsDelegatedPermissions -GraphSpId $graphSpId
    } else {
        Write-Warning "Get-MyApp: Skipping delegated permission fetch because Graph SP Info was not found."
        @{}
    }

    $SignInActivityReport = Get-GraphEssentialsSignInActivityReport
    $LastSignInMethodReport = Get-GraphEssentialsSignInLogsReport # Defaults to 30 days

    # --- Pre-fetch Service Principals and Application Permissions (using private function) ---
    $SpData = $null
    $SpDetailsByAppId = @{}
    $AppPermissionsBySpId = @{}
    if ($graphSpId -and $graphAppRoles) {
        $SpData = Get-GraphEssentialsSpDetailsAndAppRoles -GraphSpId $graphSpId -GraphAppRoles $graphAppRoles
        if ($SpData) {
            $SpDetailsByAppId = $SpData.SpDetails
            $AppPermissionsBySpId = $SpData.AppPermissions
        }
        # Error handling happens within the private function
    } else {
         Write-Warning "Get-MyApp: Skipping Service Principal / App Role Assignment fetch because Graph SP Info was not found."
    }

    # --- Get Applications (using private function) ---
    $ApplicationsRaw = Get-GraphEssentialsApplications -ApplicationName $ApplicationName

    if (-not $ApplicationsRaw -or $ApplicationsRaw.Count -eq 0) {
        Write-Warning "Get-MyApp: No applications found or failed to retrieve applications."
        return
    }

    # --- Process Each Application (using private function) ---
    Write-Verbose "Get-MyApp: Converting $($ApplicationsRaw.Count) raw applications to report objects..."
    $Applications = foreach ($App in $ApplicationsRaw) {
        # Pass all necessary pre-fetched data to the conversion function
        Convert-GraphEssentialsAppToReportObject -App $App `
            -TenantId $TenantId `
            -SpDetailsByAppId $SpDetailsByAppId `
            -AppPermissionsBySpId $AppPermissionsBySpId `
            -AllDelegatedPermissions $AllDelegatedPermissions `
            -SignInActivityReport $SignInActivityReport `
            -LastSignInMethodReport $LastSignInMethodReport `
            -IncludeCredentials:$IncludeCredentials
    }

    Write-Verbose "Get-MyApp: Finished processing applications."
    return $Applications
}