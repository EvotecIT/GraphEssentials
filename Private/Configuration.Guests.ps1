$Script:Guests = [ordered] @{
    Name       = 'Azure Active Directory Guests and External Users'
    Enabled    = $true
    Execute    = {
        Get-MyGuest
    }
    Processing = {

    }
    Summary    = {
        $guestData = @($Script:Reporting['Guests']['Data'])
        $totalGuests = @($guestData).Count
        $enabledGuests = 0
        $disabledGuests = 0
        $pendingGuests = 0
        $acceptedGuests = 0
        $neverSignedInGuests = 0
        $neverSuccessfulSignInGuests = 0
        $staleGuests = 0
        $recentGuests = 0
        $guestWithRoles = 0
        $guestWithLicenses = 0
        $guestDomains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $domainCounts = @{}
        $stateCounts = @{}
        $creationTypeCounts = @{}
        $pendingAccounts = [System.Collections.Generic.List[object]]::new()
        $acceptedAccounts = [System.Collections.Generic.List[object]]::new()
        $neverSuccessfulAccounts = [System.Collections.Generic.List[object]]::new()
        $staleAccounts = [System.Collections.Generic.List[object]]::new()
        $recentAccounts = [System.Collections.Generic.List[object]]::new()
        $privilegedAccounts = [System.Collections.Generic.List[object]]::new()
        $licensedAccounts = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($guest in $guestData) {
            if ($guest.Enabled) {
                $enabledGuests++
            } else {
                $disabledGuests++
            }

            if ($guest.ExternalUserState -eq 'PendingAcceptance') {
                $pendingGuests++
                $pendingAccounts.Add($guest)
            } elseif ($guest.ExternalUserState -eq 'Accepted') {
                $acceptedGuests++
                $acceptedAccounts.Add($guest)
            }

            if ($guest.NeverSignedIn) {
                $neverSignedInGuests++
            }
            if ($guest.NeverSuccessfullySignedIn) {
                $neverSuccessfulSignInGuests++
                $neverSuccessfulAccounts.Add($guest)
            }
            if ($guest.HasRoles) {
                $guestWithRoles++
                $privilegedAccounts.Add($guest)
            }
            if ($guest.HasLicenses) {
                $guestWithLicenses++
                $licensedAccounts.Add($guest)
            }
            if ($guest.GuestDomain) {
                [void] $guestDomains.Add($guest.GuestDomain)
                if (-not $domainCounts.ContainsKey($guest.GuestDomain)) {
                    $domainCounts[$guest.GuestDomain] = 0
                }
                $domainCounts[$guest.GuestDomain]++
            }

            $guestState = if ($guest.ExternalUserState) { $guest.ExternalUserState } else { 'Unknown' }
            if (-not $stateCounts.ContainsKey($guestState)) {
                $stateCounts[$guestState] = 0
            }
            $stateCounts[$guestState]++

            $creationType = if ($guest.CreationType) { $guest.CreationType } else { 'Unknown' }
            if (-not $creationTypeCounts.ContainsKey($creationType)) {
                $creationTypeCounts[$creationType] = 0
            }
            $creationTypeCounts[$creationType]++

            if ($null -ne $guest.LastSuccessfulSignInDaysAgo -and $guest.LastSuccessfulSignInDaysAgo -gt 180) {
                $staleGuests++
                $staleAccounts.Add($guest)
            }

            if ($null -ne $guest.LastSuccessfulSignInDaysAgo -and $guest.LastSuccessfulSignInDaysAgo -le 30) {
                $recentGuests++
                $recentAccounts.Add($guest)
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if (-not $guest.Enabled) {
                $reviewFlags.Add('Disabled')
            }
            if ($guest.ExternalUserState -eq 'PendingAcceptance') {
                $reviewFlags.Add('Pending acceptance')
            }
            if ($guest.NeverSignedIn) {
                $reviewFlags.Add('Never signed in')
            }
            if ($guest.NeverSuccessfullySignedIn) {
                $reviewFlags.Add('No successful sign-in')
            }
            if (($null -ne $guest.LastSignInDaysAgo -and $guest.LastSignInDaysAgo -gt 180) -or ($null -ne $guest.LastNonInteractiveSignInDaysAgo -and $guest.LastNonInteractiveSignInDaysAgo -gt 180)) {
                $reviewFlags.Add('Stale sign-in')
            }
            if ($null -ne $guest.LastSuccessfulSignInDaysAgo -and $guest.LastSuccessfulSignInDaysAgo -gt 180) {
                $reviewFlags.Add('No successful sign-in 180+ days')
            }
            if ($guest.HasRoles) {
                $reviewFlags.Add('Privileged')
            }
            if ($guest.HasLicenses) {
                $reviewFlags.Add('Licensed')
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($guest | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalGuests        = $totalGuests
                EnabledGuests      = $enabledGuests
                DisabledGuests     = $disabledGuests
                PendingAcceptance  = $pendingGuests
                AcceptedGuests     = $acceptedGuests
                NeverSignedIn      = $neverSignedInGuests
                NeverSuccessfulSignIn = $neverSuccessfulSignInGuests
                StaleSuccessful180Days = $staleGuests
                ActiveSuccessful30Days = $recentGuests
                GuestsWithRoles    = $guestWithRoles
                GuestsWithLicenses = $guestWithLicenses
                DistinctDomains    = $guestDomains.Count
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

        $stateDistribution = @(
            foreach ($key in $stateCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $stateCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $signInDistribution = @(
            [PSCustomObject]@{ Name = 'No activity data'; Count = @($guestData.Where({ $null -eq $_.NeverSignedIn -and $null -eq $_.LastSignInDaysAgo -and $null -eq $_.LastNonInteractiveSignInDaysAgo })).Count }
            [PSCustomObject]@{ Name = 'Never signed in'; Count = $neverSignedInGuests }
            [PSCustomObject]@{ Name = '0-30 days'; Count = @($guestData.Where({ $null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -le 30 })).Count }
            [PSCustomObject]@{ Name = '31-90 days'; Count = @($guestData.Where({ $null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 30 -and $_.LastSignInDaysAgo -le 90 })).Count }
            [PSCustomObject]@{ Name = '91-180 days'; Count = @($guestData.Where({ $null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 90 -and $_.LastSignInDaysAgo -le 180 })).Count }
            [PSCustomObject]@{ Name = '180+ days'; Count = @($guestData.Where({ $null -ne $_.LastSignInDaysAgo -and $_.LastSignInDaysAgo -gt 180 })).Count }
        )

        $successfulSignInDistribution = @(
            [PSCustomObject]@{ Name = 'No activity data'; Count = @($guestData.Where({ $null -eq $_.NeverSuccessfullySignedIn -and $null -eq $_.LastSuccessfulSignInDaysAgo })).Count }
            [PSCustomObject]@{ Name = 'No successful sign-in'; Count = $neverSuccessfulSignInGuests }
            [PSCustomObject]@{ Name = '0-30 days'; Count = @($guestData.Where({ $null -ne $_.LastSuccessfulSignInDaysAgo -and $_.LastSuccessfulSignInDaysAgo -le 30 })).Count }
            [PSCustomObject]@{ Name = '31-90 days'; Count = @($guestData.Where({ $null -ne $_.LastSuccessfulSignInDaysAgo -and $_.LastSuccessfulSignInDaysAgo -gt 30 -and $_.LastSuccessfulSignInDaysAgo -le 90 })).Count }
            [PSCustomObject]@{ Name = '91-180 days'; Count = @($guestData.Where({ $null -ne $_.LastSuccessfulSignInDaysAgo -and $_.LastSuccessfulSignInDaysAgo -gt 90 -and $_.LastSuccessfulSignInDaysAgo -le 180 })).Count }
            [PSCustomObject]@{ Name = '180+ days'; Count = @($guestData.Where({ $null -ne $_.LastSuccessfulSignInDaysAgo -and $_.LastSuccessfulSignInDaysAgo -gt 180 })).Count }
        )

        $accessDistribution = @(
            [PSCustomObject]@{ Name = 'Enabled'; Count = $enabledGuests }
            [PSCustomObject]@{ Name = 'Disabled'; Count = $disabledGuests }
            [PSCustomObject]@{ Name = 'Pending acceptance'; Count = $pendingGuests }
            [PSCustomObject]@{ Name = 'Never signed in'; Count = $neverSignedInGuests }
            [PSCustomObject]@{ Name = 'No successful sign-in'; Count = $neverSuccessfulSignInGuests }
            [PSCustomObject]@{ Name = 'Successful sign-in 180+ days'; Count = $staleGuests }
            [PSCustomObject]@{ Name = 'With roles'; Count = $guestWithRoles }
            [PSCustomObject]@{ Name = 'With licenses'; Count = $guestWithLicenses }
        )

        $creationTypeDistribution = @(
            foreach ($key in $creationTypeCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $creationTypeCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $authenticationSummary = @()
        try {
            $authPolicy = Get-MyAuthenticationMethodsPolicy
            if ($authPolicy -and $authPolicy.Methods -and $authPolicy.Methods.Email) {
                $authenticationSummary = @(
                    [PSCustomObject]@{
                        ExternalEmailOtpAllowed = $authPolicy.Methods.Email.AllowExternalIdToUseEmailOtp
                        EmailMethodState        = $authPolicy.Methods.Email.State
                        LastModifiedDateTime    = $authPolicy.LastModifiedDateTime
                    }
                )
            }
        } catch {
            Write-Warning -Message "Guests Summary - Failed to get authentication methods policy. Error: $($_.Exception.Message)"
        }

        $termsOfUseSummary = @()
        try {
            $termsOfUse = @(Get-MyTermsOfUse)
            if ($termsOfUse.Count -gt 0) {
                $externalTerms = @(
                    foreach ($agreement in $termsOfUse) {
                        if ($agreement.Summary.UserScope -like '*External*') {
                            [PSCustomObject]@{
                                DisplayName         = $agreement.Summary.DisplayName
                                AcceptanceRequired  = $agreement.Summary.AcceptanceRequired
                                ViewingRequired     = $agreement.Summary.ViewingRequired
                                Reacceptance        = $agreement.Summary.Reacceptance
                                Languages           = $agreement.Summary.Languages
                                Modified            = $agreement.Summary.Modified
                            }
                        }
                    }
                )
                $termsOfUseSummary = $externalTerms
            }
        } catch {
            Write-Warning -Message "Guests Summary - Failed to get Terms of Use. Error: $($_.Exception.Message)"
        }

        $crossTenantSummary = @()
        try {
            $crossTenant = Get-MyCrossTenantAccess
            if ($crossTenant -and $crossTenant.DefaultPolicy) {
                $crossTenantSummary = @(
                    [PSCustomObject]@{
                        InboundAllowed             = $crossTenant.DefaultPolicy.InboundAllowed
                        OutboundAllowed            = $crossTenant.DefaultPolicy.OutboundAllowed
                        B2BCollaborationUsers      = $crossTenant.DefaultPolicy.B2BCollaboration.UsersEnabled
                        B2BDirectConnectUsers      = $crossTenant.DefaultPolicy.B2BDirectConnect.UsersEnabled
                        InboundTrustMfaAccepted    = $crossTenant.DefaultPolicy.InboundTrust.IsMfaAccepted
                        CompliantDeviceAccepted    = $crossTenant.DefaultPolicy.InboundTrust.IsCompliantDeviceAccepted
                        HybridJoinedDeviceAccepted = $crossTenant.DefaultPolicy.InboundTrust.IsHybridAzureADJoinedDeviceAccepted
                    }
                )
            }
        } catch {
            Write-Warning -Message "Guests Summary - Failed to get cross-tenant access settings. Error: $($_.Exception.Message)"
        }

        $conditionalAccessSummary = @()
        try {
            $conditionalAccess = @(Get-MyConditionalAccess)
            if ($conditionalAccess.Count -gt 0) {
                $guestPolicies = @(
                    foreach ($policy in $conditionalAccess) {
                        if ($policy.IncludedUsersGuid -contains 'GuestsOrExternalUsers' -or $policy.UsersInclude -contains 'All guests') {
                            [PSCustomObject]@{
                                DisplayName       = $policy.DisplayName
                                State             = $policy.State
                                GrantControls     = $policy.GrantControls
                                TermsOfUse        = $policy.GrantControlsTermsOfUse
                                Applications      = $policy.Applications
                                UserActions       = $policy.UserActions
                            }
                        }
                    }
                )
                $conditionalAccessSummary = $guestPolicies
            }
        } catch {
            Write-Warning -Message "Guests Summary - Failed to get Conditional Access policies. Error: $($_.Exception.Message)"
        }

        [PSCustomObject]@{
            Overview              = $overview
            DomainDistribution    = $domainDistribution
            StateDistribution     = $stateDistribution
            SignInDistribution    = $signInDistribution
            SuccessfulSignInDistribution = $successfulSignInDistribution
            AccessDistribution    = $accessDistribution
            CreationTypeDistribution = $creationTypeDistribution
            PendingAccounts       = @($pendingAccounts)
            AcceptedAccounts      = @($acceptedAccounts)
            NeverSuccessfulAccounts = @($neverSuccessfulAccounts)
            StaleAccounts         = @($staleAccounts)
            RecentAccounts        = @($recentAccounts)
            PrivilegedAccounts    = @($privilegedAccounts)
            LicensedAccounts      = @($licensedAccounts)
            ReviewCandidates      = @($reviewCandidates)
            AuthenticationPolicy  = $authenticationSummary
            TermsOfUse            = $termsOfUseSummary
            CrossTenantAccess     = $crossTenantSummary
            ConditionalAccess     = $conditionalAccessSummary
        }
    }
    Variables  = @{

    }
    Solution   = {
        $guestSummary = $Script:Reporting['Guests']['Summary']
        $guestData = @($Script:Reporting['Guests']['Data'])
        $guestCount = $guestData.Count

        New-HTMLTabPanel {
            New-HTMLTab -Name "Overview ($guestCount)" {
                if ($guestSummary -and $guestSummary.Overview) {
                    $overview = $guestSummary.Overview[0]
                    New-HTMLSection -HeaderText 'Guest And External Identity Overview' -Density Compact {
                        New-HTMLSection -Invisible {
                            New-HTMLInfoCard -Title 'Total External Accounts' -Number $overview.TotalGuests -Subtitle 'All guest and external accounts in scope' -Icon '👥' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'Enabled / Disabled' -Number "$($overview.EnabledGuests) / $($overview.DisabledGuests)" -Subtitle 'Account state split' -Icon '✅' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'Pending / Accepted' -Number "$($overview.PendingAcceptance) / $($overview.AcceptedGuests)" -Subtitle 'Invitation lifecycle split' -Icon '📨' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'No Successful Sign-in' -Number $overview.NeverSuccessfulSignIn -Subtitle 'External accounts without recorded successful sign-in activity' -Icon '⏱️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        }
                        New-HTMLSection -Invisible {
                            New-HTMLInfoCard -Title 'Accounts With Roles' -Number $overview.GuestsWithRoles -Subtitle 'Privileged external identities' -Icon '🛡️' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'Accounts With Licenses' -Number $overview.GuestsWithLicenses -Subtitle 'Licensed external identities' -Icon '🎫' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'Successful 180+ Days' -Number $overview.StaleSuccessful180Days -Subtitle 'No recent successful sign-in recorded' -Icon '📉' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            New-HTMLInfoCard -Title 'Distinct Domains' -Number $overview.DistinctDomains -Subtitle 'Partner domains represented' -Icon '🌐' -IconColor '#0dcaf0' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                        }
                        New-HTMLSection -Invisible {
                            New-HTMLPanel {
                                New-HTMLChart -Title 'External Account State Distribution' {
                                    foreach ($item in $guestSummary.StateDistribution) {
                                        New-ChartPie -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLChart -Title 'External Successful Sign-in Recency' {
                                    foreach ($item in $guestSummary.SuccessfulSignInDistribution) {
                                        New-ChartPie -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                        }
                        New-HTMLSection -HeaderText 'Access Footprint' -Invisible {
                            New-HTMLPanel {
                                New-HTMLChart -Title 'External Access Indicators' {
                                    foreach ($item in $guestSummary.AccessDistribution) {
                                        New-ChartPie -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLChart -Title 'Creation Type Distribution' {
                                    foreach ($item in $guestSummary.CreationTypeDistribution) {
                                        New-ChartBar -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                        }
                        New-HTMLSection -HeaderText 'Sign-in Signals' -Invisible {
                            New-HTMLPanel {
                                New-HTMLChart -Title 'External Sign-in Recency' {
                                    foreach ($item in $guestSummary.SignInDistribution) {
                                        New-ChartPie -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLChart -Title 'Top External Domains' {
                                    foreach ($item in ($guestSummary.DomainDistribution | Select-Object -First 10)) {
                                        New-ChartBar -Name $item.Name -Value $item.Count
                                    }
                                }
                            }
                        }
                        if ($guestSummary.Overview) {
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $guestSummary.Overview -Filtering -ScrollX
                            }
                        }
                    } -Wrap wrap
                }
            }

            New-HTMLTab -Name 'Access Policies' {
                if ($guestSummary -and $guestSummary.AuthenticationPolicy) {
                    New-HTMLSection -HeaderText 'Guest Authentication Policy' {
                        New-HTMLTable -DataTable $guestSummary.AuthenticationPolicy -Filtering -ScrollX
                    }
                }
                if ($guestSummary -and $guestSummary.CrossTenantAccess) {
                    New-HTMLSection -HeaderText 'Cross-tenant Guest Defaults' {
                        New-HTMLTable -DataTable $guestSummary.CrossTenantAccess -Filtering -ScrollX
                    }
                }
                if ($guestSummary -and $guestSummary.TermsOfUse) {
                    New-HTMLSection -HeaderText 'External Terms Of Use' {
                        New-HTMLTable -DataTable $guestSummary.TermsOfUse -Filtering -ScrollX
                    }
                }
                if ($guestSummary -and $guestSummary.ConditionalAccess) {
                    New-HTMLSection -HeaderText 'Guest-targeted Conditional Access' {
                        New-HTMLTable -DataTable $guestSummary.ConditionalAccess -Filtering -ScrollX
                    }
                }
            }

            New-HTMLTab -Name "External Accounts ($guestCount)" {
                if ($guestData) {
                    $guestTableConditions = {
                        New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon
                        New-HTMLTableCondition -Name 'Enabled' -Operator eq -Value $true -ComparisonType string -BackgroundColor SpringGreen

                        New-HTMLTableCondition -Name 'ExternalUserState' -Operator eq -Value 'PendingAcceptance' -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'ExternalUserState', 'ExternalUserStateChangeDateTime', 'ExternalUserStateChangeDaysAgo'
                        New-HTMLTableCondition -Name 'ExternalUserState' -Operator eq -Value 'Accepted' -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'ExternalUserState', 'ExternalUserStateChangeDateTime', 'ExternalUserStateChangeDaysAgo'
                        New-HTMLTableCondition -Name 'ExternalUserState' -Operator eq -Value '' -ComparisonType string -BackgroundColor OldGold -HighlightHeaders 'ExternalUserState'

                        New-HTMLTableCondition -Name 'NeverSignedIn' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'NeverSignedIn', 'LastSignInDateTime', 'LastNonInteractiveSignInDateTime'
                        New-HTMLTableCondition -Name 'NeverSuccessfullySignedIn' -Operator eq -Value $true -ComparisonType string -BackgroundColor CoralRed -HighlightHeaders 'NeverSuccessfullySignedIn', 'LastSuccessfulSignInDateTime'
                        New-HTMLTableCondition -Name 'SignInPattern' -Operator eq -Value 'Non-interactive only' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'SignInPattern', 'LastNonInteractiveSignInDateTime'
                        New-HTMLTableCondition -Name 'SignInPattern' -Operator eq -Value 'Interactive only' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'SignInPattern', 'LastSignInDateTime'
                        New-HTMLTableCondition -Name 'SignInPattern' -Operator eq -Value 'Interactive + non-interactive' -ComparisonType string -BackgroundColor MediumSpringGreen -HighlightHeaders 'SignInPattern'
                        New-HTMLTableCondition -Name 'HasRoles' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'HasRoles', 'RoleCount', 'Roles'
                        New-HTMLTableCondition -Name 'HasLicenses' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'HasLicenses', 'LicenseCount', 'Licenses'

                        New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSignInDaysAgo' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSignInDaysAgo', 'LastSignInDateTime'

                        New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                        New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                        New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'
                        New-HTMLTableCondition -Name 'LastNonInteractiveSignInDaysAgo' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastNonInteractiveSignInDaysAgo', 'LastNonInteractiveSignInDateTime'

                        New-HTMLTableCondition -Name 'LastSuccessfulSignInDaysAgo' -Value 180 -Operator gt -ComparisonType number -BackgroundColor CoralRed -HighlightHeaders 'LastSuccessfulSignInDaysAgo', 'LastSuccessfulSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSuccessfulSignInDaysAgo' -Value 180 -Operator le -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'LastSuccessfulSignInDaysAgo', 'LastSuccessfulSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSuccessfulSignInDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'LastSuccessfulSignInDaysAgo', 'LastSuccessfulSignInDateTime'
                        New-HTMLTableCondition -Name 'LastSuccessfulSignInDaysAgo' -Value 30 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'LastSuccessfulSignInDaysAgo', 'LastSuccessfulSignInDateTime'

                        New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Direct' -ComparisonType string -BackgroundColor LightSkyBlue
                        New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Group' -ComparisonType string -BackgroundColor LightGreen
                        New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Duplicate' -ComparisonType string -BackgroundColor PeachOrange
                        New-HTMLTableCondition -Name 'LicensesStatus' -Operator contains -Value 'Error' -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'LicensesStatus', 'LicensesErrors'
                        New-HTMLTableCondition -Name 'LicensesStatus' -Operator eq -Value '' -ComparisonType string -BackgroundColor OldGold

                        New-HTMLTableCondition -Name 'CreatedDaysAgo' -Value 365 -Operator gt -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'CreatedDaysAgo', 'CreatedDateTime'
                        New-HTMLTableCondition -Name 'CreatedDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'CreatedDaysAgo', 'CreatedDateTime'
                    }

                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Accounts ($guestCount)" {
                            New-HTMLSection -HeaderText 'All External Accounts' {
                                New-HTMLTable -DataTable $guestData -Filtering $guestTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Pending Invitations ($(@($guestSummary.PendingAccounts).Count))" {
                            if (@($guestSummary.PendingAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Pending External Invitations' {
                                    New-HTMLTable -DataTable $guestSummary.PendingAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Pending External Invitations' {
                                    New-HTMLText -Text 'No pending external invitations found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Accepted Accounts ($(@($guestSummary.AcceptedAccounts).Count))" {
                            if (@($guestSummary.AcceptedAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Accepted External Accounts' {
                                    New-HTMLTable -DataTable $guestSummary.AcceptedAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Accepted External Accounts' {
                                    New-HTMLText -Text 'No accepted external accounts found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "No Successful Sign-in ($(@($guestSummary.NeverSuccessfulAccounts).Count))" {
                            if (@($guestSummary.NeverSuccessfulAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'External Accounts Without Successful Sign-in' {
                                    New-HTMLTable -DataTable $guestSummary.NeverSuccessfulAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'External Accounts Without Successful Sign-in' {
                                    New-HTMLText -Text 'All guest or external accounts have a recorded successful sign-in.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Recent Successful ($(@($guestSummary.RecentAccounts).Count))" {
                            if (@($guestSummary.RecentAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Recently Active External Accounts' {
                                    New-HTMLTable -DataTable $guestSummary.RecentAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Recently Active External Accounts' {
                                    New-HTMLText -Text 'No external accounts have a successful sign-in within the last 30 days.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Stale Successful ($(@($guestSummary.StaleAccounts).Count))" {
                            if (@($guestSummary.StaleAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Stale External Accounts' {
                                    New-HTMLTable -DataTable $guestSummary.StaleAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Stale External Accounts' {
                                    New-HTMLText -Text 'No external accounts are currently stale based on successful sign-in activity.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Privileged ($(@($guestSummary.PrivilegedAccounts).Count))" {
                            if (@($guestSummary.PrivilegedAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Privileged External Accounts' {
                                    New-HTMLTable -DataTable $guestSummary.PrivilegedAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Privileged External Accounts' {
                                    New-HTMLText -Text 'No guest or external accounts currently hold directory roles.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Licensed ($(@($guestSummary.LicensedAccounts).Count))" {
                            if (@($guestSummary.LicensedAccounts).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Licensed External Accounts' {
                                    New-HTMLTable -DataTable $guestSummary.LicensedAccounts -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Licensed External Accounts' {
                                    New-HTMLText -Text 'No guest or external accounts currently have licenses assigned.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($guestSummary.ReviewCandidates).Count))" {
                            if (@($guestSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'External Accounts Requiring Review' {
                                    New-HTMLTable -DataTable $guestSummary.ReviewCandidates -Filtering $guestTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'External Accounts Requiring Review' {
                                    New-HTMLText -Text 'No external accounts matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Domains ($(@($guestSummary.DomainDistribution).Count))" {
                            if (@($guestSummary.DomainDistribution).Count -gt 0) {
                                New-HTMLSection -HeaderText 'External Domains' {
                                    New-HTMLTable -DataTable $guestSummary.DomainDistribution -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'External Domains' {
                                    New-HTMLText -Text 'No external domains were detected in the current guest dataset.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
