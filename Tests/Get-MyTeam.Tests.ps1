BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsGroupOwner.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyTeam.ps1')

    function Get-MgTeam {
        param(
            [switch] $All,
            [string] $TeamId,
            [string[]] $Property,
            [string[]] $ExpandProperty,
            $ErrorAction
        )
    }

    function Invoke-MgGraphRequest {
        param([string] $Method, [string] $Uri, [string] $OutputType, $ErrorAction)
    }

}

Describe 'Get-MyTeam' {
    BeforeEach {
        $script:TeamDetailsParameters = $null

        Mock Get-MgTeam {
            if ($All) {
                [PSCustomObject] @{
                    Id          = 'team-1'
                    DisplayName = 'Operations'
                    Description = 'Operations team'
                    Visibility  = 'Private'
                }
            } else {
                $script:TeamDetailsParameters = [PSCustomObject] @{
                    Property       = @($Property)
                    ExpandProperty = @($ExpandProperty)
                }
                [PSCustomObject] @{
                    CreatedDateTime = (Get-Date).AddDays(-5)
                    GuestSettings   = [PSCustomObject] @{
                        AllowCreateUpdateChannels = $false
                        AllowDeleteChannels       = $false
                    }
                    MemberSettings  = [PSCustomObject] @{
                        AllowAddRemoveApps                = $true
                        AllowCreatePrivateChannels        = $true
                        AllowCreateUpdateChannels         = $true
                        AllowCreateUpdateRemoveConnectors = $true
                        AllowCreateUpdateRemoveTabs       = $true
                        AllowDeleteChannels               = $true
                    }
                    Summary         = [PSCustomObject] @{
                        MembersCount = 8
                        GuestsCount  = 2
                    }
                }
            }
        }

        Mock Get-GraphEssentialsGroupOwner {
            [PSCustomObject] @{
                DisplayName       = 'Team Owner'
                Mail              = 'owner@contoso.com'
                UserPrincipalName = 'owner@contoso.com'
                Id                = 'owner-1'
                ObjectType        = '#microsoft.graph.user'
            }
        }
    }

    It 'requests team summary and automatically pages owners through the group relationship' {
        $result = Get-MyTeam

        $script:TeamDetailsParameters.Property | Should -Contain 'Summary'
        $script:TeamDetailsParameters.ExpandProperty | Should -BeNullOrEmpty
        Should -Invoke Get-GraphEssentialsGroupOwner -Times 1 -Exactly -ParameterFilter {
            $GroupId -eq 'team-1'
        }
        $result.MembersCount | Should -Be 8
        $result.GuestsCount | Should -Be 2
        $result.HasGuests | Should -BeTrue
        $result.OwnerCount | Should -Be 1
        $result.Owners.Count | Should -Be 1
        $result.Owners[0].Id | Should -Be 'owner-1'
        $result.OwnerUserPrincipalName | Should -Be 'owner@contoso.com'
        $result.OwnerObjectType | Should -Be '#microsoft.graph.user'
    }

    It 'keeps the team when extended team details fail' {
        Mock Get-MgTeam {
            if ($All) {
                [PSCustomObject] @{
                    Id          = 'team-1'
                    DisplayName = 'Operations'
                    Description = 'Operations team'
                    Visibility  = 'Private'
                }
            } else {
                throw 'details unavailable'
            }
        }

        $result = Get-MyTeam -WarningAction SilentlyContinue

        $result.Team | Should -Be 'Operations'
        $result.OwnerCount | Should -Be 1
        $result.MembersCount | Should -BeNullOrEmpty
        $result.HasGuests | Should -BeNullOrEmpty
    }

    It 'stops when extended team details fail and complete data is required' {
        Mock Get-MgTeam {
            if ($All) {
                [PSCustomObject] @{
                    Id          = 'team-1'
                    DisplayName = 'Operations'
                    Description = 'Operations team'
                    Visibility  = 'Private'
                }
            } else {
                throw 'details unavailable'
            }
        }

        { Get-MyTeam -RequireCompleteData } | Should -Throw '*details unavailable*'
    }

    It 'does not emit earlier team rows when a later team fails in complete-data mode' {
        Mock Get-MgTeam {
            if ($All) {
                @(
                    [PSCustomObject] @{ Id = 'team-1'; DisplayName = 'Operations'; Visibility = 'Private' }
                    [PSCustomObject] @{ Id = 'team-2'; DisplayName = 'Broken'; Visibility = 'Private' }
                )
            } elseif ($TeamId -eq 'team-2') {
                throw 'second team details unavailable'
            } else {
                [PSCustomObject] @{
                    CreatedDateTime = (Get-Date).AddDays(-5)
                    GuestSettings   = [PSCustomObject] @{}
                    MemberSettings  = [PSCustomObject] @{}
                    Summary         = [PSCustomObject] @{ MembersCount = 8; GuestsCount = 0 }
                }
            }
        }

        $script:RowsObserved = 0
        try {
            Get-MyTeam -RequireCompleteData | ForEach-Object { $script:RowsObserved++ }
        } catch {
            $_.Exception.Message | Should -BeLike '*second team details unavailable*'
        }

        $script:RowsObserved | Should -Be 0
    }

    It 'keeps the team and reports owner state as unknown when owner retrieval fails' {
        Mock Get-GraphEssentialsGroupOwner { throw 'owners unavailable' }

        $result = Get-MyTeam -WarningAction SilentlyContinue

        $result.Team | Should -Be 'Operations'
        $result.OwnerCount | Should -BeNullOrEmpty
        $result.HasOwners | Should -BeNullOrEmpty
        $result.MembersCount | Should -Be 8
    }

    It 'stops when owner retrieval fails and complete data is required' {
        Mock Get-GraphEssentialsGroupOwner { throw 'owners unavailable' }

        { Get-MyTeam -RequireCompleteData } | Should -Throw '*owners unavailable*'
    }

    It 'counts non-user group owners returned through the beta owner projection' {
        Mock Get-GraphEssentialsGroupOwner {
            [PSCustomObject] @{
                DisplayName = 'Automation owner'
                Id          = 'service-principal-1'
                ObjectType  = '#microsoft.graph.servicePrincipal'
            }
        }

        $result = Get-MyTeam

        $result.OwnerCount | Should -Be 1
        $result.HasOwners | Should -BeTrue
        $result.OwnerDisplayName | Should -Be 'Automation owner'
        $result.OwnerId | Should -Be 'service-principal-1'
        $result.OwnerObjectType | Should -Be '#microsoft.graph.servicePrincipal'
        $result.Owners[0].Id | Should -Be 'service-principal-1'
    }

    It 'keeps a team in the unavailable-owner bucket when per-owner retrieval fails' {
        Mock Get-GraphEssentialsGroupOwner { throw 'owners unavailable' }

        $result = Get-MyTeam -PerOwner -WarningAction SilentlyContinue

        $result.Keys | Should -Contain '[Owner state unavailable]'
        $result['[Owner state unavailable]'][0].Team | Should -Be 'Operations'
        $result['[Owner state unavailable]'][0].HasOwners | Should -BeNullOrEmpty
    }

    It 'keeps a genuinely ownerless team in a distinct per-owner bucket' {
        Mock Get-GraphEssentialsGroupOwner { @() }

        $result = Get-MyTeam -PerOwner

        $result.Keys | Should -Contain '[No owner]'
        $result['[No owner]'][0].HasOwners | Should -BeFalse
    }

    It 'does not coerce missing visibility and guest fields to false' {
        Mock Get-MgTeam {
            if ($All) {
                [PSCustomObject] @{
                    Id          = 'team-1'
                    DisplayName = 'Operations'
                    Description = 'Operations team'
                    Visibility  = $null
                }
            } else {
                [PSCustomObject] @{
                    GuestSettings = [PSCustomObject] @{
                        AllowCreateUpdateChannels = $null
                        AllowDeleteChannels       = $false
                    }
                    Summary       = [PSCustomObject] @{ GuestsCount = $null }
                }
            }
        }

        $result = Get-MyTeam

        $result.IsPublic | Should -BeNullOrEmpty
        $result.IsPrivate | Should -BeNullOrEmpty
        $result.HasGuests | Should -BeNullOrEmpty
        $result.GuestControlsEnabled | Should -BeNullOrEmpty
    }

    It 'organizes teams by the owner user principal name' {
        $result = Get-MyTeam -PerOwner

        $result.Keys | Should -Contain 'owner@contoso.com'
        $result['owner@contoso.com'].Count | Should -Be 1
        $result['owner@contoso.com'][0].Team | Should -Be 'Operations'
    }

    It 'stops when the team list fails and complete data is required' {
        Mock Get-MgTeam { throw 'team list unavailable' }

        { Get-MyTeam -RequireCompleteData } | Should -Throw '*team list unavailable*'
    }

    It 'turns a team-list permission failure into a terminating collection error' {
        Mock Get-MgTeam { throw [System.UnauthorizedAccessException]::new('Team.ReadBasic.All is missing') }

        try {
            Get-MyTeam -RequireCompleteData
            throw 'Expected Get-MyTeam to terminate.'
        } catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'GetMyTeamListFailed*'
            $_.CategoryInfo.Category | Should -Be 'ResourceUnavailable'
            $_.Exception.Message | Should -BeLike '*Team.ReadBasic.All is missing*'
        }
    }

    It 'preserves the compatibility warning when the team list fails by default' {
        Mock Get-MgTeam { throw 'team list unavailable' }

        $warnings = @()
        $result = Get-MyTeam -WarningVariable warnings -WarningAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        @($warnings).Count | Should -Be 1
        [string] $warnings[0] | Should -BeLike '*team list unavailable*'
    }
}

