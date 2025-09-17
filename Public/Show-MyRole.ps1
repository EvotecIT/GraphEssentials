function Show-MyRole {
    <#
    .SYNOPSIS
    Generates a comprehensive HTML report for Azure AD roles, users, and PIM history.

    .DESCRIPTION
    This function creates a detailed HTML report that combines role assignments, user role memberships,
    and PIM history into a single interactive dashboard. The report includes summary statistics,
    detailed tables, and visual representations of your role management landscape.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .PARAMETER DaysBack
    Number of days to look back for PIM history. Defaults to 30 days.

    .PARAMETER IncludeDisabledUsers
    If specified, includes disabled users in the user analysis.

    .EXAMPLE
    Show-MyRole -FilePath "C:\Reports\RoleManagement.html"
    Generates a role management report and saves it to the specified path.

    .EXAMPLE
    Show-MyRole -FilePath "C:\Reports\RoleManagement.html" -Online -DaysBack 90
    Generates a comprehensive role report with 90 days of PIM history and opens it in the browser.

    .NOTES
    This function requires the Microsoft.Graph.Identity.Governance module and appropriate permissions.
    Typically requires RoleManagement.Read.Directory or Directory.Read.All permissions.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [int] $DaysBack = 30,
        [switch] $IncludeDisabledUsers
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    Write-Verbose -Message "Show-MyRole - Getting role definitions and assignments"
    $RoleData = Get-MyRole

    if (-not $RoleData) {
        Write-Warning -Message "Show-MyRole - Failed to retrieve role data"
        return
    }

    Write-Verbose -Message "Show-MyRole - Getting user role assignments"
    $UserRoleData = Get-MyRoleUsers
    $UserRoleDataFiltered = if ($IncludeDisabledUsers) {
        $UserRoleData
    } else {
        $UserRoleData.Where({ $_.Enabled -ne $false })
    }

    Write-Verbose -Message "Show-MyRole - Getting user role assignments with RolePerColumn"
    $UserRoleDataPerColumn = Get-MyRoleUsers -RolePerColumn
    $UserRoleDataPerColumnFiltered = if ($IncludeDisabledUsers) {
        $UserRoleDataPerColumn
    } else {
        $UserRoleDataPerColumn.Where({ $_.Enabled -ne $false })
    }
    $RoleHolderTotal = $UserRoleDataFiltered.Where({ $_.Type -eq 'User' }).Count
    $RoleHolderLicenseSummary = @()
    $RoleHolderServicePlanSummary = @()
    if ($RoleHolderTotal -gt 0) {
        $licenseCounts = [System.Collections.Generic.Dictionary[string, int]]::new()
        $servicePlanCounts = [System.Collections.Generic.Dictionary[string, int]]::new()
        foreach ($entry in $UserRoleDataFiltered) {
            if ($entry.Type -ne 'User') {
                continue
            }
            if ($entry.Licenses) {
                foreach ($license in $entry.Licenses) {
                    if ($null -eq $license) {
                        continue
                    }
                    if ($licenseCounts.ContainsKey($license)) {
                        $licenseCounts[$license]++
                    } else {
                        $licenseCounts[$license] = 1
                    }
                }
            }
            if ($entry.LicenseServices) {
                foreach ($service in $entry.LicenseServices) {
                    if ($null -eq $service) {
                        continue
                    }
                    if ($servicePlanCounts.ContainsKey($service)) {
                        $servicePlanCounts[$service]++
                    } else {
                        $servicePlanCounts[$service] = 1
                    }
                }
            }
        }
        $RoleHolderLicenseSummary = @(
            foreach ($licenseName in $licenseCounts.Keys) {
                $count = $licenseCounts[$licenseName]
                [PSCustomObject]@{
                    License         = $licenseName
                    RoleHolderCount = $count
                    Percentage      = [math]::Round(($count / $RoleHolderTotal) * 100, 1)
                }
            }
        ) | Sort-Object -Property @{ Expression = 'RoleHolderCount'; Descending = $true }, @{ Expression = 'License'; Descending = $false }
        $RoleHolderServicePlanSummary = @(
            foreach ($serviceName in $servicePlanCounts.Keys) {
                $count = $servicePlanCounts[$serviceName]
                [PSCustomObject]@{
                    ServicePlan     = $serviceName
                    RoleHolderCount = $count
                    Percentage      = [math]::Round(($count / $RoleHolderTotal) * 100, 1)
                }
            }
        ) | Sort-Object -Property @{ Expression = 'RoleHolderCount'; Descending = $true }, @{ Expression = 'ServicePlan'; Descending = $false }
    }


    Write-Verbose -Message "Show-MyRole - Getting PIM role history"
    try {
        $RoleHistory = Get-MyRoleHistory -DaysBack $DaysBack -IncludeAllStatuses -Verbose
        Write-Verbose -Message "Show-MyRole - Retrieved $($RoleHistory.Count) PIM history entries"
    } catch {
        Write-Warning -Message "Show-MyRole - Failed to get PIM history: $($_.Exception.Message)"
        $RoleHistory = @()
    }

    if (-not $RoleHistory -or $RoleHistory.Count -eq 0) {
        Write-Warning -Message "Show-MyRole - No PIM history found for the specified period ($DaysBack days)"
        $RoleHistory = @()
    }

    # Calculate statistics
    Write-Verbose -Message "Show-MyRole - Calculating statistics"
    $RecentCutoff = (Get-Date).AddDays(-7)
    $Stats = @{
        TotalRoles             = $RoleData.Count
        RolesWithMembers       = $RoleData.Where({ $_.TotalMembers -gt 0 }).Count
        TotalUsers             = $UserRoleDataFiltered.Where({ $_.Type -eq 'User' }).Count
        UsersWithRoles         = $UserRoleDataFiltered.Where({ $_.Type -eq 'User' -and (($_.DirectCount -and $_.DirectCount -gt 0) -or ($_.EligibleCount -and $_.EligibleCount -gt 0)) }).Count
        TotalServicePrincipals = $UserRoleDataFiltered.Where({ $_.Type -like '*ServicePrincipal*' }).Count
        SPsWithRoles           = $UserRoleDataFiltered.Where({ $_.Type -like '*ServicePrincipal*' -and (($_.DirectCount -and $_.DirectCount -gt 0) -or ($_.EligibleCount -and $_.EligibleCount -gt 0)) }).Count
        TotalGroups            = $UserRoleDataFiltered.Where({ $_.Type -like '*Group*' }).Count
        GroupsWithRoles        = $UserRoleDataFiltered.Where({ $_.Type -like '*Group*' -and (($_.DirectCount -and $_.DirectCount -gt 0) -or ($_.EligibleCount -and $_.EligibleCount -gt 0)) }).Count
        PIMActivations         = $RoleHistory.Where({ $_.Action -like '*Activated*' }).Count
        PIMDeactivations       = $RoleHistory.Where({ $_.Action -like '*Deactivated*' }).Count
        AdminActions           = $RoleHistory.Where({ $_.Action -like 'Admin*' }).Count
        RecentActivity         = $RoleHistory.Where({ $_.CreatedDateTime -gt $RecentCutoff }).Count
    }

    # Get most active roles from history
    $MostActiveRoles = $RoleHistory | Group-Object RoleName | Sort-Object Count -Descending | Select-Object -First 5

    # Properties to exclude from HTML tables for cleaner display
    $ExcludedProperties = @(
        'RoleId',
        'PrincipalId'
    )

    Write-Verbose -Message "Show-MyRole - Preparing HTML report"
    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor '#0078d4' -RemoveShadow
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

        New-HTMLTab -Name "Overview" {
            # Summary Cards Section
            #New-HTMLSection -HeaderText "Role Management Overview" {
            New-HTMLSection -Density Dense -Invisible {
                # Role Statistics
                New-HTMLInfoCard -Title "Total Roles" -Number $Stats.TotalRoles -Subtitle "$($Stats.RolesWithMembers) roles have assigned members" -Icon "🎭" -IconColor "#0078d4" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                # User Statistics
                New-HTMLInfoCard -Title "Users with Roles" -Number "$($Stats.UsersWithRoles)" -Subtitle "Out of $($Stats.TotalUsers) total users" -Icon "👥" -IconColor "#198754" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                # Service Principal Statistics
                New-HTMLInfoCard -Title "Service Principals" -Number "$($Stats.SPsWithRoles)" -Subtitle "Out of $($Stats.TotalServicePrincipals) total service principals" -Icon "🔧" -IconColor "#6f42c1" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                # Group Statistics
                New-HTMLInfoCard -Title "Groups with Roles" -Number "$($Stats.GroupsWithRoles)" -Subtitle "Out of $($Stats.TotalGroups) role-assignable groups" -Icon "🏢" -IconColor "#fd7e14" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
            }
            #}

            # PIM Activity Section
            #New-HTMLSection -HeaderText "PIM Activity (Last $DaysBack Days)" {
            New-HTMLSection -Density Dense -Invisible {
                # PIM Activations
                New-HTMLInfoCard -Title "Role Activations" -Number $Stats.PIMActivations -Subtitle "Self-service role activations" -Icon "🔓" -IconColor "#198754" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px -ShadowColor 'rgba(25, 135, 84, 0.3)'

                # PIM Deactivations
                New-HTMLInfoCard -Title "Role Deactivations" -Number $Stats.PIMDeactivations -Subtitle "Role session endings" -Icon "🔒" -IconColor "#6c757d" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                # Admin Actions
                New-HTMLInfoCard -Title "Admin Actions" -Number $Stats.AdminActions -Subtitle "Administrative role changes" -Icon "⚙️" -IconColor "#0078d4" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                # Recent Activity
                New-HTMLInfoCard -Title "Recent Activity" -Number $Stats.RecentActivity -Subtitle "Actions in last 7 days" -Icon "📊" -IconColor "#ffc107" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px -ShadowColor 'rgba(255, 193, 7, 0.3)'
            }
            #}

            # Most Active Roles Section
            if ($MostActiveRoles) {
                New-HTMLSection -HeaderText "Most Active Roles (PIM History)" -Invisible -Density Comfortable {
                    New-HTMLPanel {
                        New-HTMLContainer {
                            $MostActiveRoleData = $MostActiveRoles | ForEach-Object {
                                [PSCustomObject]@{
                                    RoleName      = $_.Name
                                    ActivityCount = $_.Count
                                    Percentage    = [math]::Round(($_.Count / $RoleHistory.Count) * 100, 1)
                                }
                            }

                            New-HTMLChart {
                                $ChartColors = @('#0078d4', '#198754', '#6f42c1', '#fd7e14', '#ffc107', '#20c997', '#dc3545', '#6c757d')
                                $LegendColors = $ChartColors[0..([Math]::Min($MostActiveRoleData.Count - 1, $ChartColors.Count - 1))]
                                New-ChartLegend -Names $MostActiveRoleData.RoleName -Color $LegendColors
                                foreach ($Role in $MostActiveRoleData) {
                                    New-ChartPie -Name $Role.RoleName -Value $Role.ActivityCount
                                }
                            } -Title 'Most Active Roles Distribution' -TitleAlignment left
                        }
                    }

                    # Role Assignment Distribution Chart
                    New-HTMLPanel {
                        New-HTMLContainer {
                            # Create assignment type distribution chart
                            $AssignmentData = @(
                                [PSCustomObject]@{ Type = 'Direct Assignments'; Count = ($RoleData | Measure-Object -Property DirectMembers -Sum).Sum }
                                [PSCustomObject]@{ Type = 'Eligible Assignments'; Count = ($RoleData | Measure-Object -Property EligibleMembers -Sum).Sum }
                                [PSCustomObject]@{ Type = 'Group Assignments'; Count = ($RoleData | Measure-Object -Property GroupsMembers -Sum).Sum }
                            ).Where({ $_.Count -gt 0 })

                            if ($AssignmentData.Count -gt 0) {
                                New-HTMLChart {
                                    $ChartColors = @('#0078d4', '#ffc107', '#6f42c1')
                                    New-ChartLegend -Names ($AssignmentData.Type) -Color $ChartColors[0..($AssignmentData.Count - 1)]
                                    foreach ($Assignment in $AssignmentData) {
                                        New-ChartPie -Name $Assignment.Type -Value $Assignment.Count
                                    }
                                } -Title 'Role Assignment Distribution' -TitleAlignment left
                            }
                        }
                    }
                }
            }

            # Quick Stats Tables
            New-HTMLSection -HeaderText "Role Assignment Summary" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Summary of role assignments across your environment. Direct assignments are permanent, "
                            "while eligible assignments require activation through PIM."
                        }
                    }

                    New-HTMLContainer {
                        $TopRoles = $RoleData | Sort-Object TotalMembers -Descending | Select-Object -First 10
                        New-HTMLTable -DataTable $TopRoles -Filtering {
                            New-HTMLTableCondition -Name 'TotalMembers' -Value 0 -Operator gt -BackgroundColor LightGreen -ComparisonType number
                            New-HTMLTableCondition -Name 'DirectMembers' -Value 5 -Operator gt -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'EligibleMembers' -Value 5 -Operator gt -BackgroundColor LightYellow -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableTopRoles" -ScrollX #-WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "All Roles ($($RoleData.Count))" {
            # Security Insights Section (merged into this tab)
            New-HTMLSection -HeaderText "Security Insights & Analysis" {
                # High-privilege role analysis
                $HighPrivilegeRoles = @(
                    'Global Administrator',
                    'Privileged Role Administrator',
                    'Security Administrator',
                    'Global Reader',
                    'Directory Writers',
                    'Application Administrator',
                    'Cloud Application Administrator'
                )

                $HighPrivRoleData = $RoleData.Where({ $_.Name -in $HighPrivilegeRoles -and $_.TotalMembers -gt 0 }) | Sort-Object TotalMembers -Descending
                $UsersWithMultipleRoles = $UserRoleDataFiltered.Where({
                        $_.Type -eq 'User' -and
                        (($_.DirectCount -and $_.DirectCount -gt 0) -or ($_.EligibleCount -and $_.EligibleCount -gt 0)) -and
                        (($_.DirectCount + $_.EligibleCount) -gt 3)
                    }) | Sort-Object { $_.DirectCount + $_.EligibleCount } -Descending
                $AdminSPs = $UserRoleDataFiltered.Where({
                        $_.Type -like '*ServicePrincipal*' -and
                        (($_.DirectCount -and $_.DirectCount -gt 0) -or ($_.EligibleCount -and $_.EligibleCount -gt 0))
                    })

                New-HTMLSection -Density Dense -Invisible {
                    # Security InfoCards
                    New-HTMLInfoCard -Title "High-Privilege Roles" -Number $HighPrivRoleData.Count -Subtitle "Roles with significant privileges" -Icon "🚨" -IconColor "#dc3545" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                    New-HTMLInfoCard -Title "Multi-Role Users" -Number $UsersWithMultipleRoles.Count -Subtitle "Users with 4+ role assignments" -Icon "👤" -IconColor "#fd7e14" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                    New-HTMLInfoCard -Title "Admin Service Principals" -Number $AdminSPs.Count -Subtitle "Service principals with admin roles" -Icon "🔧" -IconColor "#6f42c1" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px

                    New-HTMLInfoCard -Title "Custom Roles" -Number ($RoleData.Where({ -not $_.IsBuiltin }).Count) -Subtitle "Custom-created role definitions" -Icon "⚙️" -IconColor "#0078d4" -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                }

                if ($HighPrivRoleData.Count -gt 0) {
                    New-HTMLPanel {
                        New-HTMLContainer {
                            New-HTMLText -Text "High-Privilege Role Distribution" -FontSize 14pt -FontWeight bold
                            New-HTMLChart {
                                $ChartColors = @('#0078d4', '#198754', '#6f42c1', '#fd7e14', '#ffc107', '#20c997', '#dc3545', '#6c757d')
                                $LegendColors = $ChartColors[0..([Math]::Min($MostActiveRoleData.Count - 1, $ChartColors.Count - 1))]
                                New-ChartLegend -Names $MostActiveRoleData.RoleName -Color $LegendColors
                                foreach ($Role in $HighPrivRoleData) {
                                    New-ChartPie -Name $Role.Name -Value $Role.TotalMembers
                                }
                            } -Title 'High-Privilege Role Assignments' -TitleAlignment left
                        }
                    }
                }
            }

            New-HTMLSection -HeaderText "Azure AD Role Definitions" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Complete list of Azure AD role definitions in your tenant. Built-in roles are predefined by Microsoft, "
                            "while custom roles can be created to meet specific organizational requirements. The member counts show "
                            "both direct assignments and eligible assignments that can be activated through PIM."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $RoleData -Filtering {
                            New-HTMLTableCondition -Name 'IsBuiltin' -Value $true -BackgroundColor LightBlue -ComparisonType bool
                            New-HTMLTableCondition -Name 'TotalMembers' -Value 0 -Operator gt -BackgroundColor LightGreen -ComparisonType number
                            New-HTMLTableCondition -Name 'DirectMembers' -Value 10 -Operator gt -BackgroundColor Orange -ComparisonType number
                            New-HTMLTableCondition -Name 'EligibleMembers' -Value 10 -Operator gt -BackgroundColor LightYellow -ComparisonType number
                            # Highlight high-privilege roles
                            New-HTMLTableCondition -Name 'Name' -Value 'Global Administrator' -BackgroundColor '#ffebee' -ComparisonType string
                            New-HTMLTableCondition -Name 'Name' -Value 'Privileged Role Administrator' -BackgroundColor '#ffebee' -ComparisonType string
                            New-HTMLTableCondition -Name 'Name' -Value 'Security Administrator' -BackgroundColor '#fff3e0' -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableAllRoles" -PagingLength 25 -ScrollX #-WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Users & Principals ($($UserRoleDataFiltered.Count))" {
            New-HTMLTabPanel {
                New-HTMLTab -Name "Standard View" {
                    New-HTMLSection -HeaderText "User Role Assignments" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Detailed view of all users, service principals, and groups with role assignments. "
                                    "Direct roles are permanently assigned, while eligible roles require activation through PIM. "
                                    "Disabled users are $(if ($IncludeDisabledUsers) { 'included' } else { 'excluded' }) from this view."
                                }
                            }

                            New-HTMLContainer {
                                if ($RoleHolderTotal -gt 0) {
                                    if ($RoleHolderLicenseSummary.Count -gt 0 -or $RoleHolderServicePlanSummary.Count -gt 0) {
                                        New-HTMLContainer {
                                            New-HTMLText -FontSize 11pt -TextBlock {
                                                "License footprint across $RoleHolderTotal user role holders. Monitor privileged identities for productivity workloads."
                                            }
                                        }
                                    }
                                    if ($RoleHolderLicenseSummary.Count -gt 0) {
                                        New-HTMLContainer {
                                            New-HTMLText -FontSize 10pt -FontWeight bold -Text "Top Licenses Assigned to Role Holders"
                                            New-HTMLTable -DataTable $RoleHolderLicenseSummary -DataStore JavaScript -DataTableID "TableRoleHolderLicenses" -PagingLength 10
                                        }
                                    }
                                    if ($RoleHolderServicePlanSummary.Count -gt 0) {
                                        New-HTMLContainer {
                                            New-HTMLText -FontSize 10pt -FontWeight bold -Text "Service Plans Enabled for Role Holders"
                                            New-HTMLTable -DataTable $RoleHolderServicePlanSummary -DataStore JavaScript -DataTableID "TableRoleHolderServicePlans" -PagingLength 10
                                        }
                                    }
                                }
                                New-HTMLTable -DataTable $UserRoleDataFiltered -Filtering {
                                    New-HTMLTableCondition -Name 'Type' -Value 'User' -BackgroundColor LightGreen -ComparisonType string
                                    New-HTMLTableCondition -Name 'Type' -Value 'ServicePrincipal' -BackgroundColor LightBlue -ComparisonType string
                                    New-HTMLTableCondition -Name 'Type' -Value 'SecurityGroup' -BackgroundColor LightYellow -ComparisonType string
                                    New-HTMLTableCondition -Name 'Type' -Value 'DistributionGroup' -BackgroundColor LightCoral -ComparisonType string
                                    New-HTMLTableCondition -Name 'Enabled' -Value $false -BackgroundColor LightGray -ComparisonType bool
                                    New-HTMLTableCondition -Name 'DirectCount' -Value 0 -Operator gt -BackgroundColor LightGreen -ComparisonType number
                                    New-HTMLTableCondition -Name 'EligibleCount' -Value 0 -Operator gt -BackgroundColor LightYellow -ComparisonType number
                                } -DataStore JavaScript -DataTableID "TableUserRoles" -PagingLength 25 -ScrollX -ExcludeProperty $ExcludedProperties #-WarningAction SilentlyContinue
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Matrix View (Roles as Columns)" {
                    New-HTMLSection -HeaderText "User-Role Assignment Matrix" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Matrix view showing users and their role assignments with each role as a separate column. "
                                    "This format makes it easy to see role distribution across users and identify role overlap patterns. "
                                    "Values show assignment type: 'Direct', 'Eligible', or group names for group-based assignments."
                                }
                            }

                            New-HTMLContainer {
                                New-HTMLTable -DataTable $UserRoleDataPerColumnFiltered -Filtering {
                                    New-HTMLTableCondition -Name 'Enabled' -Value $true -BackgroundColor SpringGreen -ComparisonType bool
                                    New-HTMLTableCondition -Name 'Enabled' -Value $false -BackgroundColor Salmon -ComparisonType bool
                                    # Dynamic conditions for role columns
                                    if ($UserRoleDataPerColumnFiltered -and $UserRoleDataPerColumnFiltered.Count -gt 0) {
                                        $SampleUser = $UserRoleDataPerColumnFiltered[0]
                                        foreach ($PropertyName in $SampleUser.PSObject.Properties.Name) {
                                            if ($PropertyName -notin @('Name', 'Enabled', 'UserPrincipalName', 'Mail', 'Status', 'Type', 'Location', 'CreatedDateTime')) {
                                                New-HTMLTableCondition -Name $PropertyName -Value 'Direct' -BackgroundColor GoldenFizz -ComparisonType string
                                                New-HTMLTableCondition -Name $PropertyName -Value 'Eligible' -BackgroundColor SpringGreen -ComparisonType string
                                            }
                                        }
                                    }
                                } -DataStore JavaScript -DataTableID "TableUserRolesMatrix" -PagingLength 25 -ScrollX -AllProperties #-WarningAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }

        New-HTMLTab -Name "PIM History ($($RoleHistory.Count))" {
            if ($RoleHistory.Count -gt 0) {
                New-HTMLSection -Invisible -Wrap wrap {
                    # Activity by Action Type
                    $ActionStats = $RoleHistory | Group-Object Action | Sort-Object Count -Descending | ForEach-Object {
                        [PSCustomObject]@{
                            Action     = $_.Name
                            Count      = $_.Count
                            Percentage = [math]::Round(($_.Count / $RoleHistory.Count) * 100, 1)
                        }
                    }
                    New-HTMLSection -Density Dense -Invisible {
                        $TopActions = $ActionStats | Select-Object -First 4
                        $ActionIcons = @{
                            'User Activated Role'          = '🔓'
                            'User Deactivated Role'        = '🔒'
                            'Admin Assigned Active Role'   = '👤'
                            'Admin Assigned Eligible Role' = '⭐'
                            'Admin Removed Active Role'    = '❌'
                            'Admin Removed Eligible Role'  = '🚫'
                            'Admin Updated Assignment'     = '✏️'
                            'User Extended Role'           = '⏰'
                            'Admin Extended Role'          = '🔄'
                            'Role Provisioned'             = '✅'
                        }
                        $ActionColors = @('#198754', '#6c757d', '#0078d4', '#ffc107', '#dc3545', '#fd7e14')

                        for ($i = 0; $i -lt $TopActions.Count; $i++) {
                            $Action = $TopActions[$i]
                            $Icon = if ($ActionIcons[$Action.Action]) { $ActionIcons[$Action.Action] } else { '📊' }
                            $Color = $ActionColors[$i % $ActionColors.Count]
                            New-HTMLInfoCard -Title $Action.Action -Number $Action.Count -Subtitle "$($Action.Percentage)% of all activity" -Icon $Icon -IconColor $Color -Style "Standard" -ShadowIntensity 'Normal' -BorderRadius 2px
                        }
                    }

                    New-HTMLSection -Density Dense -Invisible {
                        New-HTMLPanel {
                            #New-HTMLText -Text "PIM Activity Distribution by Action Type" -FontSize 14pt -FontWeight bold
                            New-HTMLChart {
                                $ChartColors = @('#198754', '#0078d4', '#6c757d', '#ffc107', '#dc3545', '#fd7e14', '#6f42c1', '#20c997')
                                New-ChartLegend -Names ($ActionStats.Action) -Color $ChartColors[0..($ActionStats.Count - 1)]
                                foreach ($Action in $ActionStats) {
                                    New-ChartPie -Name $Action.Action -Value $Action.Count
                                }
                            } -Title 'PIM Activity Distribution by Action Type' -TitleAlignment left
                        }


                        New-HTMLPanel {
                            # Activity by User
                            $UserStats = $RoleHistory | Group-Object PrincipalName | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
                                [PSCustomObject]@{
                                    PrincipalName = $_.Name
                                    ActivityCount = $_.Count
                                    Percentage    = [math]::Round(($_.Count / $RoleHistory.Count) * 100, 1)
                                }
                            }

                            #New-HTMLText -Text "Most Active Users (Top 10)" -FontSize 14pt -FontWeight bold
                            New-HTMLChart {
                                New-ChartBarOptions -Type bar
                                New-ChartLegend -Names $UserStats.PrincipalName
                                New-ChartBar -Name "Activity Count" -Value $UserStats.ActivityCount
                            } -Title 'Most Active Users (Top 10)' -TitleAlignment left
                        }
                    }
                }

                New-HTMLSection -HeaderText "Privileged Identity Management Activity (Last $DaysBack Days)" {
                    New-HTMLPanel -Invisible {
                        New-HTMLContainer {
                            New-HTMLText -FontSize 11pt -TextBlock {
                                "Complete audit trail of PIM activities including role activations, deactivations, assignments, and removals. "
                                "This log helps track privileged access usage and administrative actions for compliance and security monitoring."
                            }
                        }

                        New-HTMLContainer {
                            New-HTMLTable -DataTable $RoleHistory -Filtering {
                                New-HTMLTableCondition -Name 'Action' -Value 'Activated' -BackgroundColor LightGreen -ComparisonType string -Operator like
                                New-HTMLTableCondition -Name 'Action' -Value 'Deactivated' -BackgroundColor LightGray -ComparisonType string -Operator like
                                New-HTMLTableCondition -Name 'Action' -Value 'Admin' -BackgroundColor LightBlue -ComparisonType string -Operator like
                                New-HTMLTableCondition -Name 'Status' -Value 'Completed Successfully' -BackgroundColor LightGreen -ComparisonType string
                                New-HTMLTableCondition -Name 'Status' -Value 'Revoked/Removed' -BackgroundColor LightCoral -ComparisonType string
                                New-HTMLTableCondition -Name 'RequestType' -Value 'Assignment' -BackgroundColor LightBlue -ComparisonType string
                                New-HTMLTableCondition -Name 'RequestType' -Value 'Eligibility' -BackgroundColor LightYellow -ComparisonType string
                            } -DataStore JavaScript -DataTableID "TablePIMHistory" -ScrollX -ExcludeProperty 'RequestID', 'CompletedDateTime', 'RoleID', 'PrincipalID'
                        }
                    }
                }
            } else {
                New-HTMLSection -HeaderText "No PIM History Found" {
                    New-HTMLPanel -Invisible {
                        New-HTMLContainer {
                            New-HTMLText -FontSize 12pt -TextBlock {
                                "No PIM activity was found for the last $DaysBack days. This could mean:"
                            }
                            New-HTMLList {
                                New-HTMLListItem -Text "No role activations or administrative changes occurred"
                                New-HTMLListItem -Text "PIM might not be configured in your tenant"
                                New-HTMLListItem -Text "You may need additional permissions to read PIM history"
                                New-HTMLListItem -Text "Try extending the time period with the -DaysBack parameter"
                            } -FontSize 11pt

                            New-HTMLText -FontSize 11pt -TextBlock {
                                "Required permissions for PIM history: RoleManagement.Read.Directory, RoleAssignmentSchedule.Read.Directory"
                            }
                        }
                    }
                }
            }
        }



    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent -TitleText "Azure AD Role Management Report"
}
