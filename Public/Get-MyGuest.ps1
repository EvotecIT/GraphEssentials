function Get-MyGuest {
    <#
    .SYNOPSIS
    Retrieves guest and external user accounts from Microsoft Graph API.

    .DESCRIPTION
    Gets guest and external user accounts from Microsoft Graph API with properties that are
    useful when reviewing B2B accounts. The output focuses on invitation state, account
    lifecycle, licensing, and tenant-specific metadata to make external identities easier
    to audit separately from member users.

    .EXAMPLE
    Get-MyGuest
    Returns guest and external users in the tenant.

    .PARAMETER IncludeSignInActivity
    Requests sign-in activity from Microsoft Graph. This is opt-in because it requires
    AuditLog.Read.All. If that permission is unavailable, the command retries without
    sign-in activity while retaining guest and license data.

    .NOTES
    This function requires the Microsoft.Graph.Users and Microsoft.Graph.Identity modules
    with appropriate permissions. Typically requires User.Read.All permissions.
    Sign-in activity is not requested by default.
    #>
    [CmdletBinding()]
    param(
        [switch] $IncludeSignInActivity
    )

    $Today = Get-Date
    $Properties = @(
        'AccountEnabled', 'AssignedPlans', 'CompanyName', 'CreatedDateTime', 'CreationType',
        'DisplayName', 'ExternalUserState', 'ExternalUserStateChangeDateTime', 'Id',
        'LicenseAssignmentStates', 'Mail', 'OnPremisesSyncEnabled', 'OtherMails',
        'UserPrincipalName', 'UserType'
    )

    Write-Verbose -Message 'Get-MyGuest - Getting list of licenses'
    $AllLicenses = Get-MyLicense -Internal

    $RoleLookup = $null
    try {
        Write-Verbose -Message 'Get-MyGuest - Building lookup for guest role assignments'
        $RoleLookup = Get-MyUserRolesAndLicensesLookup
    } catch {
        Write-Warning -Message "Get-MyGuest - Failed to build role lookup. Error: $($_.Exception.Message)"
    }

    $getMgUserSplat = @{
        All      = $true
        Filter   = "userType eq 'Guest'"
        Property = $Properties
    }

    Write-Verbose -Message 'Get-MyGuest - Getting list of guest and external users'
    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $GuestQuery = Get-GraphEssentialsUsers -Query $getMgUserSplat -CommandName 'Get-MyGuest' -IncludeSignInActivity:$IncludeSignInActivity
    $AllGuests = @($GuestQuery.Users)
    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyGuest - Got $($AllGuests.Count) guest users in $EndTime. Now processing them."

    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $Count = 0
    foreach ($Guest in $AllGuests) {
        $Count++
        Write-Verbose -Message "Get-MyGuest - Processing $($Guest.DisplayName) - $Count/$($AllGuests.Count)"

        if ($Guest.CreatedDateTime) {
            $CreatedDaysAgo = [math]::Floor((New-TimeSpan -Start $Guest.CreatedDateTime -End $Today).TotalDays)
        } else {
            $CreatedDaysAgo = $null
        }

        if ($Guest.ExternalUserStateChangeDateTime) {
            $ExternalUserStateChangeDaysAgo = [math]::Floor((New-TimeSpan -Start $Guest.ExternalUserStateChangeDateTime -End $Today).TotalDays)
        } else {
            $ExternalUserStateChangeDaysAgo = $null
        }

        if ($Guest.SignInActivity -and $Guest.SignInActivity.LastSignInDateTime) {
            $LastSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $Guest.SignInActivity.LastSignInDateTime -End $Today).TotalDays)
        } else {
            $LastSignInDaysAgo = $null
        }

        if ($Guest.SignInActivity -and $Guest.SignInActivity.LastNonInteractiveSignInDateTime) {
            $LastNonInteractiveSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $Guest.SignInActivity.LastNonInteractiveSignInDateTime -End $Today).TotalDays)
        } else {
            $LastNonInteractiveSignInDaysAgo = $null
        }

        if ($Guest.SignInActivity -and $Guest.SignInActivity.LastSuccessfulSignInDateTime) {
            $LastSuccessfulSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $Guest.SignInActivity.LastSuccessfulSignInDateTime -End $Today).TotalDays)
        } else {
            $LastSuccessfulSignInDaysAgo = $null
        }

        if ($null -ne $LastSignInDaysAgo -and $null -ne $LastNonInteractiveSignInDaysAgo) {
            $SignInPattern = 'Interactive + non-interactive'
        } elseif ($null -ne $LastSignInDaysAgo) {
            $SignInPattern = 'Interactive only'
        } elseif ($null -ne $LastNonInteractiveSignInDaysAgo) {
            $SignInPattern = 'Non-interactive only'
        } elseif ($null -ne $LastSuccessfulSignInDaysAgo) {
            $SignInPattern = 'Successful sign-in only'
        } elseif ($Guest.SignInActivity) {
            $SignInPattern = 'No sign-in recorded'
        } else {
            $SignInPattern = 'No activity data'
        }

        $ExternalAddress = $null
        if ($Guest.OtherMails -and $Guest.OtherMails.Count -gt 0) {
            $ExternalAddress = $Guest.OtherMails[0]
        } elseif ($Guest.Mail) {
            $ExternalAddress = $Guest.Mail
        }

        $GuestDomain = $null
        if ($ExternalAddress -and $ExternalAddress -like '*@*') {
            $GuestDomain = ($ExternalAddress -split '@', 2)[1]
        } elseif ($Guest.UserPrincipalName -and $Guest.UserPrincipalName -like '*@*') {
            $GuestDomain = ($Guest.UserPrincipalName -split '@', 2)[1]
        }

        $RoleNames = $null
        if ($RoleLookup -and $RoleLookup.Roles.ContainsKey($Guest.UserPrincipalName)) {
            $RoleNames = $RoleLookup.Roles[$Guest.UserPrincipalName]
        }

        $LicensesList = [System.Collections.Generic.List[string]]::new()
        $LicensesStatus = [System.Collections.Generic.List[string]]::new()
        $LicensesErrors = [System.Collections.Generic.List[string]]::new()
        foreach ($License in $Guest.LicenseAssignmentStates) {
            $LicenseName = $AllLicenses['Licenses'][$License.SkuId]
            if ($LicenseName -and $LicensesList -notcontains $LicenseName) {
                $LicensesList.Add($LicenseName)
                if ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -gt 0) {
                    $LicensesStatus.Add('Group')
                } elseif ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -eq 0) {
                    $LicensesStatus.Add('Direct')
                } else {
                    $LicensesStatus.Add($License.State)
                    if ($License.Error -and $LicensesErrors -notcontains $License.Error) {
                        $LicensesErrors.Add($License.Error)
                    }
                }
            } elseif (-not $LicenseName) {
                if ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -gt 0) {
                    $LicensesStatus.Add('Group')
                } elseif ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -eq 0) {
                    $LicensesStatus.Add('Direct')
                }
                $LicensesErrors.Add("License ID $($License.SkuId) not found in All Licenses")
                Write-Warning -Message "Get-MyGuest - License ID $($License.SkuId) not found in AllLicenses for $($Guest.DisplayName)"
            } else {
                $LicensesStatus.Add('Duplicate')
            }
        }

        $Plans = foreach ($AssignedPlan in $Guest.AssignedPlans) {
            if ($AssignedPlan.CapabilityStatus -ne 'Deleted') {
                $AllLicenses['ServicePlans'][$AssignedPlan.ServicePlanId]
            }
        }

        if ($null -ne $Guest.SignInActivity) {
            $NeverSignedIn = ($null -eq $LastSignInDaysAgo -and $null -eq $LastNonInteractiveSignInDaysAgo -and $null -eq $LastSuccessfulSignInDaysAgo)
            $NeverSuccessfullySignedIn = ($null -eq $LastSuccessfulSignInDaysAgo)
        } else {
            $NeverSignedIn = $null
            $NeverSuccessfullySignedIn = $null
        }

        [PSCustomObject] @{
            DisplayName                       = $Guest.DisplayName
            Id                                = $Guest.Id
            UserPrincipalName                 = $Guest.UserPrincipalName
            Mail                              = $Guest.Mail
            OtherMails                        = $Guest.OtherMails
            ExternalAddress                   = $ExternalAddress
            GuestDomain                       = $GuestDomain
            UserType                          = $Guest.UserType
            Enabled                           = $Guest.AccountEnabled
            CreatedDateTime                   = $Guest.CreatedDateTime
            CreatedDaysAgo                    = $CreatedDaysAgo
            ExternalUserState                 = $Guest.ExternalUserState
            ExternalUserStateChangeDateTime   = $Guest.ExternalUserStateChangeDateTime
            ExternalUserStateChangeDaysAgo    = $ExternalUserStateChangeDaysAgo
            LastSignInDateTime                = if ($Guest.SignInActivity) { $Guest.SignInActivity.LastSignInDateTime } else { $null }
            LastSignInDaysAgo                 = $LastSignInDaysAgo
            LastNonInteractiveSignInDateTime  = if ($Guest.SignInActivity) { $Guest.SignInActivity.LastNonInteractiveSignInDateTime } else { $null }
            LastNonInteractiveSignInDaysAgo   = $LastNonInteractiveSignInDaysAgo
            LastSuccessfulSignInDateTime      = if ($Guest.SignInActivity) { $Guest.SignInActivity.LastSuccessfulSignInDateTime } else { $null }
            LastSuccessfulSignInDaysAgo       = $LastSuccessfulSignInDaysAgo
            NeverSignedIn                     = $NeverSignedIn
            NeverSuccessfullySignedIn         = $NeverSuccessfullySignedIn
            SignInPattern                     = $SignInPattern
            SignInActivityRequested           = $GuestQuery.SignInActivityRequested
            SignInActivityAvailable           = $GuestQuery.SignInActivityAvailable
            CreationType                      = $Guest.CreationType
            CompanyName                       = $Guest.CompanyName
            IsSynchronized                    = if ($Guest.OnPremisesSyncEnabled) { $Guest.OnPremisesSyncEnabled } else { $null }
            HasLicenses                       = $LicensesList.Count -gt 0
            LicenseCount                      = $LicensesList.Count
            LicensesStatus                    = $LicensesStatus | Sort-Object -Unique
            LicensesErrors                    = $LicensesErrors
            Licenses                          = $LicensesList
            Plans                             = $Plans
            HasRoles                          = $null -ne $RoleNames -and $RoleNames.Count -gt 0
            RoleCount                         = if ($RoleNames) { $RoleNames.Count } else { 0 }
            Roles                             = $RoleNames
        }
    }

    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyGuest - Processed all guest users in $EndTime."
}
