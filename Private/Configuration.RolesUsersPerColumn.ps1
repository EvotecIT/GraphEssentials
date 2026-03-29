$Script:RolesUsersPerColumn = [ordered] @{
    Name       = 'Azure Active Directory Roles Users Per Column'
    Enabled    = $true
    Execute    = {
        Get-MyRoleUsers -OnlyWithRoles -RolePerColumn
    }
    Processing = {

    }
    Summary    = {
        $matrixData = @($Script:Reporting['RolesUsersPerColumn']['Data'])
        $totalHolders = $matrixData.Count
        $baseColumns = @('Name', 'Enabled', 'UserPrincipalName', 'Mail', 'Status', 'Type', 'Location', 'CreatedDateTime', 'Licenses', 'LicenseAssignments', 'LicenseServices')
        $roleColumns = @()
        if ($totalHolders -gt 0) {
            foreach ($property in $matrixData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $roleColumns += $property
                }
            }
        }

        $disabledHolders = 0
        $guestHolders = 0
        $directHolders = 0
        $eligibleHolders = 0
        $groupBasedHolders = 0
        $typeCounts = @{}
        $statusCounts = @{}
        $groupBasedList = [System.Collections.Generic.List[object]]::new()
        $guestList = [System.Collections.Generic.List[object]]::new()
        $disabledList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($holder in $matrixData) {
            if ($holder.Enabled -eq $false) {
                $disabledHolders++
                $disabledList.Add($holder)
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

            $hasDirect = $false
            $hasEligible = $false
            $hasGroupBased = $false
            $roleCount = 0

            foreach ($roleColumn in $roleColumns) {
                $cellValue = $holder.$roleColumn
                if ($null -eq $cellValue) {
                    continue
                }

                $values = if ($cellValue -is [System.Collections.IEnumerable] -and $cellValue -isnot [string]) { @($cellValue) } else { @($cellValue) }
                foreach ($value in $values) {
                    if ([string]::IsNullOrWhiteSpace([string] $value)) {
                        continue
                    }
                    $roleCount++
                    if ([string] $value -eq 'Direct') {
                        $hasDirect = $true
                    } elseif ([string] $value -eq 'Eligible') {
                        $hasEligible = $true
                    } else {
                        $hasGroupBased = $true
                    }
                }
            }

            if ($hasDirect) {
                $directHolders++
            }
            if ($hasEligible) {
                $eligibleHolders++
            }
            if ($hasGroupBased) {
                $groupBasedHolders++
                $groupBasedList.Add($holder)
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($holder.Enabled -eq $false) {
                $reviewFlags.Add('Disabled')
            }
            if ($holderType -eq 'Guest') {
                $reviewFlags.Add('Guest or external')
            }
            if ($hasEligible) {
                $reviewFlags.Add('Eligible assignment')
            }
            if ($hasGroupBased) {
                $reviewFlags.Add('Group-derived role')
            }
            if ($roleCount -ge 3) {
                $reviewFlags.Add('Multiple role assignments')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($holder | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $roleSummary = [System.Collections.Generic.List[object]]::new()
        foreach ($roleColumn in $roleColumns) {
            $directCount = 0
            $eligibleCount = 0
            $groupCount = 0
            $holderCount = 0

            foreach ($holder in $matrixData) {
                $cellValue = $holder.$roleColumn
                if ($null -eq $cellValue) {
                    continue
                }

                $values = if ($cellValue -is [System.Collections.IEnumerable] -and $cellValue -isnot [string]) { @($cellValue) } else { @($cellValue) }
                $hasValue = $false
                foreach ($value in $values) {
                    if ([string]::IsNullOrWhiteSpace([string] $value)) {
                        continue
                    }
                    $hasValue = $true
                    if ([string] $value -eq 'Direct') {
                        $directCount++
                    } elseif ([string] $value -eq 'Eligible') {
                        $eligibleCount++
                    } else {
                        $groupCount++
                    }
                }

                if ($hasValue) {
                    $holderCount++
                }
            }

            $roleSummary.Add([PSCustomObject]@{
                    Role          = $roleColumn
                    Holders       = $holderCount
                    DirectCount   = $directCount
                    EligibleCount = $eligibleCount
                    GroupCount    = $groupCount
                })
        }

        $overview = @(
            [PSCustomObject]@{
                TotalRoleHolders  = $totalHolders
                DistinctRoles     = $roleColumns.Count
                DisabledHolders   = $disabledHolders
                GuestHolders      = $guestHolders
                DirectHolders     = $directHolders
                EligibleHolders   = $eligibleHolders
                GroupBasedHolders = $groupBasedHolders
            }
        )

        $assignmentDistribution = @(
            [PSCustomObject]@{ Name = 'Direct'; Count = $directHolders }
            [PSCustomObject]@{ Name = 'Eligible'; Count = $eligibleHolders }
            [PSCustomObject]@{ Name = 'Group based'; Count = $groupBasedHolders }
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

        [PSCustomObject]@{
            Overview               = $overview
            AssignmentDistribution = $assignmentDistribution
            TypeDistribution       = $typeDistribution
            StatusDistribution     = $statusDistribution
            RoleSummary            = @($roleSummary | Sort-Object -Property @{ Expression = 'Holders'; Descending = $true }, @{ Expression = 'Role'; Descending = $false })
            Disabled               = @($disabledList)
            Guests                 = @($guestList)
            GroupBased             = @($groupBasedList)
            ReviewCandidates       = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $matrixSummary = $Script:Reporting['RolesUsersPerColumn']['Summary']
        $matrixData = @($Script:Reporting['RolesUsersPerColumn']['Data'])
        $matrixCount = $matrixData.Count

        if ($matrixData) {
            $baseColumns = @('Name', 'Enabled', 'UserPrincipalName', 'Mail', 'Status', 'Type', 'Location', 'CreatedDateTime', 'Licenses', 'LicenseAssignments', 'LicenseServices')
            $roleColumns = @()
            foreach ($property in $matrixData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $roleColumns += $property
                }
            }

            $matrixConditions = {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Guest' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'Type', 'Name'
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Member' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'Type'
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Synchronized' -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'Status'
                New-HTMLTableCondition -Name 'Status' -Operator eq -Value 'Online' -ComparisonType string -BackgroundColor GoldenFizz -HighlightHeaders 'Status'
                foreach ($roleColumn in $roleColumns) {
                    New-HTMLTableCondition -Name $roleColumn -Operator eq -Value 'Direct' -ComparisonType string -BackgroundColor GoldenFizz
                    New-HTMLTableCondition -Name $roleColumn -Operator eq -Value 'Eligible' -ComparisonType string -BackgroundColor SpringGreen
                    New-HTMLTableConditionGroup -Conditions {
                        New-HTMLTableCondition -Name $roleColumn -Operator ne -Value 'Eligible' -ComparisonType string
                        New-HTMLTableCondition -Name $roleColumn -Operator ne -Value 'Direct' -ComparisonType string
                        New-HTMLTableCondition -Name $roleColumn -Operator ne -Value '' -ComparisonType string
                    } -Logic AND -BackgroundColor Orange -HighlightHeaders $roleColumn
                }
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($matrixCount)" {
                    if ($matrixSummary -and $matrixSummary.Overview) {
                        $overview = $matrixSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Role Coverage Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Holders' -Number $overview.TotalRoleHolders -Subtitle 'Identities represented in this role review' -Icon '🧮' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Roles Covered' -Number $overview.DistinctRoles -Subtitle 'Distinct roles in scope for this review' -Icon '📚' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Disabled / Guests' -Number "$($overview.DisabledHolders) / $($overview.GuestHolders)" -Subtitle 'High-review holder groups' -Icon '🚩' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Inherited Through Groups' -Number $overview.GroupBasedHolders -Subtitle 'Holders with role access coming from groups' -Icon '👥' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Direct / Eligible' -Number "$($overview.DirectHolders) / $($overview.EligibleHolders)" -Subtitle 'How holders receive role access' -Icon '📌' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Assignment Paths' {
                                        foreach ($item in $matrixSummary.AssignmentDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Identity Types' {
                                        foreach ($item in $matrixSummary.TypeDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($matrixSummary.RoleSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Most Common Roles In Scope' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Role Coverage By Holder Count' {
                                            foreach ($item in ($matrixSummary.RoleSummary | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.Role -Value $item.Holders
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $matrixSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }
                New-HTMLTab -Name "Role Coverage ($matrixCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Holders ($matrixCount)" {
                            New-HTMLSection -HeaderText 'Role Exposure Matrix' {
                                New-HTMLTable -DataTable $matrixData -Filtering $matrixConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Disabled ($(@($matrixSummary.Disabled).Count))" {
                            if (@($matrixSummary.Disabled).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Disabled Role Holders' {
                                    New-HTMLTable -DataTable $matrixSummary.Disabled -Filtering $matrixConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Disabled Role Holders' {
                                    New-HTMLText -Text 'No disabled role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Guests / External ($(@($matrixSummary.Guests).Count))" {
                            if (@($matrixSummary.Guests).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Guest and External Role Holders' {
                                    New-HTMLTable -DataTable $matrixSummary.Guests -Filtering $matrixConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Guest and External Role Holders' {
                                    New-HTMLText -Text 'No guest or external role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Inherited Through Groups ($(@($matrixSummary.GroupBased).Count))" {
                            if (@($matrixSummary.GroupBased).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Role Holders Inheriting Access Through Groups' {
                                    New-HTMLTable -DataTable $matrixSummary.GroupBased -Filtering $matrixConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Role Holders Inheriting Access Through Groups' {
                                    New-HTMLText -Text 'No group-based role holders were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Role Coverage Summary ($(@($matrixSummary.RoleSummary).Count))" {
                            if (@($matrixSummary.RoleSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Role Coverage Summary' {
                                    New-HTMLTable -DataTable $matrixSummary.RoleSummary -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Role Coverage Summary' {
                                    New-HTMLText -Text 'No role coverage summary data was generated.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($matrixSummary.ReviewCandidates).Count))" {
                            if (@($matrixSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Role Coverage Review Queue' {
                                    New-HTMLTable -DataTable $matrixSummary.ReviewCandidates -Filtering $matrixConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Role Coverage Review Queue' {
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
