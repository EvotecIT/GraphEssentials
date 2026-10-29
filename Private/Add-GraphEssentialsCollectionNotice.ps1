function Add-GraphEssentialsCollectionNotice {
    <#
    .SYNOPSIS
    Displays collection problems independently of console diagnostic switches.
    .PARAMETER Issues
    Safe collection notices belonging to the current report.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]] $Issues
    )

    if ($Issues.Count -gt 0) {
        New-HTMLSection -HeaderText 'Collection notice - report may be incomplete' {
            foreach ($issue in $Issues) {
                New-HTMLText -Text "$($issue.TargetName): $($issue.Comment)" -Color Firebrick
            }
        }
    }
}
