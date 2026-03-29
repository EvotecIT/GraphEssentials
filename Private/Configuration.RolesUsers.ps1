$Script:RolesUsers = [ordered] @{
    Name       = 'Azure Active Directory Roles Users'
    Enabled    = $true
    Execute    = {
        Get-MyRoleUsers -OnlyWithRoles
    }
    Processing = {

    }
    Summary    = {
        $roleUserData = @($Script:Reporting['RolesUsers']['Data'])
        $totalHolders = $roleUserData.Count
        $enabledHolders = 0
        $disabledHolders = 0
        $unknownStatusHolders = 0
        $guestHolders = 0
        $workloadHolders = 0
        $groupHolders = 0
        $holdersWithDirectRoles = 0
        $holdersWithEligibleRoles = 0
        $holdersWithGroupDirectRoles = 0
        $holdersWithGroupEligibleRoles = 0
        $licensedUsers = 0
        $typeCounts = @{}
        $statusCounts = @{}
        $roleCounts = @{}
        $guestList = [System.Collections.Generic.List[object]]::new()
        $workloadList = [System.Collections.Generic.List[object]]::new()
        $groupDerivedList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($holder in $roleUserData) {
            if ($holder.Enabled -eq $true) {
                $enabledHolders++
            } elseif ($holder.Enabled -eq $false) {
                $disabledHolders++
            } else {
                $unknownStatusHolders++
            }

            $holderType = if ($holder.Type) { $holder.Type } else { 'Unknown' }
            if (-not $typeCounts.ContainsKey($holderType)) {
                $typeCounts[$holderType] = 0
            }
            $typeCounts[$holderType]++

            $holderStatus = if ($holder.Status) { $holder.Status } else { 'Unknown' }
            if (-not $statusCounts.ContainsKey($holderStatus)) {
                $statusCounts[$holderStatus] = 0
            }
            $statusCounts[$holderStatus]++

            if ($holderType -eq 'Guest') {
                $guestHolders++
                $guestList.Add($holder)
            }

            if ($holder.AppId) {
                $workloadHolders++
                $workloadList.Add($holder)
            }

            if ($holderType -in @('SecurityGroup', 'DistributionGroup')) {
                $groupHolders++
            }

            if ($holder.DirectCount -gt 0) {
                $holdersWithDirectRoles++
            }
            if ($holder.EligibleCount -gt 0) {
                $holdersWithEligibleRoles++
            }
            if ($holder.GroupDirectCount -gt 0) {
                $holdersWithGroupDirectRoles++
            }
            if ($holder.GroupEligibleCount -gt 0) {
                $holdersWithGroupEligibleRoles++
            }
            if ($holder.GroupDirectCount -gt 0 -or $holder.GroupEligibleCount -gt 0) {
                $groupDerivedList.Add($holder)
            }

            if ($holder.Licenses) {
                $licenseValues = @($holder.Licenses)
                if ($licenseValues.Count -gt 0) {
                    $licensedUsers++
                }
            }

            $holderRoles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($propertyName in 'Direct', 'Eligible', 'GroupDirectRoles', 'GroupEligibleRoles') {
                $propertyValue = $holder.$propertyName
                if ($null -eq $propertyValue) {
                    continue
                }
                $values = if ($propertyValue -is [System.Collections.IEnumerable] -and $propertyValue -isnot [string]) { @($propertyValue) } else { @($propertyValue) }
                foreach ($value in $values) {
                    if ([string]::IsNullOrWhiteSpace([string] $value)) {
                        continue
                    }
                    [void] $holderRoles.Add([string] $value)
                }
            }

            foreach ($roleName in $holderRoles) {
                if (-not $roleCounts.ContainsKey($roleName)) {
                    $roleCounts[$roleName] = 0
                }
                $roleCounts[$roleName]++
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($holder.Enabled -eq $false) {
                $reviewFlags.Add('Disabled')
            }
            if ($holderType -eq 'Guest') {
                $reviewFlags.Add('Guest or external')
            }
            if ($holder.AppId) {
                $reviewFlags.Add('Workload identity')
            }
            if ($holder.EligibleCount -gt 0 -or $holder.GroupEligibleCount -gt 0) {
                $reviewFlags.Add('Eligible assignment')
            }
            if ($holder.GroupDirectCount -gt 0 -or $holder.GroupEligibleCount -gt 0) {
                $reviewFlags.Add('Group-derived role')
            }
            if ($holder.AllRolesCount -ge 3) {
                $reviewFlags.Add('Multiple role assignments')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($holder | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalRoleHolders            = $totalHolders
                EnabledHolders              = $enabledHolders
                DisabledHolders             = $disabledHolders
                UnknownStatusHolders        = $unknownStatusHolders
                GuestHolders                = $guestHolders
                WorkloadHolders             = $workloadHolders
                GroupHolders                = $groupHolders
                HoldersWithDirectRoles      = $holdersWithDirectRoles
                HoldersWithEligibleRoles    = $holdersWithEligibleRoles
                HoldersWithGroupDirectRoles = $holdersWithGroupDirectRoles
                HoldersWithGroupEligibleRoles = $holdersWithGroupEligibleRoles
                LicensedUsers               = $licensedUsers
            }
        )

        $assignmentDistribution = @(
            [PSCustomObject]@{ Name = 'Direct assignments'; Count = $holdersWithDirectRoles }
            [PSCustomObject]@{ Name = 'Eligible assignments'; Count = $holdersWithEligibleRoles }
            [PSCustomObject]@{ Name = 'Group direct'; Count = $holdersWithGroupDirectRoles }
            [PSCustomObject]@{ Name = 'Group eligible'; Count = $holdersWithGroupEligibleRoles }
        )

        $typeDistribution = @(
            foreach ($key in $typeCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $typeCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $statusDistribution = @(
            foreach ($key in $statusCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $statusCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $roleDistribution = @(
            foreach ($key in $roleCounts.Keys) {
                [PSCustomObject]@{
                    Role    = $key
                    Holders = $roleCounts[$key]
                }
            }
        ) | Sort-Object -Property @{ Expression = 'Holders'; Descending = $true }, @{ Expression = 'Role'; Descending = $false }

        [PSCustomObject]@{
            Overview               = $overview
            AssignmentDistribution = $assignmentDistribution
            TypeDistribution       = $typeDistribution
            StatusDistribution     = $statusDistribution
            RoleDistribution       = $roleDistribution
            Guests                 = @($guestList)
            Workloads              = @($workloadList)
            GroupDerived           = @($groupDerivedList)
            ReviewCandidates       = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $roleUserSummary = $Script:Reporting['RolesUsers']['Summary']
        $roleUserData = @($Script:Reporting['RolesUsers']['Data'])
        $roleHolderCount = $roleUserData.Count

        if ($roleUserData) {
            $roleUserConditions = {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Member' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Guest' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'Type', 'Name'
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'SecurityGroup' -ComparisonType string -BackgroundColor LaserLemon -HighlightHeaders 'Type', 'Name'
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'DistributionGroup' -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'Type', 'Name'
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Synchronized' -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'Status'
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Online' -ComparisonType string -BackgroundColor GoldenFizz -HighlightHeaders 'Status'
                New-HTMLTableCondition -Name 'DirectCount' -Operator gt -Value 0 -ComparisonType number -BackgroundColor LightGreen -HighlightHeaders 'DirectCount', 'Direct'
                New-HTMLTableCondition -Name 'EligibleCount' -Operator gt -Value 0 -ComparisonType number -BackgroundColor LightSkyBlue -HighlightHeaders 'EligibleCount', 'Eligible'
                New-HTMLTableCondition -Name 'GroupDirectCount' -Operator gt -Value 0 -ComparisonType number -BackgroundColor LightCyan -HighlightHeaders 'GroupDirectCount', 'GroupDirectRoles', 'GroupRoleAssignments'
                New-HTMLTableCondition -Name 'GroupEligibleCount' -Operator gt -Value 0 -ComparisonType number -BackgroundColor LemonChiffon -HighlightHeaders 'GroupEligibleCount', 'GroupEligibleRoles', 'GroupRoleAssignments'
                New-HTMLTableCondition -Name 'AllRolesCount' -Operator ge -Value 3 -ComparisonType number -BackgroundColor Orange -HighlightHeaders 'AllRolesCount', 'Direct', 'Eligible', 'GroupDirectRoles', 'GroupEligibleRoles'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($roleHolderCount)" {
                    if ($roleUserSummary -and $roleUserSummary.Overview) {
                        $overview = $roleUserSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Role Holder Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Holders' -Number $overview.TotalRoleHolders -Subtitle 'Identities with at least one role' -Icon '🪪' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledHolders) / $($overview.DisabledHolders)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Guests / Workloads' -Number "$($overview.GuestHolders) / $($overview.WorkloadHolders)" -Subtitle 'External and workload identity holders' -Icon '🌐' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Group Holders' -Number $overview.GroupHolders -Subtitle 'Role-assignable groups in the set' -Icon '👥' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Direct / Eligible' -Number "$($overview.HoldersWithDirectRoles) / $($overview.HoldersWithEligibleRoles)" -Subtitle 'Assignment model split' -Icon '📌' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Group Direct / Eligible' -Number "$($overview.HoldersWithGroupDirectRoles) / $($overview.HoldersWithGroupEligibleRoles)" -Subtitle 'Nested role exposure' -Icon '🧬' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Licensed Users' -Number $overview.LicensedUsers -Subtitle 'User holders with license data' -Icon '🎫' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Assignment Distribution' {
                                        foreach ($item in $roleUserSummary.AssignmentDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Holder Type Distribution' {
                                        foreach ($item in $roleUserSummary.TypeDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($roleUserSummary.RoleDistribution).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Top Roles By Holder Count' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Most Common Roles' {
                                            foreach ($item in ($roleUserSummary.RoleDistribution | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.Role -Value $item.Holders
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $roleUserSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }
                New-HTMLTab -Name "Role Holders ($roleHolderCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Holders ($roleHolderCount)" {
                            New-HTMLSection -HeaderText 'Role Holders' {
                                New-HTMLTable -DataTable $roleUserData -Filtering $roleUserConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Guests / External ($(@($roleUserSummary.Guests).Count))" {
                            if (@($roleUserSummary.Guests).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Guest and External Role Holders' {
                                    New-HTMLTable -DataTable $roleUserSummary.Guests -Filtering $roleUserConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Guest and External Role Holders' {
                                    New-HTMLText -Text 'No guest or external role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Workloads ($(@($roleUserSummary.Workloads).Count))" {
                            if (@($roleUserSummary.Workloads).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Workload Identity Role Holders' {
                                    New-HTMLTable -DataTable $roleUserSummary.Workloads -Filtering $roleUserConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Workload Identity Role Holders' {
                                    New-HTMLText -Text 'No workload identity role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Group Derived ($(@($roleUserSummary.GroupDerived).Count))" {
                            if (@($roleUserSummary.GroupDerived).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Group-Derived Role Holders' {
                                    New-HTMLTable -DataTable $roleUserSummary.GroupDerived -Filtering $roleUserConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Group-Derived Role Holders' {
                                    New-HTMLText -Text 'No group-derived role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Role Summary ($(@($roleUserSummary.RoleDistribution).Count))" {
                            if (@($roleUserSummary.RoleDistribution).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Role Distribution Summary' {
                                    New-HTMLTable -DataTable $roleUserSummary.RoleDistribution -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Role Distribution Summary' {
                                    New-HTMLText -Text 'No role summary data was generated.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($roleUserSummary.ReviewCandidates).Count))" {
                            if (@($roleUserSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Role Holders Requiring Review' {
                                    New-HTMLTable -DataTable $roleUserSummary.ReviewCandidates -Filtering $roleUserConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Role Holders Requiring Review' {
                                    New-HTMLText -Text 'No role holders matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
