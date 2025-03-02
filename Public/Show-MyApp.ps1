function Show-MyApp {
    <#
    .SYNOPSIS
    Generates an HTML report for Azure AD applications and their credentials.

    .DESCRIPTION
    Creates a comprehensive HTML report displaying information about Azure AD/Entra applications
    and their associated credentials. The report includes details about application owners,
    credential expiry dates, and other important application properties.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html"
    Generates an applications report and saves it to the specified path.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html" -Online
    Generates an applications report, saves it to the specified path, and opens it in the default browser.

    .NOTES
    This function requires the PSWriteHTML module and appropriate Microsoft Graph permissions.
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    $Applications = Get-MyApp
    $ApplicationsPassword = Get-MyAppCredentials

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "GraphEssentials - $($Script:Reporting['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        New-HTMLSection -HeaderText "Applications" {
            New-HTMLTable -DataTable $Applications -Filtering {
                New-TableEvent -ID 'TableAppsCredentials' -SourceColumnID 0 -TargetColumnID 0
            } -DataStore JavaScript -DataTableID "TableApps" -PagingLength 5 -ScrollX
        }
        New-HTMLSection -HeaderText 'Applications Credentials' {
            New-HTMLTable -DataTable $ApplicationsPassword -Filtering {
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'ge' -BackgroundColor Conifer -ComparisonType number
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'lt' -BackgroundColor Orange -ComparisonType number
                New-HTMLTableCondition -Name 'DaysToExpire' -Value 5 -Operator 'lt' -BackgroundColor Red -ComparisonType number
                New-HTMLTableCondition -Name 'Expired' -Value $true -ComparisonType string -BackgroundColor Salmon -FailBackgroundColor Conifer
            } -DataStore JavaScript -DataTableID "TableAppsCredentials" -ScrollX
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}