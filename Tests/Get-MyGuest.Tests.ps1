BeforeAll {
    . (Join-Path $PSScriptRoot '..\Public\Get-MyGuest.ps1')

    function Get-MyLicense {}
    function Get-MyUserRolesAndLicensesLookup {}
    function Get-MgUser {}
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
        $guests = @(Get-MyGuest)

        $guests.Count | Should -Be 1
        $guests[0].SignInPattern | Should -Be 'Successful sign-in only'
        $guests[0].NeverSignedIn | Should -BeFalse
        $guests[0].NeverSuccessfullySignedIn | Should -BeFalse
    }
}
