function Show-MyApp {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML
    )

    $Applications = Get-MyApp
    $ApplicationsPassword = Get-MyAppCredentials

    New-HTML {
        New-HTMLTableOption -DataStore JavaScript -BoolAsString

        New-HTMLSection -Invisible {
            New-HTMLSection -HeaderText "Applications" {
                New-HTMLTable -DataTable $Applications -Filtering {
                    New-TableEvent -ID 'TableAppsCredentials' -SourceColumnID 1 -TargetColumnID 1
                } -DataStore JavaScript -DataTableID "TableApps"
            }
            New-HTMLSection -HeaderText 'Applications Credentials' {
                New-HTMLTable -DataTable $ApplicationsPassword -Filtering {
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'ge' -BackgroundColor Conifer -ComparisonType number
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'lt' -BackgroundColor Orange -ComparisonType number
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 5 -Operator 'lt' -BackgroundColor Red -ComparisonType number
                    New-HTMLTableCondition -Name 'Expired' -Value $true -ComparisonType string -BackgroundColor Salmon -FailBackgroundColor Conifer
                } -DataStore JavaScript -DataTableID "TableAppsCredentials"
            }
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}