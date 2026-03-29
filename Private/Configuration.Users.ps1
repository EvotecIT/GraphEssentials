$Script:Users = [ordered] @{
    Name       = 'Azure Active Directory Users'
    Enabled    = $true
    Execute    = {
        Get-MyUser
    }
    Processing = {

    }
    Summary    = {
        $userData = @($Script:Reporting['Users']['Data'])
        $totalUsers = $userData.Count
        $enabledUsers = 0
        $disabledUsers = 0
        $memberUsers = 0
        $guestUsers = 0
        $synchronizedUsers = 0
        $cloudOnlyUsers = 0
        $usersWithLicenses = 0
        $usersWithoutLicenses = 0
        $usersWithoutManager = 0
        $neverSignedInUsers = 0
        $inactiveUsers = 0
        $recentUsers = 0
        $domainCounts = @{}
        $userTypeCounts = @{}
        $memberAccounts = [System.Collections.Generic.List[object]]::new()
        $guestAccounts = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($user in $userData) {
            if ($user.Enabled) {
                $enabledUsers++
            } else {
                $disabledUsers++
            }

            $userType = if ($user.UserType) { $user.UserType } else { 'Unknown' }
            if (-not $userTypeCounts.ContainsKey($userType)) {
                $userTypeCounts[$userType] = 0
            }
            $userTypeCounts[$userType]++

            if ($user.UserType -eq 'Member') {
                $memberUsers++
                $memberAccounts.Add($user)
            } elseif ($user.UserType -eq 'Guest') {
                $guestUsers++
                $guestAccounts.Add($user)
            }

            if ($user.IsSynchronized -eq $true) {
                $synchronizedUsers++
            } elseif ($user.IsSynchronized -eq $false) {
                $cloudOnlyUsers++
            }

            if ($user.HasLicenses) {
                $usersWithLicenses++
            } else {
                $usersWithoutLicenses++
            }

            if (-not $user.HasManager) {
                $usersWithoutManager++
            }

            if ($user.NeverSignedIn -eq $true) {
                $neverSignedInUsers++
            }

            if (($null -ne $user.LastSignInDaysAgo -and $user.LastSignInDaysAgo -gt 90) -or ($null -ne $user.LastNonInteractiveSignInDaysAgo -and $user.LastNonInteractiveSignInDaysAgo -gt 90)) {
                $inactiveUsers++
            }

            if (($null -ne $user.LastSignInDaysAgo -and $user.LastSignInDaysAgo -le 30) -or ($null -ne $user.LastNonInteractiveSignInDaysAgo -and $user.LastNonInteractiveSignInDaysAgo -le 30)) {
                $recentUsers++
            }

            if ($user.UserDomain) {
                if (-not $domainCounts.ContainsKey($user.UserDomain)) {
                    $domainCounts[$user.UserDomain] = 0
                }
                $domainCounts[$user.UserDomain]++
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if (-not $user.Enabled) {
                $reviewFlags.Add('Disabled')
            }
            if ($user.UserType -eq 'Guest') {
                $reviewFlags.Add('Guest or external')
            }
            if (-not $user.HasManager) {
                $reviewFlags.Add('No manager')
            }
            if ($user.NeverSignedIn -eq $true) {
                $reviewFlags.Add('Never signed in')
            }
            if (($null -ne $user.LastSignInDaysAgo -and $user.LastSignInDaysAgo -gt 90) -or ($null -ne $user.LastNonInteractiveSignInDaysAgo -and $user.LastNonInteractiveSignInDaysAgo -gt 90)) {
                $reviewFlags.Add('Inactive 90+ days')
            }
            if ($null -ne $user.LastPasswordChangeDays -and $user.LastPasswordChangeDays -gt 180) {
                $reviewFlags.Add('Password older than 180 days')
            }
            if (-not $user.HasLicenses) {
                $reviewFlags.Add('Unlicensed')
            }
            if ($user.LicensesStatus -contains 'Error') {
                $reviewFlags.Add('License issue')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($user | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalUsers         = $totalUsers
                EnabledUsers       = $enabledUsers
                DisabledUsers      = $disabledUsers
                MemberUsers        = $memberUsers
                GuestUsers         = $guestUsers
                SynchronizedUsers  = $synchronizedUsers
                CloudOnlyUsers     = $cloudOnlyUsers
                LicensedUsers      = $usersWithLicenses
                UnlicensedUsers    = $usersWithoutLicenses
                UsersWithoutManager = $usersWithoutManager
                NeverSignedIn      = $neverSignedInUsers
                Inactive90Days     = $inactiveUsers
                Active30Days       = $recentUsers
            }
        )

        $domainDistribution = @(
            foreach ($key in $domainCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $domainCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $userTypeDistribution = @(
            foreach ($key in $userTypeCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $userTypeCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $signInDistribution = @(
            [PSCustomObject]@{ Name = 'No activity data'; Count = @($userData.Where({ $null -eq $_.NeverSignedIn -and $null -eq $_.LastSignInDaysAgo -and $null -eq $_.LastNonInteractiveSignInDaysAgo })).Count }
            [PSCustomObject]@{ Name = 'Never signed in'; Count = @($userData.Where({ $_.NeverSignedIn -eq $true })).Count }
            [PSCustomObject]@{ Name = '0-30 days'; Count = @($userData.Where({ ($null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -le 30) -or ($null -ne $_.LastNonInteractiveSignInDaysAgo -and $_.LastNonInteractiveSignInDaysAgo -le 30) })).Count }
            [PSCustomObject]@{ Name = '31-90 days'; Count = @($userData.Where({ (($null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 30 -and $_.LastSignInDaysAgo -le 90) -or ($null -ne $_.LastNonInteractiveSignInDaysAgo -and $_.LastNonInteractiveSignInDaysAgo -gt 30 -and $_.LastNonInteractiveSignInDaysAgo -le 90)) })).Count }
            [PSCustomObject]@{ Name = '91-180 days'; Count = @($userData.Where({ (($null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 90 -and $_.LastSignInDaysAgo -le 180) -or ($null -ne $_.LastNonInteractiveSignInDaysAgo -and $_.LastNonInteractiveSignInDaysAgo -gt 90 -and $_.LastNonInteractiveSignInDaysAgo -le 180)) })).Count }
            [PSCustomObject]@{ Name = '180+ days'; Count = @($userData.Where({ ($null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 180) -or ($null -ne $_.LastNonInteractiveSignInDaysAgo -and $_.LastNonInteractiveSignInDaysAgo -gt 180) })).Count }
        )

        $identitySourceDistribution = @(
            [PSCustomObject]@{ Name = 'Synchronized'; Count = $synchronizedUsers }
            [PSCustomObject]@{ Name = 'Cloud only'; Count = $cloudOnlyUsers }
            [PSCustomObject]@{ Name = 'Unknown'; Count = @($userData.Where({ $null -eq $_.IsSynchronized })).Count }
        )

        $licenseDistribution = @(
            [PSCustomObject]@{ Name = 'Licensed'; Count = $usersWithLicenses }
            [PSCustomObject]@{ Name = 'Unlicensed'; Count = $usersWithoutLicenses }
            [PSCustomObject]@{ Name = 'License issues'; Count = @($userData.Where({ $_.LicensesStatus -contains 'Error' })).Count }
        )

        [PSCustomObject]@{
            Overview                   = $overview
            DomainDistribution         = $domainDistribution
            UserTypeDistribution       = $userTypeDistribution
            SignInDistribution         = $signInDistribution
            IdentitySourceDistribution = $identitySourceDistribution
            LicenseDistribution        = $licenseDistribution
            MemberAccounts             = @($memberAccounts)
            GuestAccounts              = @($guestAccounts)
            ReviewCandidates           = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $userSummary = $Script:Reporting['Users']['Summary']
        $userData = @($Script:Reporting['Users']['Data'])
        $userCount = $userData.Count

        if ($userData) {
            $userTableConditions = {
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Guest' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'UserType'
                New-HTMLTableCondition -Name 'UserType' -Operator eq -Value 'Member' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'UserType'

                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $false -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'IsSynchronized'
                New-HTMLTableCondition -Name 'IsSynchronized' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen -HighlightHeaders 'IsSynchronized'

                New-HTMLTableCondition -Name 'HasManager' -Operator eq -Value $false -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'HasManager', 'ManagerDisplayName', 'ManagerUserPrincipalName'
                New-HTMLTableCondition -Name 'HasLicenses' -Operator eq -Value $false -ComparisonType string -BackgroundColor OldGold -HighlightHeaders 'HasLicenses', 'LicenseCount', 'Licenses'
                New-HTMLTableCondition -Name 'HasLicenses' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'HasLicenses', 'LicenseCount', 'Licenses'

                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Direct' -ComparisonType string -BackgroundColor LightSkyBlue
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Duplicate' -ComparisonType string -BackgroundColor PeachOrange
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Error' -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesStatus', 'LicensesErrors'
                New-HTMLTableCondition -Name 'LicensesStatus' -Operator eq -Value '' -ComparisonType string -BackgroundColor OldGold

                New-HTMLTableCondition -Name 'NeverSignedIn' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'NeverSignedIn', 'LastSignInDateTime', 'LastNonInteractiveSignInDateTime'

                New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'

                New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'

                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'
                New-HTMLTableCondition -Name 'LastPasswordChangeDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastPasswordChangeDays', 'LastPasswordChangeDateTime'

                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
                New-HTMLTableCondition -Name 'LastSynchronizedDays' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSynchronizedDays', 'LastSynchronized'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($userCount)" {
                    if ($userSummary -and $userSummary.Overview) {
                        $overview = $userSummary.Overview[0]
                        New-HTMLSection -HeaderText 'User Identity Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Users' -Number $overview.TotalUsers -Subtitle 'All users in scope' -Icon '👤' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledUsers) / $($overview.DisabledUsers)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Members / Guests' -Number "$($overview.MemberUsers) / $($overview.GuestUsers)" -Subtitle 'Identity type split' -Icon '🪪' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Licensed / Unlicensed' -Number "$($overview.LicensedUsers) / $($overview.UnlicensedUsers)" -Subtitle 'License coverage split' -Icon '🎫' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Synchronized / Cloud' -Number "$($overview.SynchronizedUsers) / $($overview.CloudOnlyUsers)" -Subtitle 'Identity source split' -Icon '🔄' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Without Manager' -Number $overview.UsersWithoutManager -Subtitle 'Users missing manager assignment' -Icon '🧭' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Never Signed In' -Number $overview.NeverSignedIn -Subtitle 'Only when sign-in activity is available' -Icon '⏱️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Inactive 90+ Days' -Number $overview.Inactive90Days -Subtitle 'No recent sign-in activity reported' -Icon '📉' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Users by Type' {
                                        foreach ($item in $userSummary.UserTypeDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'User Sign-in Recency' {
                                        foreach ($item in $userSummary.SignInDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Identity Posture' -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Identity Source Distribution' {
                                        foreach ($item in $userSummary.IdentitySourceDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'License Coverage' {
                                        foreach ($item in $userSummary.LicenseDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'User Domains' -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Top User Domains' {
                                        foreach ($item in ($userSummary.DomainDistribution | Select-Object -First 10)) {
                                            New-ChartBar -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $userSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }

                New-HTMLTab -Name "User Accounts ($userCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Users ($userCount)" {
                            New-HTMLSection -HeaderText 'All Users' {
                                New-HTMLTable -DataTable $userData -Filtering $userTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Members ($(@($userSummary.MemberAccounts).Count))" {
                            if (@($userSummary.MemberAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Member Accounts' {
                                    New-HTMLTable -DataTable $userSummary.MemberAccounts -Filtering $userTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Member Accounts' {
                                    New-HTMLText -Text 'No member accounts found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Guests / External ($(@($userSummary.GuestAccounts).Count))" {
                            if (@($userSummary.GuestAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Guest And External Accounts' {
                                    New-HTMLTable -DataTable $userSummary.GuestAccounts -Filtering $userTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Guest And External Accounts' {
                                    New-HTMLText -Text 'No guest or external accounts found in the user dataset.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($userSummary.ReviewCandidates).Count))" {
                            if (@($userSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Users Requiring Review' {
                                    New-HTMLTable -DataTable $userSummary.ReviewCandidates -Filtering $userTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Users Requiring Review' {
                                    New-HTMLText -Text 'No users matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Domains ($(@($userSummary.DomainDistribution).Count))" {
                            if (@($userSummary.DomainDistribution).Count -gt 0) {
                                New-HTMLSection -HeaderText 'User Domains' {
                                    New-HTMLTable -DataTable $userSummary.DomainDistribution -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'User Domains' {
                                    New-HTMLText -Text 'No user domains were detected in the current dataset.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
