$Script:UsersPerServicePlan = [ordered] @{
    Name       = 'Azure Active Directory Users Per Service Plan'
    Enabled    = $true
    Execute    = {
        Get-MyUser -PerServicePlan
    }
    Processing = {

    }
    Summary    = {
        $userData = @($Script:Reporting['UsersPerServicePlan']['Data'])
        $totalUsers = $userData.Count
        $enabledUsers = 0
        $disabledUsers = 0
        $memberUsers = 0
        $guestUsers = 0
        $synchronizedUsers = 0
        $cloudOnlyUsers = 0
        $usersWithPlans = 0
        $usersWithoutPlans = 0
        $usersWithDeletedPlans = 0
        $neverSignedInUsers = 0
        $inactiveUsers = 0
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()
        $usersWithoutPlansList = [System.Collections.Generic.List[object]]::new()
        $usersWithDeletedPlansList = [System.Collections.Generic.List[object]]::new()

        $baseColumns = @(
            'DisplayName', 'Id', 'UserPrincipalName', 'UserDomain', 'GivenName', 'SurName', 'UserType', 'Enabled',
            'JobTitle', 'Mail', 'CreatedDateTime', 'CreatedDaysAgo', 'Manager', 'ManagerDisplayName',
            'ManagerUserPrincipalName', 'ManagerIsSynchronized', 'HasManager', 'LastPasswordChangeDateTime',
            'LastPasswordChangeDays', 'IsSynchronized', 'LastSynchronized', 'LastSynchronizedDays',
            'OnPremisesDistinguishedName', 'LastSignInDateTime', 'LastSignInDaysAgo',
            'LastNonInteractiveSignInDateTime', 'LastNonInteractiveSignInDaysAgo', 'NeverSignedIn',
            'DeletedServicePlans'
        )

        $servicePlanColumns = @()
        if ($totalUsers -gt 0) {
            foreach ($property in $userData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $servicePlanColumns += $property
                }
            }
        }

        $servicePlanSummary = [System.Collections.Generic.List[object]]::new()

        foreach ($user in $userData) {
            if ($user.Enabled) {
                $enabledUsers++
            } else {
                $disabledUsers++
            }

            if ($user.UserType -eq 'Guest') {
                $guestUsers++
            } else {
                $memberUsers++
            }

            if ($user.IsSynchronized -eq $true) {
                $synchronizedUsers++
            } elseif ($user.IsSynchronized -eq $false) {
                $cloudOnlyUsers++
            }

            $hasPlans = $false
            foreach ($servicePlanColumn in $servicePlanColumns) {
                if ([string]::IsNullOrWhiteSpace([string] $user.$servicePlanColumn)) {
                    continue
                }
                $hasPlans = $true
                break
            }

            if ($hasPlans) {
                $usersWithPlans++
            } else {
                $usersWithoutPlans++
                $usersWithoutPlansList.Add($user)
            }

            $hasDeletedPlans = $false
            if ($null -ne $user.DeletedServicePlans) {
                foreach ($deletedPlan in @($user.DeletedServicePlans)) {
                    if (-not [string]::IsNullOrWhiteSpace([string] $deletedPlan)) {
                        $hasDeletedPlans = $true
                        break
                    }
                }
            }
            if ($hasDeletedPlans) {
                $usersWithDeletedPlans++
                $usersWithDeletedPlansList.Add($user)
            }

            if ($user.NeverSignedIn -eq $true) {
                $neverSignedInUsers++
            }
            if ($null -ne $user.LastSignInDaysAgo -and $user.LastSignInDaysAgo -gt 90) {
                $inactiveUsers++
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if (-not $user.Enabled) {
                $reviewFlags.Add('Disabled')
            }
            if ($user.UserType -eq 'Guest') {
                $reviewFlags.Add('Guest or external')
            }
            if (-not $hasPlans) {
                $reviewFlags.Add('No active service plans')
            }
            if ($hasDeletedPlans) {
                $reviewFlags.Add('Deleted service plans')
            }
            if ($user.NeverSignedIn -eq $true) {
                $reviewFlags.Add('Never signed in')
            }
            if ($null -ne $user.LastSignInDaysAgo -and $user.LastSignInDaysAgo -gt 90) {
                $reviewFlags.Add('Inactive 90+ days')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($user | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        foreach ($servicePlanColumn in $servicePlanColumns) {
            $assignedUsers = 0
            foreach ($user in $userData) {
                if (-not [string]::IsNullOrWhiteSpace([string] $user.$servicePlanColumn)) {
                    $assignedUsers++
                }
            }
            $servicePlanSummary.Add([PSCustomObject]@{
                    ServicePlan = $servicePlanColumn
                    Users       = $assignedUsers
                })
        }

        $overview = @(
            [PSCustomObject]@{
                TotalUsers            = $totalUsers
                EnabledUsers          = $enabledUsers
                DisabledUsers         = $disabledUsers
                MemberUsers           = $memberUsers
                GuestUsers            = $guestUsers
                SynchronizedUsers     = $synchronizedUsers
                CloudOnlyUsers        = $cloudOnlyUsers
                UsersWithPlans        = $usersWithPlans
                UsersWithoutPlans     = $usersWithoutPlans
                UsersWithDeletedPlans = $usersWithDeletedPlans
                NeverSignedInUsers    = $neverSignedInUsers
                InactiveUsers         = $inactiveUsers
                ServicePlanColumns    = $servicePlanColumns.Count
            }
        )

        $assignmentDistribution = @(
            [PSCustomObject]@{ Name = 'With service plans'; Count = $usersWithPlans }
            [PSCustomObject]@{ Name = 'Without service plans'; Count = $usersWithoutPlans }
            [PSCustomObject]@{ Name = 'Deleted plans'; Count = $usersWithDeletedPlans }
            [PSCustomObject]@{ Name = 'Never signed in'; Count = $neverSignedInUsers }
            [PSCustomObject]@{ Name = 'Inactive 90+ days'; Count = $inactiveUsers }
        )

        $identityDistribution = @(
            [PSCustomObject]@{ Name = 'Members'; Count = $memberUsers }
            [PSCustomObject]@{ Name = 'Guests'; Count = $guestUsers }
            [PSCustomObject]@{ Name = 'Synchronized'; Count = $synchronizedUsers }
            [PSCustomObject]@{ Name = 'Cloud only'; Count = $cloudOnlyUsers }
        )

        [PSCustomObject]@{
            Overview              = $overview
            AssignmentDistribution = $assignmentDistribution
            IdentityDistribution  = $identityDistribution
            ServicePlanSummary    = @($servicePlanSummary | Sort-Object -Property @{ Expression = 'Users'; Descending = $true }, @{ Expression = 'ServicePlan'; Descending = $false })
            UsersWithoutPlans     = @($usersWithoutPlansList)
            UsersWithDeletedPlans = @($usersWithDeletedPlansList)
            ReviewCandidates      = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $servicePlanSummary = $Script:Reporting['UsersPerServicePlan']['Summary']
        $userData = @($Script:Reporting['UsersPerServicePlan']['Data'])
        $userCount = $userData.Count

        if ($userData) {
            $baseColumns = @(
                'DisplayName', 'Id', 'UserPrincipalName', 'UserDomain', 'GivenName', 'SurName', 'UserType', 'Enabled',
                'JobTitle', 'Mail', 'CreatedDateTime', 'CreatedDaysAgo', 'Manager', 'ManagerDisplayName',
                'ManagerUserPrincipalName', 'ManagerIsSynchronized', 'HasManager', 'LastPasswordChangeDateTime',
                'LastPasswordChangeDays', 'IsSynchronized', 'LastSynchronized', 'LastSynchronizedDays',
                'OnPremisesDistinguishedName', 'LastSignInDateTime', 'LastSignInDaysAgo',
                'LastNonInteractiveSignInDateTime', 'LastNonInteractiveSignInDaysAgo', 'NeverSignedIn',
                'DeletedServicePlans'
            )

            $servicePlanColumns = @()
            foreach ($property in $userData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $servicePlanColumns += $property
                }
            }

            $servicePlanConditions = {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Guest' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'UserType'
                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Member' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'UserType'
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $true -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'IsSynchronized'
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $false -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'IsSynchronized'
                New-HTMLTableCondition -Name 'NeverSignedIn' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'NeverSignedIn', 'LastSignInDateTime'
                New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Operator gt -Value 90 -ComparisonType number -BackgroundColor Salmon -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                New-HTMLTableCondition -Name 'DeletedServicePlans' -Operator ne -Value '' -ComparisonType string -BackgroundColor Orange -HighlightHeaders 'DeletedServicePlans'
                foreach ($servicePlanColumn in $servicePlanColumns) {
                    New-HTMLTableCondition -Name $servicePlanColumn -Operator eq -Value 'Assigned' -ComparisonType string -BackgroundColor GoldenFizz
                }
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($userCount)" {
                    if ($servicePlanSummary -and $servicePlanSummary.Overview) {
                        $overview = $servicePlanSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Users Per Service Plan Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Users' -Number $overview.TotalUsers -Subtitle 'Users in the service-plan matrix' -Icon '👤' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledUsers) / $($overview.DisabledUsers)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Members / Guests' -Number "$($overview.MemberUsers) / $($overview.GuestUsers)" -Subtitle 'Identity type split' -Icon '🌐' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'With / Without Plans' -Number "$($overview.UsersWithPlans) / $($overview.UsersWithoutPlans)" -Subtitle 'Service plan coverage' -Icon '🧩' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Deleted Plans' -Number $overview.UsersWithDeletedPlans -Subtitle 'Users with removed plan references' -Icon '🗑️' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Never Signed In' -Number $overview.NeverSignedInUsers -Subtitle 'Accounts without interactive sign-in' -Icon '🚪' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Inactive 90+ Days' -Number $overview.InactiveUsers -Subtitle 'Potential stale account review' -Icon '⏱️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Service Plan Columns' -Number $overview.ServicePlanColumns -Subtitle 'Distinct plans represented in the matrix' -Icon '📚' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Service Plan Coverage' {
                                        foreach ($item in $servicePlanSummary.AssignmentDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Identity Distribution' {
                                        foreach ($item in $servicePlanSummary.IdentityDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($servicePlanSummary.ServicePlanSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Top Assigned Service Plans' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Users Per Service Plan' {
                                            foreach ($item in ($servicePlanSummary.ServicePlanSummary | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.ServicePlan -Value $item.Users
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $servicePlanSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }
                New-HTMLTab -Name "Service Plan Matrix ($userCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Users ($userCount)" {
                            New-HTMLSection -HeaderText 'Users Per Service Plan Matrix' {
                                New-HTMLTable -DataTable $userData -Filtering $servicePlanConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Plan Summary ($(@($servicePlanSummary.ServicePlanSummary).Count))" {
                            if (@($servicePlanSummary.ServicePlanSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Service Plan Summary' {
                                    New-HTMLTable -DataTable $servicePlanSummary.ServicePlanSummary -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Service Plan Summary' {
                                    New-HTMLText -Text 'No service plan summary data was generated.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Without Plans ($(@($servicePlanSummary.UsersWithoutPlans).Count))" {
                            if (@($servicePlanSummary.UsersWithoutPlans).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users Without Service Plans' {
                                    New-HTMLTable -DataTable $servicePlanSummary.UsersWithoutPlans -Filtering $servicePlanConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users Without Service Plans' {
                                    New-HTMLText -Text 'No users without service plans were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Deleted Plans ($(@($servicePlanSummary.UsersWithDeletedPlans).Count))" {
                            if (@($servicePlanSummary.UsersWithDeletedPlans).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users With Deleted Service Plans' {
                                    New-HTMLTable -DataTable $servicePlanSummary.UsersWithDeletedPlans -Filtering $servicePlanConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users With Deleted Service Plans' {
                                    New-HTMLText -Text 'No users with deleted service plans were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($servicePlanSummary.ReviewCandidates).Count))" {
                            if (@($servicePlanSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users Requiring Service Plan Review' {
                                    New-HTMLTable -DataTable $servicePlanSummary.ReviewCandidates -Filtering $servicePlanConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users Requiring Service Plan Review' {
                                    New-HTMLText -Text 'No users matched the current service plan review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
