BeforeAll {
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

    function Get-MgGroupOwner {
        param(
            [string] $GroupId,
            [switch] $All,
            $ErrorAction
        )
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

        Mock Get-MgGroupOwner {
            [PSCustomObject] @{
                DisplayName       = 'Team Owner'
                Mail              = 'owner@contoso.com'
                UserPrincipalName = 'owner@contoso.com'
                Id                = 'owner-1'
            }
        }
    }

    It 'requests team summary and automatically pages owners through the group relationship' {
        $result = Get-MyTeam

        $script:TeamDetailsParameters.Property | Should -Contain 'Summary'
        $script:TeamDetailsParameters.ExpandProperty | Should -BeNullOrEmpty
        Should -Invoke Get-MgGroupOwner -Times 1 -Exactly -ParameterFilter {
            $GroupId -eq 'team-1' -and $All
        }
        $result.MembersCount | Should -Be 8
        $result.GuestsCount | Should -Be 2
        $result.HasGuests | Should -BeTrue
        $result.OwnerCount | Should -Be 1
        $result.OwnerUserPrincipalName | Should -Be 'owner@contoso.com'
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

    It 'keeps the team and reports owner state as unknown when owner retrieval fails' {
        Mock Get-MgGroupOwner { throw 'owners unavailable' }

        $result = Get-MyTeam -WarningAction SilentlyContinue

        $result.Team | Should -Be 'Operations'
        $result.OwnerCount | Should -BeNullOrEmpty
        $result.HasOwners | Should -BeNullOrEmpty
        $result.MembersCount | Should -Be 8
    }

    It 'counts non-user group owners returned through the uncast owner relationship' {
        Mock Get-MgGroupOwner {
            [PSCustomObject] @{
                AdditionalProperties = @{
                    '@odata.type' = '#microsoft.graph.servicePrincipal'
                    displayName   = 'Automation owner'
                }
                Id                   = 'service-principal-1'
            }
        }

        $result = Get-MyTeam

        $result.OwnerCount | Should -Be 1
        $result.HasOwners | Should -BeTrue
        $result.OwnerDisplayName | Should -Be 'Automation owner'
        $result.OwnerId | Should -Be 'service-principal-1'
    }

    It 'keeps a team in the unavailable-owner bucket when per-owner retrieval fails' {
        Mock Get-MgGroupOwner { throw 'owners unavailable' }

        $result = Get-MyTeam -PerOwner -WarningAction SilentlyContinue

        $result.Keys | Should -Contain '[Owner state unavailable]'
        $result['[Owner state unavailable]'][0].Team | Should -Be 'Operations'
        $result['[Owner state unavailable]'][0].HasOwners | Should -BeNullOrEmpty
    }

    It 'keeps a genuinely ownerless team in a distinct per-owner bucket' {
        Mock Get-MgGroupOwner { @() }

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
