$Script:UsersPerLicense = [ordered] @{
    Name       = 'Azure Active Directory Users Per License'
    Enabled    = $true
    Execute    = {
        Get-MyUser -PerLicense
    }
    Processing = {

    }
    Summary    = {
        $userData = @($Script:Reporting['UsersPerLicense']['Data'])
        $totalUsers = $userData.Count
        $enabledUsers = 0
        $disabledUsers = 0
        $memberUsers = 0
        $guestUsers = 0
        $synchronizedUsers = 0
        $cloudOnlyUsers = 0
        $usersWithAssignments = 0
        $usersWithoutAssignments = 0
        $usersWithDirectAssignments = 0
        $usersWithGroupAssignments = 0
        $usersWithLicenseErrors = 0
        $usersWithDifferentLicenses = 0
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()
        $usersWithLicenseErrorsList = [System.Collections.Generic.List[object]]::new()
        $usersWithoutAssignmentsList = [System.Collections.Generic.List[object]]::new()

        $baseColumns = @(
            'DisplayName', 'Id', 'UserPrincipalName', 'UserDomain', 'GivenName', 'SurName', 'UserType', 'Enabled',
            'JobTitle', 'Mail', 'CreatedDateTime', 'CreatedDaysAgo', 'Manager', 'ManagerDisplayName',
            'ManagerUserPrincipalName', 'ManagerIsSynchronized', 'HasManager', 'LastPasswordChangeDateTime',
            'LastPasswordChangeDays', 'IsSynchronized', 'LastSynchronized', 'LastSynchronizedDays',
            'OnPremisesDistinguishedName', 'LastSignInDateTime', 'LastSignInDaysAgo',
            'LastNonInteractiveSignInDateTime', 'LastNonInteractiveSignInDaysAgo', 'NeverSignedIn',
            'DifferentLicense', 'LicensesErrors'
        )

        $licenseColumns = @()
        if ($totalUsers -gt 0) {
            foreach ($property in $userData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $licenseColumns += $property
                }
            }
        }

        $licenseAssignmentSummary = [System.Collections.Generic.List[object]]::new()

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

            $hasAssignments = $false
            $hasDirectAssignments = $false
            $hasGroupAssignments = $false

            foreach ($column in $licenseColumns) {
                $cellValue = $user.$column
                $values = @()
                if ($null -eq $cellValue) {
                    $values = @()
                } elseif ($cellValue -is [System.Collections.IEnumerable] -and $cellValue -isnot [string]) {
                    $values = @($cellValue)
                } else {
                    $values = @($cellValue)
                }

                foreach ($value in $values) {
                    if ([string]::IsNullOrWhiteSpace([string] $value)) {
                        continue
                    }
                    $hasAssignments = $true
                    if ([string] $value -like '*Direct*') {
                        $hasDirectAssignments = $true
                    }
                    if ([string] $value -like '*Group*') {
                        $hasGroupAssignments = $true
                    }
                }
            }

            $differentLicenseValues = @()
            if ($null -ne $user.DifferentLicense) {
                if ($user.DifferentLicense -is [System.Collections.IEnumerable] -and $user.DifferentLicense -isnot [string]) {
                    $differentLicenseValues = @($user.DifferentLicense)
                } else {
                    $differentLicenseValues = @($user.DifferentLicense)
                }
            }

            foreach ($value in $differentLicenseValues) {
                if ([string]::IsNullOrWhiteSpace([string] $value)) {
                    continue
                }
                $hasAssignments = $true
                $usersWithDifferentLicenses++
                if ([string] $value -like '*Direct*') {
                    $hasDirectAssignments = $true
                }
                if ([string] $value -like '*Group*') {
                    $hasGroupAssignments = $true
                }
            }

            if ($hasAssignments) {
                $usersWithAssignments++
            } else {
                $usersWithoutAssignments++
                $usersWithoutAssignmentsList.Add($user)
            }

            if ($hasDirectAssignments) {
                $usersWithDirectAssignments++
            }
            if ($hasGroupAssignments) {
                $usersWithGroupAssignments++
            }

            $hasLicenseErrors = $false
            if ($null -ne $user.LicensesErrors) {
                foreach ($errorItem in @($user.LicensesErrors)) {
                    if (-not [string]::IsNullOrWhiteSpace([string] $errorItem)) {
                        $hasLicenseErrors = $true
                        break
                    }
                }
            }
            if ($hasLicenseErrors) {
                $usersWithLicenseErrors++
                $usersWithLicenseErrorsList.Add($user)
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if (-not $user.Enabled) {
                $reviewFlags.Add('Disabled')
            }
            if ($user.UserType -eq 'Guest') {
                $reviewFlags.Add('Guest or external')
            }
            if (-not $hasAssignments) {
                $reviewFlags.Add('No license assignments')
            }
            if ($hasLicenseErrors) {
                $reviewFlags.Add('License error')
            }
            if ($differentLicenseValues.Count -gt 0) {
                $reviewFlags.Add('Different license mapping')
            }
            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($user | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        foreach ($column in $licenseColumns) {
            $anyUsers = 0
            $directUsers = 0
            $groupUsers = 0
            foreach ($user in $userData) {
                $cellValue = $user.$column
                $values = @()
                if ($null -eq $cellValue) {
                    $values = @()
                } elseif ($cellValue -is [System.Collections.IEnumerable] -and $cellValue -isnot [string]) {
                    $values = @($cellValue)
                } else {
                    $values = @($cellValue)
                }

                $userHasAny = $false
                $userHasDirect = $false
                $userHasGroup = $false
                foreach ($value in $values) {
                    if ([string]::IsNullOrWhiteSpace([string] $value)) {
                        continue
                    }
                    $userHasAny = $true
                    if ([string] $value -like '*Direct*') {
                        $userHasDirect = $true
                    }
                    if ([string] $value -like '*Group*') {
                        $userHasGroup = $true
                    }
                }
                if ($userHasAny) {
                    $anyUsers++
                }
                if ($userHasDirect) {
                    $directUsers++
                }
                if ($userHasGroup) {
                    $groupUsers++
                }
            }

            $licenseAssignmentSummary.Add([PSCustomObject]@{
                    License    = $column
                    AnyUsers    = $anyUsers
                    DirectUsers = $directUsers
                    GroupUsers  = $groupUsers
                })
        }

        $overview = @(
            [PSCustomObject]@{
                TotalUsers                = $totalUsers
                EnabledUsers              = $enabledUsers
                DisabledUsers             = $disabledUsers
                MemberUsers               = $memberUsers
                GuestUsers                = $guestUsers
                SynchronizedUsers         = $synchronizedUsers
                CloudOnlyUsers            = $cloudOnlyUsers
                UsersWithAssignments      = $usersWithAssignments
                UsersWithoutAssignments   = $usersWithoutAssignments
                UsersWithDirectAssignments = $usersWithDirectAssignments
                UsersWithGroupAssignments = $usersWithGroupAssignments
                UsersWithLicenseErrors    = $usersWithLicenseErrors
            }
        )

        $assignmentDistribution = @(
            [PSCustomObject]@{ Name = 'With assignments'; Count = $usersWithAssignments }
            [PSCustomObject]@{ Name = 'Without assignments'; Count = $usersWithoutAssignments }
            [PSCustomObject]@{ Name = 'Direct assignments'; Count = $usersWithDirectAssignments }
            [PSCustomObject]@{ Name = 'Group assignments'; Count = $usersWithGroupAssignments }
            [PSCustomObject]@{ Name = 'License errors'; Count = $usersWithLicenseErrors }
        )

        $identityDistribution = @(
            [PSCustomObject]@{ Name = 'Members'; Count = $memberUsers }
            [PSCustomObject]@{ Name = 'Guests'; Count = $guestUsers }
            [PSCustomObject]@{ Name = 'Synchronized'; Count = $synchronizedUsers }
            [PSCustomObject]@{ Name = 'Cloud only'; Count = $cloudOnlyUsers }
        )

        [PSCustomObject]@{
            Overview                 = $overview
            AssignmentDistribution   = $assignmentDistribution
            IdentityDistribution     = $identityDistribution
            LicenseAssignmentSummary = @($licenseAssignmentSummary | Sort-Object AnyUsers -Descending)
            UsersWithLicenseErrors   = @($usersWithLicenseErrorsList)
            UsersWithoutAssignments  = @($usersWithoutAssignmentsList)
            ReviewCandidates         = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $usersPerLicenseSummary = $Script:Reporting['UsersPerLicense']['Summary']
        $userData = @($Script:Reporting['UsersPerLicense']['Data'])
        $userCount = $userData.Count

        if ($userData) {
            $baseColumns = @(
                'DisplayName', 'Id', 'UserPrincipalName', 'UserDomain', 'GivenName', 'SurName', 'UserType', 'Enabled',
                'JobTitle', 'Mail', 'CreatedDateTime', 'CreatedDaysAgo', 'Manager', 'ManagerDisplayName',
                'ManagerUserPrincipalName', 'ManagerIsSynchronized', 'HasManager', 'LastPasswordChangeDateTime',
                'LastPasswordChangeDays', 'IsSynchronized', 'LastSynchronized', 'LastSynchronizedDays',
                'OnPremisesDistinguishedName', 'LastSignInDateTime', 'LastSignInDaysAgo',
                'LastNonInteractiveSignInDateTime', 'LastNonInteractiveSignInDaysAgo', 'NeverSignedIn',
                'DifferentLicense', 'LicensesErrors'
            )

            $licenseColumns = @()
            foreach ($property in $userData[0].PSObject.Properties.Name) {
                if ($property -notin $baseColumns) {
                    $licenseColumns += $property
                }
            }

            $userPerLicenseConditions = {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen
                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Guest' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'UserType'
                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Member' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'UserType'
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $true -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'IsSynchronized'
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $false -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'IsSynchronized'
                New-HTMLTableCondition -Name 'LicensesErrors' -Operator ne -Value '' -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesErrors'
                New-HTMLTableCondition -Name 'DifferentLicense' -Operator ne -Value '' -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'DifferentLicense'

                foreach ($Name in $licenseColumns) {
                    New-HTMLTableCondition -Name $Name -Operator eq -Value 'Direct' -ComparisonType string -BackgroundColor GoldenFizz
                    New-HTMLTableCondition -Name $Name -Operator eq -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                    New-HTMLTableConditionGroup -Conditions {
                        New-HTMLTableCondition -Name $Name -Operator ne -Value 'Group' -ComparisonType string
                        New-HTMLTableCondition -Name $Name -Operator ne -Value 'Direct' -ComparisonType string
                        New-HTMLTableCondition -Name $Name -Operator ne -Value '' -ComparisonType string
                    } -Logic AND -BackgroundColor Orange -HighlightHeaders $Name
                }
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($userCount)" {
                    if ($usersPerLicenseSummary -and $usersPerLicenseSummary.Overview) {
                        $overview = $usersPerLicenseSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Users Per License Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Users' -Number $overview.TotalUsers -Subtitle 'Users in the assignment matrix' -Icon '👤' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledUsers) / $($overview.DisabledUsers)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Members / Guests' -Number "$($overview.MemberUsers) / $($overview.GuestUsers)" -Subtitle 'Identity type split' -Icon '🪪' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'With / Without Assignments' -Number "$($overview.UsersWithAssignments) / $($overview.UsersWithoutAssignments)" -Subtitle 'License matrix coverage' -Icon '🎫' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Direct Assignments' -Number $overview.UsersWithDirectAssignments -Subtitle 'Users with direct license grants' -Icon '📌' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Group Assignments' -Number $overview.UsersWithGroupAssignments -Subtitle 'Users with group-based grants' -Icon '👥' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'License Errors' -Number $overview.UsersWithLicenseErrors -Subtitle 'Users with assignment issues' -Icon '🚨' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Synchronized / Cloud' -Number "$($overview.SynchronizedUsers) / $($overview.CloudOnlyUsers)" -Subtitle 'Identity source split' -Icon '🔄' -IconColor '#6c757d' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Assignment Coverage' {
                                        foreach ($item in $usersPerLicenseSummary.AssignmentDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Identity Distribution' {
                                        foreach ($item in $usersPerLicenseSummary.IdentityDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($usersPerLicenseSummary.LicenseAssignmentSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Top Assigned Licenses' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Users Per License' {
                                            foreach ($item in ($usersPerLicenseSummary.LicenseAssignmentSummary | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.License -Value $item.AnyUsers
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $usersPerLicenseSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }

                New-HTMLTab -Name "Assignment Matrix ($userCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Users ($userCount)" {
                            New-HTMLSection -HeaderText 'Users Per License Matrix' {
                                New-HTMLTable -DataTable $userData -Filtering $userPerLicenseConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "License Summary ($(@($usersPerLicenseSummary.LicenseAssignmentSummary).Count))" {
                            if (@($usersPerLicenseSummary.LicenseAssignmentSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'License Assignment Summary' {
                                    New-HTMLTable -DataTable $usersPerLicenseSummary.LicenseAssignmentSummary -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'License Assignment Summary' {
                                    New-HTMLText -Text 'No license assignment summary data was generated.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Errors ($(@($usersPerLicenseSummary.UsersWithLicenseErrors).Count))" {
                            if (@($usersPerLicenseSummary.UsersWithLicenseErrors).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users With License Errors' {
                                    New-HTMLTable -DataTable $usersPerLicenseSummary.UsersWithLicenseErrors -Filtering $userPerLicenseConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users With License Errors' {
                                    New-HTMLText -Text 'No users with license errors were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Without Assignments ($(@($usersPerLicenseSummary.UsersWithoutAssignments).Count))" {
                            if (@($usersPerLicenseSummary.UsersWithoutAssignments).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users Without License Assignments' {
                                    New-HTMLTable -DataTable $usersPerLicenseSummary.UsersWithoutAssignments -Filtering $userPerLicenseConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users Without License Assignments' {
                                    New-HTMLText -Text 'No users without license assignments were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($usersPerLicenseSummary.ReviewCandidates).Count))" {
                            if (@($usersPerLicenseSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users Requiring License Review' {
                                    New-HTMLTable -DataTable $usersPerLicenseSummary.ReviewCandidates -Filtering $userPerLicenseConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users Requiring License Review' {
                                    New-HTMLText -Text 'No users matched the current license review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
