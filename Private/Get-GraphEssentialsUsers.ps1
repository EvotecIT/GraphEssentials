function Get-GraphEssentialsUsers {
    <#
    .SYNOPSIS
    Retrieves Microsoft Graph users with optional sign-in activity.

    .DESCRIPTION
    Executes a Get-MgUser query and adds SignInActivity only when requested. If Microsoft
    Graph rejects that optional property because the caller lacks permission, the query is
    retried without sign-in activity so the remaining user data is still returned.

    .PARAMETER Query
    Parameters forwarded to Get-MgUser.

    .PARAMETER CommandName
    Public command name used in diagnostics.

    .PARAMETER IncludeSignInActivity
    Requests the SignInActivity property. This requires AuditLog.Read.All.

    .EXAMPLE
    Get-GraphEssentialsUsers -Query @{ All = $true; Property = @('Id') } -CommandName 'Get-MyUser' -IncludeSignInActivity

    .NOTES
    This internal helper preserves PowerShell 5.1 compatibility and retries only when an
    explicitly requested sign-in activity query encounters a Graph permission denial.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Query,
        [Parameter(Mandatory)][string] $CommandName,
        [switch] $IncludeSignInActivity
    )

    $Request = @{}
    foreach ($Entry in $Query.GetEnumerator()) {
        $Request[$Entry.Key] = $Entry.Value
    }

    $PropertiesWithoutSignInActivity = @(
        foreach ($Property in @($Request.Property)) {
            if ($Property -ne 'SignInActivity') {
                $Property
            }
        }
    )
    $Properties = @(
        $PropertiesWithoutSignInActivity
        if ($IncludeSignInActivity) {
            'SignInActivity'
        }
    )
    $Request.Property = $Properties

    try {
        $Users = @(Get-MgUser @Request -ErrorAction Stop)
        $SignInActivityAvailable = [bool] $IncludeSignInActivity
    } catch {
        $GraphError = $_ | Get-GraphEssentialsErrorDetails -FunctionName $CommandName
        $IsMissingAuditPermission = $IncludeSignInActivity -and
            ($GraphError.IsPermissionDenied -or
            $GraphError.StatusCode -eq 403 -or
            $GraphError.Code -match '(?i)Authorization_RequestDenied|accessDenied|Forbidden')
        if (-not $IsMissingAuditPermission) {
            throw
        }

        $Request.Property = $PropertiesWithoutSignInActivity
        Write-Warning -Message "$CommandName - AuditLog.Read.All is not available. Retrying without sign-in activity; user and license data will still be returned."
        $Users = @(Get-MgUser @Request -ErrorAction Stop)
        $SignInActivityAvailable = $false
    }

    [PSCustomObject] @{
        Users                       = $Users
        SignInActivityRequested     = [bool] $IncludeSignInActivity
        SignInActivityAvailable     = $SignInActivityAvailable
    }
}
