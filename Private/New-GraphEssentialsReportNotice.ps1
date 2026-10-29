function New-GraphEssentialsReportNotice {
    <#
    .SYNOPSIS
    Renders a report notice within the viewport with a distinct information or warning tone.
    .PARAMETER Notices
    Safe report notices to display.
    .PARAMETER Tone
    Whether the notice describes report selection or a collection problem.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Notices,
        [Parameter(Mandatory)][ValidateSet('Information', 'Warning')][string] $Tone
    )

    if ($Notices.Count -eq 0) {
        return
    }

    if ($Tone -eq 'Warning') {
        $title = 'Warning: Collection notice - report may be incomplete'
        $headerColor = '#9a3412'
        $headerTextColor = 'White'
        $textColor = 'Firebrick'
        $role = 'alert'
        $class = 'graphEssentialsReportNotice graphEssentialsReportNoticeWarning'
    } else {
        $title = 'Report selection notice'
        $headerColor = '#e2e8f0'
        $headerTextColor = 'DarkSlateGrey'
        $textColor = 'DarkSlateGrey'
        $role = 'note'
        $class = 'graphEssentialsReportNotice graphEssentialsReportNoticeInformation'
    }

    New-HTMLTag -Tag 'div' -Attributes @{
        class = $class
        role = $role
        style = 'box-sizing:border-box;max-width:100vw;width:calc(100vw - 26px);min-width:0;overflow-wrap:anywhere;word-break:break-word'
    } -Value {
        New-HTMLSection -HeaderText $title -HeaderBackGroundColor $headerColor -HeaderTextColor $headerTextColor {
            foreach ($notice in $Notices) {
                New-HTMLText -Text "$($notice.TargetName): $($notice.Comment)" -Color $textColor
            }
        }
    }
}
