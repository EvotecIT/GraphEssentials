function Show-MyDefender {
    <#
    .SYNOPSIS
    Generates an HTML report for Microsoft Defender for Identity components.

    .DESCRIPTION
    Creates a comprehensive HTML report containing Microsoft Defender for Identity information including
    sensors, health issues, and secure scores. Deployment keys are never requested or included. The report is organized in tabs for
    easy navigation and analysis.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .EXAMPLE
    Show-MyDefender -FilePath "C:\Reports\DefenderReport.html"
    Generates a Microsoft Defender for Identity report and saves it to the specified path.

    .EXAMPLE
    Show-MyDefender -FilePath "C:\Reports\DefenderReport.html" -Online
    Generates a report, saves it to the specified path, and opens it in the default browser.

    .NOTES
    This function depends on several Get-MyDefender* functions to retrieve the data for the report.
    Requires appropriate Microsoft Graph permissions to access Microsoft Defender for Identity data.
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML
    )

    $Script:Reporting = [ordered] @{}
    $CollectionIssues = [System.Collections.Generic.List[object]]::new()
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    $DefenderHealthIssues = Invoke-GraphEssentialsReportCollection -Name 'Get-MyDefenderHealthIssues' -Issues $CollectionIssues -Collect { Get-MyDefenderHealthIssues -Status 'open' }
    $SecureScore = Invoke-GraphEssentialsReportCollection -Name 'Get-MyDefenderSecureScore' -Issues $CollectionIssues -Collect { Get-MyDefenderSecureScore }
    #$SecureProfile = Get-MyDefenderSecureScoreProfile
    $DefenderSensor = Invoke-GraphEssentialsReportCollection -Name 'Get-MyDefenderSensor' -Issues $CollectionIssues -Collect { Get-MyDefenderSensor }

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            Add-GraphEssentialsCollectionNotice -Issues $CollectionIssues
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "GraphEssentials - $($Script:Reporting['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        New-HTMLTab -Name "Defender Sensor" {
            New-HTMLSection -HeaderText "Defender Sensor" {
                New-HTMLTable -DataTable $DefenderSensor -Filtering {

                } -DataStore JavaScript -DataTableID "DefenderSensor" -PagingLength 5 -ScrollX
            }
        }
        New-HTMLTab -Name "Defender Health Issues" {
            New-HTMLSection -HeaderText "Defender Health Issues" {
                New-HTMLTable -DataTable $DefenderHealthIssues -Filtering {

                } -DataStore JavaScript -DataTableID "DefenderHealthIssues" -PagingLength 5 -ScrollX
            }
        }
        New-HTMLTab -Name "Defender Secure Score" {
            New-HTMLSection -HeaderText 'Defender Secure Score' {
                New-HTMLTable -DataTable $SecureScore -Filtering {

                } -DataStore JavaScript -DataTableID "SecureScore" -ScrollX
            }
        }
        # New-HTMLTab -Name "Defender Secure Profile" {
        #     New-HTMLSection -HeaderText 'Defender Secure Profile' {
        #         New-HTMLTable -DataTable $SecureProfile -Filtering {

        #         } -DataStore JavaScript -DataTableID "SecureProfile" -ScrollX
        #     }
        # }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}