BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsErrorDetails.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsUsers.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyGuest.ps1')

    function Get-MyLicense {}
    function Get-MyUserRolesAndLicensesLookup {}
    function Get-MgUser {
        param(
            [switch] $All,
            [string] $Filter,
            [string[]] $Property
        )
    }
    function Stop-TimeLog {}
}

Describe 'Get-MyGuest' {
    BeforeEach {
        Mock Get-MyLicense {
            @{
                Licenses     = @{}
                ServicePlans = @{}
            }
        }

        Mock Get-MyUserRolesAndLicensesLookup {
            @{
                Roles = @{}
            }
        }

        Mock Get-MgUser {
            @(
                [PSCustomObject] @{
                    DisplayName                     = 'Guest One'
                    Id                              = 'guest-1'
                    UserPrincipalName               = 'guest.one#EXT#@contoso.onmicrosoft.com'
                    Mail                            = 'guest.one@example.com'
                    OtherMails                      = @()
                    UserType                        = 'Guest'
                    AccountEnabled                  = $true
                    CreatedDateTime                 = (Get-Date).AddDays(-30)
                    ExternalUserState               = 'Accepted'
                    ExternalUserStateChangeDateTime = (Get-Date).AddDays(-29)
                    SignInActivity                  = [PSCustomObject] @{
                        LastSignInDateTime               = $null
                        LastNonInteractiveSignInDateTime = $null
                        LastSuccessfulSignInDateTime     = (Get-Date).AddDays(-3)
                    }
                    CreationType                    = 'Invitation'
                    CompanyName                     = 'Example'
                    OnPremisesSyncEnabled           = $null
                    LicenseAssignmentStates         = @()
                    AssignedPlans                   = @()
                }
            )
        }

        Mock Stop-TimeLog { '0s' }
    }

    It 'does not mark successful-only guests as never signed in' {
        $guests = @(Get-MyGuest -IncludeSignInActivity)

        $guests.Count | Should -Be 1
        $guests[0].SignInPattern | Should -Be 'Successful sign-in only'
        $guests[0].NeverSignedIn | Should -BeFalse
        $guests[0].NeverSuccessfullySignedIn | Should -BeFalse
    }

    It 'does not request sign-in activity by default' {
        $guests = @(Get-MyGuest)

        $guests[0].SignInActivityRequested | Should -BeFalse
        $guests[0].SignInActivityAvailable | Should -BeFalse
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $Property -notcontains 'SignInActivity' }
    }

    It 'retains guests when requested sign-in activity lacks AuditLog.Read.All permission' {
        $script:GuestGraphCall = 0
        Mock Get-MgUser {
            $script:GuestGraphCall++
            if ($script:GuestGraphCall -eq 1) {
                throw 'Get-MgUser_List: The principal does not have required Microsoft Graph permission(s): AuditLog.Read.All. Status: 403 (Forbidden)'
            }

            [PSCustomObject] @{
                DisplayName             = 'Guest One'
                Id                      = 'guest-1'
                UserPrincipalName       = 'guest.one#EXT#@contoso.onmicrosoft.com'
                Mail                    = 'guest.one@example.com'
                OtherMails              = @()
                UserType                = 'Guest'
                AccountEnabled          = $true
                LicenseAssignmentStates = @()
                AssignedPlans           = @()
            }
        }

        $guests = @(Get-MyGuest -IncludeSignInActivity -WarningAction SilentlyContinue)

        $guests.Count | Should -Be 1
        $guests[0].SignInActivityRequested | Should -BeTrue
        $guests[0].SignInActivityAvailable | Should -BeFalse
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $Property -contains 'SignInActivity' }
        Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter { $Property -notcontains 'SignInActivity' }
    }
}
