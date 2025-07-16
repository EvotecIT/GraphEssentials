function Show-MyApp {
    <#
    .SYNOPSIS
    Generates an HTML report for Azure AD applications, their credentials, permissions, and activity.

    .DESCRIPTION
    Creates a comprehensive HTML report displaying information about Azure AD/Entra applications,
    including owners, credential details, source (first/third party), permissions (delegated/application),
    sign-in activity, and credential expiry. Includes summary statistics.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .PARAMETER ApplicationType
    Specifies the type of applications to include in the report.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html"
    Generates an applications report and saves it to the specified path.

    .EXAMPLE
    Show-MyApp -FilePath "C:\Reports\Applications.html" -Online
    Generates an applications report, saves it to the specified path, and opens it in the default browser.

    .NOTES
    This function requires the PSWriteHTML module and the enhanced Get-MyApp function.
    Ensure appropriate Microsoft Graph permissions are granted for Get-MyApp (Application.Read.All, AuditLog.Read.All, etc.).
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [ValidateSet('All', 'AppRegistrations', 'EnterpriseApps', 'MicrosoftApps', 'ManagedIdentities')]
        [string]$ApplicationType = 'All'
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    # --- Get Enhanced Application Data ---
    Write-Verbose "Show-MyApp: Getting application data using Get-MyApp (ApplicationType: $ApplicationType)..."
    $Applications = Get-MyApp -ApplicationType $ApplicationType
    if (-not $Applications) {
        Write-Warning "Show-MyApp: No application data received from Get-MyApp. Report will be incomplete."
        # Optionally exit or continue with an empty report
        # return
    }

    # --- Get Detailed Credentials Data (for second table) ---
    # Get-MyApp now includes summary info, but we still need details for the expiry table
    Write-Verbose "Show-MyApp: Getting detailed credentials using Get-MyAppCredentials..."
    $ApplicationsPassword = Get-MyAppCredentials # Fetch details for all apps for the second table
    if (-not $ApplicationsPassword) {
        Write-Warning "Show-MyApp: No detailed credential data received from Get-MyAppCredentials. Credentials table will be empty."
    }

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

        # Group by AppId first to avoid double-counting if an app has both Delegated & App perms listed separately
        # Note: Get-MyApp now returns one object per App, so grouping might not be strictly needed if PermissionType handles 'Both'
        $AppsGrouped = $Applications | Group-Object -Property AppId

        foreach ($appGroup in $AppsGrouped) {
            $app = $appGroup.Group[0] # Take the first instance for stats

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
    # Format dates and lists for better display
    $FormattedApplications = @()
    if ($Applications) {
        $Today = Get-Date # Get today's date once for efficiency
        $FormattedApplications = $Applications | Select-Object *,
        # Permissions Lists
        @{n = 'DelegatedPermissionsList'; e = { if ($_.DelegatedPermissions) { ($_.DelegatedPermissions -join '; ') } else { 'None' } } },
        @{n = 'ApplicationPermissionsList'; e = { if ($_.ApplicationPermissions) { ($_.ApplicationPermissions -join '; ') } else { 'None' } } },
        # Owners List
        @{n = 'OwnersList'; e = { if ($_.Owners) { ($_.Owners -join '; ') } else { 'None' } } },
        # Credential Types List
        @{n = 'KeysTypesList'; e = { if ($_.KeysTypes) { ($_.KeysTypes -join ', ') } else { 'None' } } },
        # Date Formatting and Days Ago Calculation
        @{n = 'DelegatedSignInDate'; e = { if ($_.DelegatedLastSignIn) { Get-Date ($_.DelegatedLastSignIn) -Format 'yyyy-MM-dd HH:mm' } else { 'No activity' } } },
        @{n = 'DelegatedSignInDaysAgo'; e = { if ($_.DelegatedLastSignIn) { (New-TimeSpan -Start ($_.DelegatedLastSignIn) -End $Today).Days } else { $null } } },
        @{n = 'ApplicationSignInDate'; e = { if ($_.ApplicationLastSignIn) { Get-Date ($_.ApplicationLastSignIn) -Format 'yyyy-MM-dd HH:mm' } else { 'No activity' } } },
        @{n = 'ApplicationSignInDaysAgo'; e = { if ($_.ApplicationLastSignIn) { (New-TimeSpan -Start ($_.ApplicationLastSignIn) -End $Today).Days } else { $null } } },
        @{n = 'CreatedDateDisplay'; e = { if ($_.CreatedDate) { Get-Date ($_.CreatedDate) -Format 'yyyy-MM-dd' } else { '' } } },
        @{n = 'CreatedDateDaysAgo'; e = { if ($_.CreatedDate) { (New-TimeSpan -Start ($_.CreatedDate) -End $Today).Days } else { $null } } }
    }

    # Define properties to exclude from the main table - Now includes originals of formatted/calculated fields
    $ExcludedAppProperties = @(
        'Keys', 'DelegatedPermissions', 'ApplicationPermissions', 'Owners',
        'KeysTypes', 'DelegatedLastSignIn', 'ApplicationLastSignIn', 'CreatedDate',
        'DescriptionWithEmail', 'KeysDescription', 'KeysDateOldest', 'KeysDateNewest'
    )


    New-HTML -TitleText "Entra Application Report" {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin # Keep ArrayJoin for potential nested data if not formatted above

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


        New-HTMLSection -HeaderText "Application Overview" {
            # --- Statistics Section ---
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text "Total Applications" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $TotalApps -FontSize 24pt -Color '#0078d4'
                }
                New-HTMLPanel {
                    New-HTMLText -Text "First-Party Apps" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $FirstPartyAppsCount -FontSize 24pt -Color '#0078d4'
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Microsoft Apps" -FontSize 14pt -Color '#666666' # Added Microsoft distinction
                    New-HTMLText -Text ($Applications | Where-Object { $_.Source -eq 'Microsoft' }).Count -FontSize 24pt -Color '#0078d4'
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Third-Party Apps" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $ThirdPartyAppsCount -FontSize 24pt -Color '#0078d4'
                    if ($TotalApps -gt 0) { New-HTMLText -Text "$([math]::Round(($ThirdPartyAppsCount / $TotalApps) * 100, 0))%" -Color '#666666' }
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Apps w/ Delegated Permissions" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $DelegatedAppsCount -FontSize 24pt -Color '#0078d4'
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Apps w/ Application Permissions" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $ApplicationAppsCount -FontSize 24pt -Color '#0078d4'
                }
                New-HTMLPanel {
                    New-HTMLText -Text "Apps with No Sign-In Activity" -FontSize 14pt -Color '#666666'
                    New-HTMLText -Text $InactiveAppsCount -FontSize 24pt -Color '#d13438' # Highlight inactive
                    if ($TotalApps -gt 0) { New-HTMLText -Text "$([math]::Round(($InactiveAppsCount / $TotalApps) * 100, 0))%" -Color '#666666' }
                }
            }
            # --- Charts Section ---
            if ($Applications) {
                New-HTMLSection -HeaderText "Overview Charts" -Collapsable {
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Source' {
                            ($Applications | Group-Object Source) | ForEach-Object {
                                New-ChartPie -Name $_.Name -Value $_.Count
                            }
                        }
                    }
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Permission Type' {
                            ($Applications | Group-Object PermissionType) | ForEach-Object {
                                New-ChartPie -Name $_.Name -Value $_.Count
                            }
                        }
                    }
                    New-HTMLPanel {
                        New-HTMLChart -Title 'Applications by Credential Expiry' {
                            $ExpiryCounts = $Applications | Group-Object KeysExpired | Select-Object Name, Count
                            # Ensure all categories are present, even if count is 0
                            $Categories = @{ 'No' = 0; 'Yes' = 0; 'All Yes' = 0; 'Not available' = 0 }
                            $ExpiryCounts | ForEach-Object { $Categories[$_.Name] = $_.Count }

                            New-ChartPie -Name 'Not Expired' -Value $Categories['No']
                            New-ChartPie -Name 'Some Expired' -Value $Categories['Yes']
                            New-ChartPie -Name 'All Expired' -Value $Categories['All Yes']
                            New-ChartPie -Name 'No Credentials' -Value $Categories['Not available']
                        }
                    }
                } -Invisible
            }
        } -Wrap wrap



        # --- Main Application Table ---
        New-HTMLSection -HeaderText "Applications Details ($TotalApps)" {
            if ($FormattedApplications) {
                # Table now implicitly includes the new/renamed columns from $FormattedApplications
                # Ensure the -ExcludeProperty list is correct
                New-HTMLTable -DataTable $FormattedApplications -ExcludeProperty $ExcludedAppProperties -Filtering {
                    # Conditional Formatting Examples (Adjust column names if needed)
                    New-TableCondition -Name 'Source' -Value 'Third Party' -BackgroundColor LightCoral -ComparisonType string
                    New-TableCondition -Name 'PermissionType' -Value 'Application' -BackgroundColor LightSalmon -ComparisonType string
                    New-TableCondition -Name 'PermissionType' -Value 'Delegated & Application' -BackgroundColor LightSalmon -ComparisonType string
                    New-TableCondition -Name 'KeysExpired' -Value 'Yes' -BackgroundColor OrangeRed -ComparisonType string -Operator contains
                    New-TableCondition -Name 'KeysExpired' -Value 'All Yes' -BackgroundColor Red -ComparisonType string -Operator contains
                    New-TableCondition -Name 'DelegatedSignInDate' -Value 'No activity' -BackgroundColor LightGray -ComparisonType string
                    New-TableCondition -Name 'ApplicationSignInDate' -Value 'No activity' -BackgroundColor LightGray -ComparisonType string
                    # Formatting for DaysAgo columns (Example: highlight recent activity)
                    New-TableCondition -Name 'DelegatedSignInDaysAgo' -Value 7 -Operator 'le' -BackgroundColor LightGreen -ComparisonType number # Active within 7 days
                    New-TableCondition -Name 'ApplicationSignInDaysAgo' -Value 7 -Operator 'le' -BackgroundColor LightGreen -ComparisonType number # Active within 7 days
                    New-TableCondition -Name 'CreatedDateDaysAgo' -Value 30 -Operator 'le' -BackgroundColor LightBlue -ComparisonType number # Created within 30 days

                    # Link to Credentials Table
                    New-TableEvent -SourceColumnName 'ApplicationName' -TargetColumnID 0 -TableID 'TableAppsCredentials'
                } -DataStore JavaScript -DataTableID "TableApps" -PagingLength 10 -ScrollX -WarningAction SilentlyContinue
            } else {
                New-HTMLText -Text "No application data to display." -Color Orange
            }
        }

        # --- Detailed Credentials Table (No changes needed here based on request) ---
        New-HTMLSection -HeaderText "Application Credentials Details" {
            # ... (Existing logic for credentials table) ...
            if ($ApplicationsPassword) {
                # Define properties to show in this table explicitly
                $CredentialColumns = @(
                    'ApplicationName',
                    'Type',
                    'KeyDisplayName',
                    'KeyId',
                    'Hint',
                    'Expired',
                    'DaysToExpire',
                    'StartDateTime',
                    'EndDateTime'
                )
                New-HTMLTable -DataTable ($ApplicationsPassword | Select-Object $CredentialColumns) -Filtering {
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'ge' -BackgroundColor Conifer -ComparisonType number
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 30 -Operator 'lt' -BackgroundColor Orange -ComparisonType number
                    New-HTMLTableCondition -Name 'DaysToExpire' -Value 5 -Operator 'lt' -BackgroundColor Red -ComparisonType number
                    New-HTMLTableCondition -Name 'Expired' -Value $true -ComparisonType bool -BackgroundColor Salmon -FailBackgroundColor Conifer # Bool comparison now
                } -DataStore JavaScript -DataTableID "TableAppsCredentials" -ScrollX -PagingLength 10 -WarningAction SilentlyContinue
            } else {
                New-HTMLText -Text "No detailed credential data to display." -Color Orange
            }
        }

    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}