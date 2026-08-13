$Script:Teams = [ordered] @{
    Name       = 'Microsoft Teams Report'
    Enabled    = $true
    Execute    = {
        Get-MyTeam
    }
    Processing = {

    }
    Summary    = {
        $teamData = @($Script:Reporting['Teams']['Data'])
        $totalTeams = $teamData.Count
        $publicTeams = 0
        $privateTeams = 0
        $teamsWithGuests = 0
        $teamsWithoutGuests = 0
        $guestStateUnavailable = 0
        $ownerlessTeams = 0
        $ownerStateUnavailable = 0
        $multiOwnerTeams = 0
        $guestControlsEnabled = 0
        $guestDeleteEnabled = 0
        $privateChannelsEnabled = 0
        $appsEnabled = 0
        $connectorsEnabled = 0
        $tabsEnabled = 0
        $visibilityCounts = @{}
        $ownerCounts = @{}
        $teamsWithGuestsList = [System.Collections.Generic.List[object]]::new()
        $publicTeamsList = [System.Collections.Generic.List[object]]::new()
        $ownerlessTeamsList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($team in $teamData) {
            $visibility = if ($team.Visibility) { $team.Visibility } else { 'Unknown' }
            if (-not $visibilityCounts.ContainsKey($visibility)) {
                $visibilityCounts[$visibility] = 0
            }
            $visibilityCounts[$visibility]++

            if ($team.IsPublic) {
                $publicTeams++
                $publicTeamsList.Add($team)
            } elseif ($team.IsPrivate) {
                $privateTeams++
            }

            if ($team.HasGuests -eq $true) {
                $teamsWithGuests++
                $teamsWithGuestsList.Add($team)
            } elseif ($team.HasGuests -eq $false) {
                $teamsWithoutGuests++
            } else {
                $guestStateUnavailable++
            }

            if ($team.HasOwners -eq $false) {
                $ownerlessTeams++
                $ownerlessTeamsList.Add($team)
            } elseif ($null -eq $team.HasOwners) {
                $ownerStateUnavailable++
            }

            if ($team.HasMultipleOwners) {
                $multiOwnerTeams++
            }

            if ($team.GuestControlsEnabled) {
                $guestControlsEnabled++
            }
            if ($team.GuestAllowDeleteChannels) {
                $guestDeleteEnabled++
            }
            if ($team.AllowCreatePrivateChannels) {
                $privateChannelsEnabled++
            }
            if ($team.AllowAddRemoveApps) {
                $appsEnabled++
            }
            if ($team.AllowCreateUpdateRemoveConnectors) {
                $connectorsEnabled++
            }
            if ($team.AllowCreateUpdateRemoveTabs) {
                $tabsEnabled++
            }

            $ownerUpns = @()
            if ($team.OwnerUserPrincipalName -is [System.Array]) {
                $ownerUpns = @($team.OwnerUserPrincipalName)
            } elseif ($team.OwnerUserPrincipalName) {
                $ownerUpns = @($team.OwnerUserPrincipalName)
            }
            foreach ($ownerUpn in $ownerUpns) {
                if (-not $ownerCounts.ContainsKey($ownerUpn)) {
                    $ownerCounts[$ownerUpn] = 0
                }
                $ownerCounts[$ownerUpn]++
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($team.HasOwners -eq $false) {
                $reviewFlags.Add('No owners')
            } elseif ($null -eq $team.HasOwners) {
                $reviewFlags.Add('Owner state unavailable')
            }
            if ($team.IsPublic) {
                $reviewFlags.Add('Public team')
            }
            if ($team.HasGuests) {
                $reviewFlags.Add('Guests present')
            }
            if ($team.GuestAllowCreateUpdateChannels) {
                $reviewFlags.Add('Guests can update channels')
            }
            if ($team.GuestAllowDeleteChannels) {
                $reviewFlags.Add('Guests can delete channels')
            }
            if ($team.AllowCreatePrivateChannels) {
                $reviewFlags.Add('Private channels enabled')
            }
            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($team | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalTeams             = $totalTeams
                PublicTeams            = $publicTeams
                PrivateTeams           = $privateTeams
                TeamsWithGuests        = $teamsWithGuests
                TeamsWithoutGuests     = $teamsWithoutGuests
                GuestStateUnavailable  = $guestStateUnavailable
                OwnerlessTeams         = $ownerlessTeams
                OwnerStateUnavailable  = $ownerStateUnavailable
                MultiOwnerTeams        = $multiOwnerTeams
                GuestControlsEnabled   = $guestControlsEnabled
                GuestDeleteEnabled     = $guestDeleteEnabled
                PrivateChannelsEnabled = $privateChannelsEnabled
                AppsEnabled            = $appsEnabled
                ConnectorsEnabled      = $connectorsEnabled
                TabsEnabled            = $tabsEnabled
            }
        )

        $visibilityDistribution = @(
            foreach ($key in $visibilityCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $visibilityCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $guestDistribution = @(
            [PSCustomObject]@{ Name = 'Teams with guests'; Count = $teamsWithGuests }
            [PSCustomObject]@{ Name = 'Teams without guests'; Count = $teamsWithoutGuests }
            [PSCustomObject]@{ Name = 'Guest state unavailable'; Count = $guestStateUnavailable }
            [PSCustomObject]@{ Name = 'Guest controls enabled'; Count = $guestControlsEnabled }
            [PSCustomObject]@{ Name = 'Guest delete enabled'; Count = $guestDeleteEnabled }
        )

        $ownershipDistribution = @(
            [PSCustomObject]@{ Name = 'Ownerless'; Count = $ownerlessTeams }
            [PSCustomObject]@{ Name = 'Single owner'; Count = @($teamData.Where({ $_.OwnerCount -eq 1 })).Count }
            [PSCustomObject]@{ Name = 'Multiple owners'; Count = $multiOwnerTeams }
            [PSCustomObject]@{ Name = 'Owner state unavailable'; Count = $ownerStateUnavailable }
        )

        $collaborationDistribution = @(
            [PSCustomObject]@{ Name = 'Private channels'; Count = $privateChannelsEnabled }
            [PSCustomObject]@{ Name = 'Apps'; Count = $appsEnabled }
            [PSCustomObject]@{ Name = 'Connectors'; Count = $connectorsEnabled }
            [PSCustomObject]@{ Name = 'Tabs'; Count = $tabsEnabled }
        )

        $ownerDistribution = @(
            foreach ($key in $ownerCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $ownerCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        [PSCustomObject]@{
            Overview                  = $overview
            VisibilityDistribution    = $visibilityDistribution
            GuestDistribution         = $guestDistribution
            OwnershipDistribution     = $ownershipDistribution
            CollaborationDistribution = $collaborationDistribution
            OwnerDistribution         = $ownerDistribution
            TeamsWithGuests           = @($teamsWithGuestsList)
            PublicTeams               = @($publicTeamsList)
            OwnerlessTeams            = @($ownerlessTeamsList)
            ReviewCandidates          = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $teamSummary = $Script:Reporting['Teams']['Summary']
        $teamData = @($Script:Reporting['Teams']['Data'])
        $teamCount = $teamData.Count

        if ($teamData) {
            $teamTableConditions = {
                New-HTMLTableCondition -Name 'Visibility' -Operator eq -Value 'Public' -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'Visibility'
                New-HTMLTableCondition -Name 'Visibility' -Operator eq -Value 'Private' -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'Visibility'

                New-HTMLTableCondition -Name 'HasOwners' -Operator eq -Value $false -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'HasOwners', 'OwnerCount', 'OwnerDisplayName', 'OwnerUserPrincipalName'
                New-HTMLTableCondition -Name 'HasMultipleOwners' -Operator eq -Value $true -ComparisonType string -BackgroundColor LaserLemon -HighlightHeaders 'HasMultipleOwners', 'OwnerCount', 'OwnerDisplayName'

                New-HTMLTableCondition -Name 'HasGuests' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'HasGuests', 'GuestsCount'
                New-HTMLTableCondition -Name 'GuestAllowCreateUpdateChannels' -Operator eq -Value $true -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'GuestAllowCreateUpdateChannels'
                New-HTMLTableCondition -Name 'GuestAllowDeleteChannels' -Operator eq -Value $true -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'GuestAllowDeleteChannels'

                New-HTMLTableCondition -Name 'AllowCreatePrivateChannels' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightSkyBlue -HighlightHeaders 'AllowCreatePrivateChannels'
                New-HTMLTableCondition -Name 'AllowAddRemoveApps' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'AllowAddRemoveApps'
                New-HTMLTableCondition -Name 'AllowCreateUpdateRemoveConnectors' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'AllowCreateUpdateRemoveConnectors'
                New-HTMLTableCondition -Name 'AllowCreateUpdateRemoveTabs' -Operator eq -Value $true -ComparisonType string -BackgroundColor LightGreen -HighlightHeaders 'AllowCreateUpdateRemoveTabs'

                New-HTMLTableCondition -Name 'CreatedDaysAgo' -Value 365 -Operator gt -ComparisonType number -BackgroundColor SunsetOrange -HighlightHeaders 'CreatedDaysAgo', 'CreatedDateTime'
                New-HTMLTableCondition -Name 'CreatedDaysAgo' -Value 90 -Operator le -ComparisonType number -BackgroundColor MediumSpringGreen -HighlightHeaders 'CreatedDaysAgo', 'CreatedDateTime'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($teamCount)" {
                    if ($teamSummary -and $teamSummary.Overview) {
                        $overview = $teamSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Teams Collaboration Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Teams' -Number $overview.TotalTeams -Subtitle 'All Teams in scope' -Icon '💬' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Public / Private' -Number "$($overview.PublicTeams) / $($overview.PrivateTeams)" -Subtitle 'Visibility split' -Icon '👁️' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Teams With Guests' -Number $overview.TeamsWithGuests -Subtitle 'Teams hosting guest members' -Icon '🤝' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Ownerless / Multi-owner' -Number "$($overview.OwnerlessTeams) / $($overview.MultiOwnerTeams)" -Subtitle 'Ownership review split' -Icon '🧭' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Guest Controls Enabled' -Number $overview.GuestControlsEnabled -Subtitle 'Guests can modify channels' -Icon '🚪' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Guest Delete Enabled' -Number $overview.GuestDeleteEnabled -Subtitle 'Guests can delete channels' -Icon '🗑️' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Private Channels Enabled' -Number $overview.PrivateChannelsEnabled -Subtitle 'Members can create private channels' -Icon '🔒' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Apps / Connectors / Tabs' -Number "$($overview.AppsEnabled) / $($overview.ConnectorsEnabled) / $($overview.TabsEnabled)" -Subtitle 'Member collaboration controls' -Icon '🧩' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Teams by Visibility' {
                                        foreach ($item in $teamSummary.VisibilityDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Guest Presence And Guest Controls' {
                                        foreach ($item in $teamSummary.GuestDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Ownership And Collaboration' -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Ownership Model' {
                                        foreach ($item in $teamSummary.OwnershipDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Collaboration Controls' {
                                        foreach ($item in $teamSummary.CollaborationDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($teamSummary.OwnerDistribution).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Top Team Owners' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Teams Per Owner' {
                                            foreach ($item in ($teamSummary.OwnerDistribution | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.Name -Value $item.Count
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $teamSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }

                New-HTMLTab -Name "Teams ($teamCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Teams ($teamCount)" {
                            New-HTMLSection -HeaderText 'All Teams' {
                                New-HTMLTable -DataTable $teamData -Filtering $teamTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Teams With Guests ($(@($teamSummary.TeamsWithGuests).Count))" {
                            if (@($teamSummary.TeamsWithGuests).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Teams With Guests' {
                                    New-HTMLTable -DataTable $teamSummary.TeamsWithGuests -Filtering $teamTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Teams With Guests' {
                                    New-HTMLText -Text 'No Teams with guests were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Public Teams ($(@($teamSummary.PublicTeams).Count))" {
                            if (@($teamSummary.PublicTeams).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Public Teams' {
                                    New-HTMLTable -DataTable $teamSummary.PublicTeams -Filtering $teamTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Public Teams' {
                                    New-HTMLText -Text 'No public Teams were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Ownerless ($(@($teamSummary.OwnerlessTeams).Count))" {
                            if (@($teamSummary.OwnerlessTeams).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Ownerless Teams' {
                                    New-HTMLTable -DataTable $teamSummary.OwnerlessTeams -Filtering $teamTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Ownerless Teams' {
                                    New-HTMLText -Text 'No ownerless Teams were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($teamSummary.ReviewCandidates).Count))" {
                            if (@($teamSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Teams Requiring Review' {
                                    New-HTMLTable -DataTable $teamSummary.ReviewCandidates -Filtering $teamTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Teams Requiring Review' {
                                    New-HTMLText -Text 'No Teams matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
