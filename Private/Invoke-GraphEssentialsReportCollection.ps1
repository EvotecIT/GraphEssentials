function Invoke-GraphEssentialsReportCollection {
    <#
    .SYNOPSIS
    Collects report data while retaining safe notices for incomplete collections.
    .PARAMETER Name
    The report section or collector name displayed in the notice.
    .PARAMETER Collect
    The existing collection operation to invoke.
    .PARAMETER Issues
    The report-owned list that receives notices without raw Graph response bodies.
    .PARAMETER Advisory
    An expected selector warning and its safe explanation for the report.
    .PARAMETER Notices
    The report-owned list that receives selector notices separately from collection failures.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $Collect,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]] $Issues,
        [AllowNull()][object] $Advisory,
        [AllowNull()][System.Collections.Generic.List[object]] $Notices
    )

    # Report coverage must not depend on the caller's console stream preferences.
    $WarningPreference = 'Continue'
    $ErrorActionPreference = 'Continue'
    try {
        & $Collect 2>&1 3>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.WarningRecord] -and $null -ne $Advisory -and $null -ne $Notices -and $_.Message -eq $Advisory.Message) {
                $Notices.Add([pscustomobject]@{
                    TargetName = $Name
                    Comment = $Advisory.Comment
                })
            } elseif ($_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.WarningRecord]) {
                # Response bodies and exception targets can contain credentials. Retain only a
                # fixed diagnostic and the trusted collector name, never the original record.
                $kind = if ($_ -is [System.Management.Automation.ErrorRecord]) { 'Error' } else { 'Warning' }
                $Issues.Add([pscustomobject]@{
                    Type = $kind
                    TargetName = $Name
                    Comment = 'Collection reported a problem. Data may be incomplete or unavailable. Check Microsoft Graph permissions, required licences, and throttling before interpreting empty tables.'
                    Reason = ''
                })
            } elseif ($_ -is [bool] -and $_ -eq $false) {
                $Issues.Add([pscustomobject]@{
                    Type = 'Error'
                    TargetName = $Name
                    Comment = 'Collection failed. Data is unavailable; an empty table does not mean there are no results.'
                    Reason = ''
                })
            } else {
                $_
            }
        }
    } catch {
        $Issues.Add([pscustomobject]@{
            Type = 'Error'
            TargetName = $Name
            Comment = 'Collection failed. Data may be incomplete or unavailable. Check Microsoft Graph permissions, required licences, and throttling before interpreting empty tables.'
            Reason = ''
        })
    }
}
