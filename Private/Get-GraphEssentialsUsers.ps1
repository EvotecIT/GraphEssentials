function Get-GraphEssentialsUsers {
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

    $Properties = @($Request.Property | Where-Object { $_ -ne 'SignInActivity' })
    if ($IncludeSignInActivity) {
        $Properties += 'SignInActivity'
    }
    $Request.Property = $Properties

    try {
        $Users = @(Get-MgUser @Request -ErrorAction Stop)
        $SignInActivityAvailable = [bool] $IncludeSignInActivity
    } catch {
        $GraphErrorMessage = [string] $_.Exception.Message
        $IsMissingAuditPermission = $IncludeSignInActivity -and
            $GraphErrorMessage -match 'AuditLog\.Read\.All' -and
            $GraphErrorMessage -match '(403|Forbidden|permission)'
        if (-not $IsMissingAuditPermission) {
            throw
        }

        $Request.Property = @($Properties | Where-Object { $_ -ne 'SignInActivity' })
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
