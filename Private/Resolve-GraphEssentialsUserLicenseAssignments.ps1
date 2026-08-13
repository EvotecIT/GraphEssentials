function Resolve-GraphEssentialsUserLicenseAssignments {
    <#
    .SYNOPSIS
    Normalizes Microsoft Graph user license assignments.

    .DESCRIPTION
    Combines the detailed LicenseAssignmentStates collection with AssignedLicenses. Detailed
    assignment state is preserved when available, while AssignedLicenses supplies any SKU that
    is missing from the state collection.

    .PARAMETER User
    Microsoft Graph user object containing LicenseAssignmentStates and AssignedLicenses.

    .PARAMETER LicenseLookup
    Dictionary that maps Microsoft Graph SKU identifiers to display names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $User,
        [Parameter(Mandatory)][System.Collections.IDictionary] $LicenseLookup
    )

    $StateSkuIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($License in @($User.LicenseAssignmentStates)) {
        if ($null -eq $License -or $null -eq $License.SkuId) {
            continue
        }

        $SkuId = [string] $License.SkuId
        $null = $StateSkuIds.Add($SkuId)
        $LicenseName = $LicenseLookup[$License.SkuId]
        $KnownSku = [bool] $LicenseName
        if (-not $KnownSku) {
            $LicenseName = $SkuId
        }

        if ($License.State -eq 'Active' -and $License.AssignedByGroup) {
            $Status = 'Group'
        } elseif ($License.State -eq 'Active') {
            $Status = 'Direct'
        } elseif ($License.State) {
            $Status = [string] $License.State
        } else {
            $Status = 'Unknown'
        }

        [PSCustomObject] @{
            SkuId       = $SkuId
            Name        = [string] $LicenseName
            Status      = $Status
            Error       = if ($License.Error) { [string] $License.Error } else { $null }
            KnownSku    = $KnownSku
            DetailState = $true
        }
    }

    foreach ($License in @($User.AssignedLicenses)) {
        if ($null -eq $License -or $null -eq $License.SkuId) {
            continue
        }

        $SkuId = [string] $License.SkuId
        if ($StateSkuIds.Contains($SkuId)) {
            continue
        }

        $LicenseName = $LicenseLookup[$License.SkuId]
        $KnownSku = [bool] $LicenseName
        if (-not $KnownSku) {
            $LicenseName = $SkuId
        }

        [PSCustomObject] @{
            SkuId       = $SkuId
            Name        = [string] $LicenseName
            Status      = 'Assigned'
            Error       = $null
            KnownSku    = $KnownSku
            DetailState = $false
        }
    }
}