Describe 'Get-GraphEssentialsGroupOwner' {
    BeforeEach {
        $script:OwnerRequest = 0
        Mock Invoke-MgGraphRequest {
            $script:OwnerRequest++
            if ($script:OwnerRequest -eq 1) {
                [PSCustomObject] @{
                    value             = @([PSCustomObject] @{
                            '@odata.type'     = '#microsoft.graph.user'
                            displayName       = 'Team Owner'
                            id                = 'owner-1'
                            mail              = 'owner@contoso.com'
                            userPrincipalName = 'owner@contoso.com'
                        })
                    '@odata.nextLink' = 'https://graph.microsoft.com/beta/groups/team-1/owners?$skiptoken=next'
                }
            } else {
                [PSCustomObject] @{
                    value = @([PSCustomObject] @{
                            '@odata.type' = '#microsoft.graph.servicePrincipal'
                            displayName   = 'Automation owner'
                            id            = 'service-principal-1'
                        })
                }
            }
        }
    }

    It 'pages the beta relationship and retains user and service-principal owners' {
        $result = @(Get-GraphEssentialsGroupOwner -GroupId 'team-1')

        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq '/beta/groups/team-1/owners' -and
            $OutputType -eq 'PSObject'
        }
        $result.Count | Should -Be 2
        $result[0].UserPrincipalName | Should -Be 'owner@contoso.com'
        $result[1].ObjectType | Should -Be '#microsoft.graph.servicePrincipal'
        $result[1].Id | Should -Be 'service-principal-1'
    }
}

