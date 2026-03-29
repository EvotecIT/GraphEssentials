$Script:Roles = [ordered] @{
    Name       = 'Azure Active Directory Roles'
    Enabled    = $true
    Execute    = {
        Get-MyRole -OnlyWithMembers
    }
    Processing = {

    }
    Summary    = {
        $roleData = @($Script:Reporting['Roles']['Data'])
        $totalRoles = $roleData.Count
        $enabledRoles = 0
        $disabledRoles = 0
        $builtinRoles = 0
        $customRoles = 0
        $highPrivilegeRoles = 0
        $rolesWithEligible = 0
        $rolesWithGroups = 0
        $rolesWithServicePrincipals = 0
        $rolesWithLargeMembership = 0
        $builtinDistribution = @{}
        $assignmentDistribution = [System.Collections.Generic.List[object]]::new()
        $highPrivilegeRoleList = [System.Collections.Generic.List[object]]::new()
        $eligibleRoleList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($role in $roleData) {
            if ($role.IsEnabled) {
                $enabledRoles++
            } else {
                $disabledRoles++
            }

            if ($role.IsBuiltin) {
                $builtinRoles++
            } else {
                $customRoles++
            }

            $builtinName = if ($role.IsBuiltin) { 'Built-in' } else { 'Custom' }
            if (-not $builtinDistribution.ContainsKey($builtinName)) {
                $builtinDistribution[$builtinName] = 0
            }
            $builtinDistribution[$builtinName]++

            if ($role.IsHighPrivilege) {
                $highPrivilegeRoles++
                $highPrivilegeRoleList.Add($role)
            }
            if ($role.HasEligibleAssignments) {
                $rolesWithEligible++
                $eligibleRoleList.Add($role)
            }
            if ($role.HasGroupAssignments) {
                $rolesWithGroups++
            }
            if ($role.HasServicePrincipals) {
                $rolesWithServicePrincipals++
            }
            if ($role.TotalMembers -gt 10) {
                $rolesWithLargeMembership++
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($role.IsHighPrivilege) {
                $reviewFlags.Add('High privilege')
            }
            if ($role.HasEligibleAssignments) {
                $reviewFlags.Add('Eligible assignments')
            }
            if ($role.HasGroupAssignments) {
                $reviewFlags.Add('Role-assignable groups')
            }
            if ($role.HasServicePrincipals) {
                $reviewFlags.Add('Service principals')
            }
            if ($role.TotalMembers -gt 10) {
                $reviewFlags.Add('More than 10 members')
            }
            if (-not $role.IsEnabled) {
                $reviewFlags.Add('Disabled role')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($role | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalRoles               = $totalRoles
                EnabledRoles             = $enabledRoles
                DisabledRoles            = $disabledRoles
                BuiltinRoles             = $builtinRoles
                CustomRoles              = $customRoles
                HighPrivilegeRoles       = $highPrivilegeRoles
                RolesWithEligible        = $rolesWithEligible
                RolesWithGroups          = $rolesWithGroups
                RolesWithServicePrincipals = $rolesWithServicePrincipals
                RolesWithLargeMembership = $rolesWithLargeMembership
            }
        )

        $roleTypeDistribution = @(
            foreach ($key in $builtinDistribution.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $builtinDistribution[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $assignmentDistribution.Add([PSCustomObject]@{ Name = 'Direct assignments'; Count = @($roleData.Where({ $_.HasDirectAssignments })).Count })
        $assignmentDistribution.Add([PSCustomObject]@{ Name = 'Eligible assignments'; Count = $rolesWithEligible })
        $assignmentDistribution.Add([PSCustomObject]@{ Name = 'Group assignments'; Count = $rolesWithGroups })
        $assignmentDistribution.Add([PSCustomObject]@{ Name = 'Service principals'; Count = $rolesWithServicePrincipals })

        $membershipDistribution = @(
            [PSCustomObject]@{ Name = '1-2 members'; Count = @($roleData.Where({ $_.TotalMembers -ge 1 -and $_.TotalMembers -le 2 })).Count }
            [PSCustomObject]@{ Name = '3-5 members'; Count = @($roleData.Where({ $_.TotalMembers -ge 3 -and $_.TotalMembers -le 5 })).Count }
            [PSCustomObject]@{ Name = '6-10 members'; Count = @($roleData.Where({ $_.TotalMembers -ge 6 -and $_.TotalMembers -le 10 })).Count }
            [PSCustomObject]@{ Name = '10+ members'; Count = @($roleData.Where({ $_.TotalMembers -gt 10 })).Count }
        )

        $topRolesByMembers = @($roleData | Sort-Object TotalMembers -Descending | Select-Object -First 10)

        [PSCustomObject]@{
            Overview               = $overview
            RoleTypeDistribution   = $roleTypeDistribution
            AssignmentDistribution = @($assignmentDistribution)
            MembershipDistribution = $membershipDistribution
            TopRolesByMembers      = $topRolesByMembers
            HighPrivilegeRoles     = @($highPrivilegeRoleList)
            EligibleRoles          = @($eligibleRoleList)
            ReviewCandidates       = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $roleSummary = $Script:Reporting['Roles']['Summary']
        $roleData = @($Script:Reporting['Roles']['Data'])
        $roleCount = $roleData.Count

        if ($roleData) {
            $roleTableConditions = {
                New-HTMLTableCondition -Name 'IsEnabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'IsEnabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon

                New-HTMLTableCondition -Name 'IsHighPrivilege' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'IsHighPrivilege', 'Name'
                New-HTMLTableCondition -Name 'HasEligibleAssignments' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'HasEligibleAssignments', 'EligibleMembers'
                New-HTMLTableCondition -Name 'HasGroupAssignments' -Operator eq -Value $true -ComparisonType string -BackgroundColor LaserLemon -HighlightHeaders 'HasGroupAssignments', 'Groups', 'GroupsMembers'
                New-HTMLTableCondition -Name 'HasServicePrincipals' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'HasServicePrincipals', 'ServicePrincipals'

                New-HTMLTableCondition -Name 'TotalMembers' -Value 10 -Operator gt -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'TotalMembers'
                New-HTMLTableCondition -Name 'DirectMembers' -Value 10 -Operator gt -ComparisonType number -BackgroundColor Orange -HighlightHeaders 'DirectMembers'
                New-HTMLTableCondition -Name 'EligibleMembers' -Value 10 -Operator gt -ComparisonType number -BackgroundColor LightYellow -HighlightHeaders 'EligibleMembers'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($roleCount)" {
                    if ($roleSummary -and $roleSummary.Overview) {
                        $overview = $roleSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Role Management Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Roles' -Number $overview.TotalRoles -Subtitle 'Roles with members in scope' -Icon '🎭' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledRoles) / $($overview.DisabledRoles)" -Subtitle 'Role state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Built-in / Custom' -Number "$($overview.BuiltinRoles) / $($overview.CustomRoles)" -Subtitle 'Role definition source' -Icon '🧩' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'High-Privilege Roles' -Number $overview.HighPrivilegeRoles -Subtitle 'Critical administrative roles' -Icon '🚨' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Eligible Assignments' -Number $overview.RolesWithEligible -Subtitle 'Roles using PIM-style eligibility' -Icon '🔓' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Group-assigned Roles' -Number $overview.RolesWithGroups -Subtitle 'Role-assignable groups present' -Icon '👥' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Service Principals' -Number $overview.RolesWithServicePrincipals -Subtitle 'Non-user principals hold roles' -Icon '🔧' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Large Membership Roles' -Number $overview.RolesWithLargeMembership -Subtitle 'More than 10 members' -Icon '📈' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Roles by Type' {
                                        foreach ($item in $roleSummary.RoleTypeDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Assignment Models' {
                                        foreach ($item in $roleSummary.AssignmentDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Membership Patterns' -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Role Membership Distribution' {
                                        foreach ($item in $roleSummary.MembershipDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                if (@($roleSummary.TopRolesByMembers).Count -gt 0) {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Top Roles By Members' {
                                            foreach ($item in $roleSummary.TopRolesByMembers) {
                                                New-ChartBar -Name $item.Name -Value $item.TotalMembers
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $roleSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }

                New-HTMLTab -Name "Roles ($roleCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Roles ($roleCount)" {
                            New-HTMLSection -HeaderText 'All Roles' {
                                New-HTMLTable -DataTable $roleData -Filtering $roleTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "High Privilege ($(@($roleSummary.HighPrivilegeRoles).Count))" {
                            if (@($roleSummary.HighPrivilegeRoles).Count -gt 0) {
                                New-HTMLSection -HeaderText 'High-Privilege Roles' {
                                    New-HTMLTable -DataTable $roleSummary.HighPrivilegeRoles -Filtering $roleTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'High-Privilege Roles' {
                                    New-HTMLText -Text 'No high-privilege roles were found in the current dataset.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Eligible Roles ($(@($roleSummary.EligibleRoles).Count))" {
                            if (@($roleSummary.EligibleRoles).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Roles With Eligible Assignments' {
                                    New-HTMLTable -DataTable $roleSummary.EligibleRoles -Filtering $roleTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Roles With Eligible Assignments' {
                                    New-HTMLText -Text 'No eligible role assignments were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($roleSummary.ReviewCandidates).Count))" {
                            if (@($roleSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Roles Requiring Review' {
                                    New-HTMLTable -DataTable $roleSummary.ReviewCandidates -Filtering $roleTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Roles Requiring Review' {
                                    New-HTMLText -Text 'No roles matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
