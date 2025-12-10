function Add-AppsOverviewContent {
    <#
    .SYNOPSIS
    Renders the linked Apps + Credentials overview (two DataTables with cross-highlighting).

    .DESCRIPTION
    Designed to be reused both by Show-MyApp (full-page report) and by Invoke-MyGraphEssentials
    as a tab/section when the AppsOverview type is selected. Expects to be called inside an
    existing New-HTML context.
    #>
    [CmdletBinding()]
    param(
        [Array] $Applications,
        [Array] $Credentials,
        [string] $Version,
        [switch] $Embed
    )

    # --- Calculate Statistics ---
    $TotalApps = 0
    $DelegatedAppsCount = 0
    $ApplicationAppsCount = 0
    $ThirdPartyAppsCount = 0
    $InactiveAppsCount = 0
    $FirstPartyAppsCount = 0

    if ($Applications) {
        $UniqueAppIds = $Applications | Select-Object -ExpandProperty AppId -Unique
        $TotalApps = $UniqueAppIds.Count
        $AppsGrouped = $Applications | Group-Object -Property AppId

        foreach ($appGroup in $AppsGrouped) {
            $app = $appGroup.Group[0]
            if ($app.Source -eq 'Third Party') {
                $ThirdPartyAppsCount++
            } else {
                $FirstPartyAppsCount++
            }
            if ($app.PermissionType -match 'Delegated') { $DelegatedAppsCount++ }
            if ($app.PermissionType -match 'Application') { $ApplicationAppsCount++ }
            if (($null -eq $app.DelegatedLastSignIn) -and ($null -eq $app.ApplicationLastSignIn)) {
                $InactiveAppsCount++
            }
        }
    }

    # --- Pre-format data for HTML Table ---
    $FormattedApplications = @()
    if ($Applications) {
        $Today = Get-Date
        $FormattedApplications = $Applications | Select-Object *,
        @{n = 'DelegatedPermissionsList'; e = { if ($_.DelegatedPermissions) { ($_.DelegatedPermissions -join '; ') } else { 'None' } } },
        @{n = 'ApplicationPermissionsList'; e = { if ($_.ApplicationPermissions) { ($_.ApplicationPermissions -join '; ') } else { 'None' } } },
        @{n = 'OwnersList'; e = { if ($_.Owners) { ($_.Owners -join '; ') } else { 'Not collected' } } },
        @{n = 'KeysTypesList'; e = { if ($_.KeysTypes) { ($_.KeysTypes -join ', ') } else { 'None' } } },
        @{n = 'DelegatedSignInDate'; e = { if ($_.DelegatedLastSignIn) { Get-Date ($_.DelegatedLastSignIn) -Format 'yyyy-MM-dd HH:mm' } else { 'No activity' } } },
        @{n = 'DelegatedSignInDaysAgo'; e = { if ($_.DelegatedLastSignIn) { (New-TimeSpan -Start ($_.DelegatedLastSignIn) -End $Today).Days } else { $null } } },
        @{n = 'ApplicationSignInDate'; e = { if ($_.ApplicationLastSignIn) { Get-Date ($_.ApplicationLastSignIn) -Format 'yyyy-MM-dd HH:mm' } else { 'No activity' } } },
        @{n = 'ApplicationSignInDaysAgo'; e = { if ($_.ApplicationLastSignIn) { (New-TimeSpan -Start ($_.ApplicationLastSignIn) -End $Today).Days } else { $null } } },
        @{n = 'CreatedDateDisplay'; e = { if ($_.CreatedDate) { Get-Date ($_.CreatedDate) -Format 'yyyy-MM-dd' } else { '' } } },
        @{n = 'CreatedDateDaysAgo'; e = { if ($_.CreatedDate) { (New-TimeSpan -Start ($_.CreatedDate) -End $Today).Days } else { $null } } }
    }

    $ExcludedAppProperties = @(
        'Keys', 'DelegatedPermissions', 'ApplicationPermissions', 'Owners',
        'KeysTypes', 'DelegatedLastSignIn', 'ApplicationLastSignIn', 'CreatedDate',
        'DescriptionWithEmail', 'KeysDescription', 'KeysDateOldest', 'KeysDateNewest'
    )

    $renderOverviewTab = {
        New-HTMLSection -HeaderText "Application Overview" {
            New-HTMLSection -Density Dense -Invisible {
                New-HTMLInfoCard -Title "Total Applications" -Number $TotalApps -Subtitle "All registered applications" -Icon "📱" -IconColor "#0078d4" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                New-HTMLInfoCard -Title "First-Party Apps" -Number $FirstPartyAppsCount -Subtitle "$(if ($TotalApps -gt 0) { "$([math]::Round(($FirstPartyAppsCount / $TotalApps) * 100, 0))% of total" } else { "0% of total" })" -Icon "🏢" -IconColor "#198754" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                $MicrosoftAppsCount = if ($Applications) { ($Applications | Where-Object { $_.Source -eq 'Microsoft' }).Count } else { 0 }
                New-HTMLInfoCard -Title "Microsoft Apps" -Number $MicrosoftAppsCount -Subtitle "Microsoft-owned applications" -Icon "🔷" -IconColor "#0078d4" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                New-HTMLInfoCard -Title "Third-Party Apps" -Number $ThirdPartyAppsCount -Subtitle "$(if ($TotalApps -gt 0) { "$([math]::Round(($ThirdPartyAppsCount / $TotalApps) * 100, 0))% of total" } else { "0% of total" })" -Icon "🌐" -IconColor "#fd7e14" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
            }

            New-HTMLSection -Density Dense -Invisible {
                New-HTMLInfoCard -Title "Delegated Permissions" -Number $DelegatedAppsCount -Subtitle "Apps with user-consented permissions" -Icon "👤" -IconColor "#6f42c1" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                New-HTMLInfoCard -Title "Application Permissions" -Number $ApplicationAppsCount -Subtitle "Apps with admin-consented permissions" -Icon "🔒" -IconColor "#dc3545" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                New-HTMLInfoCard -Title "Inactive Apps" -Number $InactiveAppsCount -Subtitle "$(if ($TotalApps -gt 0) { "$([math]::Round(($InactiveAppsCount / $TotalApps) * 100, 0))% with no sign-in activity" } else { "0% with no sign-in activity" })" -Icon "⚠️" -IconColor "#ffc107" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px -ShadowColor 'rgba(255, 193, 7, 0.3)'
                $ExpiredCredsCount = if ($Applications) { ($Applications | Where-Object { $_.KeysExpired -in @('Yes', 'All Yes') }).Count } else { 0 }
                New-HTMLInfoCard -Title "Apps with Expired Credentials" -Number $ExpiredCredsCount -Subtitle "$(if ($TotalApps -gt 0) { "$([math]::Round(($ExpiredCredsCount / $TotalApps) * 100, 0))% need credential renewal" } else { "0% need credential renewal" })" -Icon "🔑" -IconColor "#dc3545" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px -ShadowColor 'rgba(220, 53, 69, 0.3)'
            }

            if ($Applications) {
                New-HTMLSection -HeaderText "Overview Charts" -Collapsable {
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Source' {
                            ($Applications | Group-Object Source) | ForEach-Object { New-ChartPie -Name $_.Name -Value $_.Count }
                        }
                    }
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Permission Type' {
                            ($Applications | Group-Object PermissionType) | ForEach-Object { New-ChartPie -Name $_.Name -Value $_.Count }
                        }
                    }
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Credential Expiry' {
                            $ExpiryCounts = $Applications | Group-Object KeysExpired | Select-Object Name, Count
                            $Categories = @{ 'No' = 0; 'Yes' = 0; 'All Yes' = 0; 'Not available' = 0 }
                            $ExpiryCounts | ForEach-Object { $Categories[$_.Name] = $_.Count }
                            New-ChartPie -Name 'Not Expired'   -Value $Categories['No']
                            New-ChartPie -Name 'Some Expired'  -Value $Categories['Yes']
                            New-ChartPie -Name 'All Expired'   -Value $Categories['All Yes']
                            New-ChartPie -Name 'No Credentials' -Value $Categories['Not available']
                        }
                    }
                } -Invisible
            }
        } -Wrap wrap
    }

    $renderApplicationsTab = {
        New-HTMLSection -HeaderText "Application Details" {
            New-HTMLPanel -Invisible {
                New-HTMLContainer {
                    New-HTMLText -FontSize 11pt -TextBlock {
                        "Complete list of applications. Click an application row to highlight its credentials in the table below."
                    }
                }

                New-HTMLContainer {
                    if ($FormattedApplications) {
                        New-HTMLTable -DataTable $FormattedApplications -ExcludeProperty $ExcludedAppProperties -Filtering {
                            New-TableCondition -Name 'Source' -Value 'Third Party' -BackgroundColor LightCoral -ComparisonType string
                            New-TableCondition -Name 'Source' -Value 'Microsoft'    -BackgroundColor LightBlue  -ComparisonType string
                            New-TableCondition -Name 'PermissionType' -Value 'Application' -BackgroundColor LightSalmon -ComparisonType string
                            New-TableCondition -Name 'PermissionType' -Value 'Delegated & Application' -BackgroundColor LightSalmon -ComparisonType string
                            New-TableCondition -Name 'KeysExpired' -Value 'Yes' -BackgroundColor OrangeRed -ComparisonType string -Operator contains
                            New-TableCondition -Name 'KeysExpired' -Value 'All Yes' -BackgroundColor Red -ComparisonType string -Operator contains
                            New-TableCondition -Name 'DelegatedSignInDate'   -Value 'No activity' -BackgroundColor LightGray -ComparisonType string
                            New-TableCondition -Name 'ApplicationSignInDate' -Value 'No activity' -BackgroundColor LightGray -ComparisonType string
                            New-TableCondition -Name 'DelegatedSignInDaysAgo'   -Value 7  -Operator 'le' -BackgroundColor LightGreen -ComparisonType number
                            New-TableCondition -Name 'ApplicationSignInDaysAgo' -Value 7  -Operator 'le' -BackgroundColor LightGreen -ComparisonType number
                            New-TableCondition -Name 'CreatedDateDaysAgo'       -Value 30 -Operator 'le' -BackgroundColor LightBlue  -ComparisonType number
                            New-TableEvent -SourceColumnName 'ApplicationName' -TargetColumnID 0 -TableID 'TableAppsCredentials'
                        } -DataStore JavaScript -DataTableID "TableApps" -PagingLength 7 -ScrollX -WarningAction SilentlyContinue -PagingOptions 7, 15, 25, 50, 100
                    } else {
                        New-HTMLText -Text "No application data to display." -Color Orange
                    }
                }
            }
        }

        New-HTMLSection -HeaderText "Application Credentials & Expiry Details" {
            New-HTMLPanel -Invisible {
                New-HTMLContainer {
                    New-HTMLText -FontSize 11pt -TextBlock {
                        "Detailed view of application credentials (certs, secrets, federated IDs). Red = expiring in <5 days, orange <30."
                    }
                }

                New-HTMLContainer {
                    if ($Credentials) {
                        $CredentialColumns = @(
                            'ApplicationName','Type','KeyDisplayName','KeyId','Hint',
                            'Expired','DaysToExpire','StartDateTime','EndDateTime'
                        )
                        New-HTMLTable -DataTable ($Credentials | Select-Object $CredentialColumns) -Filtering {
                            New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'ge' -BackgroundColor Conifer -ComparisonType number
                            New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'lt' -BackgroundColor Orange  -ComparisonType number
                            New-HTMLTableCondition -Name 'DaysToExpire' -Value 5  -Operator 'lt' -BackgroundColor Red     -ComparisonType number
                            New-HTMLTableCondition -Name 'Expired' -Value $true -ComparisonType bool -BackgroundColor Salmon -FailBackgroundColor Conifer
                        } -DataStore JavaScript -DataTableID "TableAppsCredentials" -ScrollX -PagingLength 7 -WarningAction SilentlyContinue -PagingOptions 7, 15, 25, 50, 100
                    } else {
                        New-HTMLText -Text "No detailed credential data to display." -Color Orange
                    }
                }
            }
        }
    }

    if ($Embed) {
        & $renderOverviewTab
        & $renderApplicationsTab
    } else {
        New-HTMLTab -Name "Overview" { & $renderOverviewTab }
        New-HTMLTab -Name "All Applications ($TotalApps)" { & $renderApplicationsTab }
    }
}
