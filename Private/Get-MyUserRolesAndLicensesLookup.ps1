function Get-MyUserRolesAndLicensesLookup {
    <#
    .SYNOPSIS
    Builds per-user lookups for directory roles and licenses using existing data sources.

    .DESCRIPTION
    Reuses Get-MyRoleUsers (and its embedded license info) to construct a hashtable mapping
    UserPrincipalName to role names and license names. When -AllUsers is specified, all users
    are included; otherwise, only users with at least one role are queried for performance.

    .PARAMETER AllUsers
    When provided, includes all users in the role query (no -OnlyWithRoles filter). If omitted,
    only users with roles are retrieved.

    .OUTPUTS
    PSCustomObject with two properties:
      - Roles    : Hashtable [string upn] -> [string[] roleNames]
      - Licenses : Hashtable [string upn] -> [string[] licenseNames]
    #>
    [CmdletBinding()]
    param(
        [switch] $AllUsers
    )

    try {
        $getParams = @{}
        if (-not $AllUsers) { $getParams['OnlyWithRoles'] = $true }
        $data = Get-MyRoleUsers @getParams
    } catch {
        Write-Warning -Message "Get-MyUserRolesAndLicensesLookup - Failed to get role users. Error: $($_.Exception.Message)"
        return $null
    }
    if (-not $data) { return $null }

    $rolesLookup = @{}
    $licensesLookup = @{}
    $licenseServicesLookup = @{}
    foreach ($entry in $data) {
        $upn = $entry.UserPrincipalName
        if (-not $upn) { continue }

        # Aggregate roles from direct, eligible, and group-based
        $roles = [System.Collections.Generic.List[string]]::new()
        if ($entry.Direct)            { foreach ($r in $entry.Direct)            { if ($r) { $roles.Add([string]$r) } } }
        if ($entry.Eligible)          { foreach ($r in $entry.Eligible)          { if ($r) { $roles.Add([string]$r) } } }
        if ($entry.GroupDirectRoles)  { foreach ($r in $entry.GroupDirectRoles)  { if ($r) { $roles.Add([string]$r) } } }
        if ($entry.GroupEligibleRoles){ foreach ($r in $entry.GroupEligibleRoles){ if ($r) { $roles.Add([string]$r) } } }

        if ($roles.Count -gt 0) {
            $rolesLookup[$upn] = $roles | Sort-Object -Unique
        }
        if ($entry.Licenses) {
            $licensesLookup[$upn] = $entry.Licenses
        }
        if ($entry.LicenseServices) {
            $licenseServicesLookup[$upn] = $entry.LicenseServices
        }
    }

    [PSCustomObject]@{
        Roles           = $rolesLookup
        Licenses        = $licensesLookup
        LicenseServices = $licenseServicesLookup
    }
}