Describe 'Teams report unknown-state summary' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\Private\Configuration.Teams.ps1')
    }

    It 'separates unavailable owner and guest state from explicit false values' {
        $Script:Reporting = @{
            Teams = @{
                Data = @(
                    [PSCustomObject] @{
                        HasGuests              = $false
                        HasOwners              = $false
                        HasMultipleOwners      = $false
                        OwnerCount             = 0
                        Visibility             = 'Private'
                        IsPrivate              = $true
                        IsPublic               = $false
                        OwnerUserPrincipalName = $null
                    }
                    [PSCustomObject] @{
                        HasGuests              = $null
                        HasOwners              = $null
                        HasMultipleOwners      = $null
                        OwnerCount             = $null
                        Visibility             = $null
                        IsPrivate              = $null
                        IsPublic               = $null
                        OwnerUserPrincipalName = $null
                    }
                )
            }
        }

        $result = & $Script:Teams.Summary

        $result.Overview[0].OwnerlessTeams | Should -Be 1
        $result.Overview[0].OwnerStateUnavailable | Should -Be 1
        $result.Overview[0].TeamsWithoutGuests | Should -Be 1
        $result.Overview[0].GuestStateUnavailable | Should -Be 1
        @($result.OwnerlessTeams).Count | Should -Be 1
        @($result.ReviewCandidates | Where-Object ReviewFlags -eq 'No owners').Count | Should -Be 1
        @($result.ReviewCandidates | Where-Object ReviewFlags -eq 'Owner state unavailable').Count | Should -Be 1
    }
}
