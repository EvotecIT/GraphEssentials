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
    $UserRoleDataFiltered = if ($IncludeDisabledUsers) { $UserRoleData } else { $UserRoleData | Where-Object { $_.Enabled -ne $false } }

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
    $Stats = @{
        TotalRoles             = $RoleData.Count
        RolesWithMembers       = ($RoleData | Where-Object { $_.TotalMembers -gt 0 }).Count
        TotalUsers             = ($UserRoleDataFiltered | Where-Object { $_.Type -eq 'User' }).Count
        UsersWithRoles         = ($UserRoleDataFiltered | Where-Object { $_.Type -eq 'User' -and ($_.DirectCount -gt 0 -or $_.EligibleCount -gt 0) }).Count
        TotalServicePrincipals = ($UserRoleDataFiltered | Where-Object { $_.Type -like '*ServicePrincipal*' }).Count
        SPsWithRoles           = ($UserRoleDataFiltered | Where-Object { $_.Type -like '*ServicePrincipal*' -and ($_.DirectCount -gt 0 -or $_.EligibleCount -gt 0) }).Count
        TotalGroups            = ($UserRoleDataFiltered | Where-Object { $_.Type -like '*Group*' }).Count
        GroupsWithRoles        = ($UserRoleDataFiltered | Where-Object { $_.Type -like '*Group*' -and ($_.DirectCount -gt 0 -or $_.EligibleCount -gt 0) }).Count
        PIMActivations         = ($RoleHistory | Where-Object { $_.Action -like '*Activated*' }).Count
        PIMDeactivations       = ($RoleHistory | Where-Object { $_.Action -like '*Deactivated*' }).Count
        AdminActions           = ($RoleHistory | Where-Object { $_.Action -like 'Admin*' }).Count
        RecentActivity         = ($RoleHistory | Where-Object { $_.CreatedDateTime -gt (Get-Date).AddDays(-7) }).Count
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

        New-HTMLTab -Name "Dashboard & Overview" {
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
                #New-HTMLSection -HeaderText "Most Active Roles (PIM History)" {
                New-HTMLPanel {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "These roles have the most PIM activity in the selected time period. High activity might indicate "
                            "either normal operational usage or potential security concerns that warrant investigation."
                        }
                    }

                    New-HTMLContainer {
                        $MostActiveRoleData = $MostActiveRoles | ForEach-Object {
                            [PSCustomObject]@{
                                RoleName      = $_.Name
                                ActivityCount = $_.Count
                                Percentage    = [math]::Round(($_.Count / $RoleHistory.Count) * 100, 1)
                            }
                        }

                        New-HTMLChart {
                            $ChartColors = @('#0078d4', '#198754', '#6f42c1', '#fd7e14', '#ffc107')
                            New-ChartLegend -Names ($MostActiveRoleData.RoleName) -Color $ChartColors[0..($MostActiveRoleData.Count - 1)]
                            foreach ($Role in $MostActiveRoleData) {
                                New-ChartPie -Name $Role.RoleName -Value $Role.ActivityCount
                            }
                        } -Title 'Most Active Roles Distribution' -TitleAlignment center
                    }
                }
                #  }
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
                        } -DataStore JavaScript -DataTableID "TableAllRoles" -PagingLength 25 -ScrollX #-WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Users & Principals ($($UserRoleDataFiltered.Count))" {
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
                            $Icon = $ActionIcons[$Action.Action] ?? '📊'
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

        New-HTMLTab -Name "Security Insights" {
            New-HTMLSection -HeaderText "Role Management Security Analysis" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Security-focused analysis of your role assignments and PIM usage. "
                            "These insights help identify potential security risks and areas for improvement."
                        }
                    }

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

                    $HighPrivRoleData = $RoleData | Where-Object { $_.Name -in $HighPrivilegeRoles -and $_.TotalMembers -gt 0 } | Sort-Object TotalMembers -Descending

                    if ($HighPrivRoleData) {
                        New-HTMLContainer {
                            New-HTMLText -Text "High-Privilege Role Assignments" -FontSize 14pt -FontWeight bold
                            New-HTMLText -FontSize 11pt -TextBlock {
                                "These roles have significant privileges and should be closely monitored. "
                                "Consider using eligible assignments instead of direct assignments for better security."
                            }
                            New-HTMLTable -DataTable $HighPrivRoleData -Filtering {
                                New-HTMLTableCondition -Name 'DirectMembers' -Value 0 -Operator gt -BackgroundColor LightCoral -ComparisonType number
                                New-HTMLTableCondition -Name 'EligibleMembers' -Value 0 -Operator gt -BackgroundColor LightGreen -ComparisonType number
                            } -DataStore JavaScript -DataTableID "TableHighPrivRoles" -ScrollX -WarningAction SilentlyContinue
                        }
                    }

                    # Users with multiple high-privilege roles
                    $UsersWithMultipleRoles = $UserRoleDataFiltered | Where-Object {
                        $_.Type -eq 'User' -and
                        ($_.DirectCount + $_.EligibleCount) -gt 3
                    } | Sort-Object { $_.DirectCount + $_.EligibleCount } -Descending

                    if ($UsersWithMultipleRoles) {
                        New-HTMLContainer {
                            New-HTMLText -Text "Users with Multiple Roles (4+ roles)" -FontSize 14pt -FontWeight bold
                            New-HTMLText -FontSize 11pt -TextBlock {
                                "Users with many role assignments may pose a security risk and should be reviewed regularly."
                            }
                            New-HTMLTable -DataTable $UsersWithMultipleRoles -Filtering -DataStore JavaScript -DataTableID "TableMultipleRoles" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                        }
                    }

                    # Service Principals with admin roles
                    $AdminSPs = $UserRoleDataFiltered | Where-Object {
                        $_.Type -like '*ServicePrincipal*' -and
                        ($_.DirectCount -gt 0 -or $_.EligibleCount -gt 0)
                    }

                    if ($AdminSPs) {
                        New-HTMLContainer {
                            New-HTMLText -Text "Service Principals with Administrative Roles" -FontSize 14pt -FontWeight bold
                            New-HTMLText -FontSize 11pt -TextBlock {
                                "Service principals with administrative roles should be carefully managed and monitored."
                            }
                            New-HTMLTable -DataTable $AdminSPs -Filtering -DataStore JavaScript -DataTableID "TableAdminSPs" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                        }
                    }
                }
            }
        }

    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent -TitleText "Azure AD Role Management Report"
}