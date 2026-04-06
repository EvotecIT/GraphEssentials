function Get-MyUser {
    <#
    .SYNOPSIS
    Retrieves detailed information about users from Microsoft Graph API.

    .DESCRIPTION
    Gets comprehensive user information from Microsoft Graph API with options to organize
    by license or service plan. Provides detailed user properties including account status,
    sign-in activity, licenses, user type, managers, and on-premises synchronization details.

    .PARAMETER PerLicense
    When specified, organizes user information by license instead of by user.

    .PARAMETER PerServicePlan
    When specified, organizes user information by service plan instead of by user.

    .EXAMPLE
    Get-MyUser
    Returns detailed information about all users in the tenant.

    .EXAMPLE
    Get-MyUser -PerLicense
    Returns user information organized by license assignments.

    .EXAMPLE
    Get-MyUser -PerServicePlan
    Returns user information organized by service plan assignments.

    .NOTES
    This function requires the Microsoft.Graph.Users and Microsoft.Graph.Identity modules
    with appropriate permissions. Typically requires User.Read.All permissions.
    Sign-in activity fields may require additional audit-related permissions.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ParameterSetName = 'PerLicense')][switch] $PerLicense,
        [Parameter(ParameterSetName = 'PerServicePlan')][switch] $PerServicePlan
    )

    $Today = Get-Date
    $Properties = @(
        'LicenseAssignmentStates', 'AccountEnabled', 'AssignedLicenses', 'AssignedPlans', 'CreatedDateTime',
        'DisplayName', 'Id', 'GivenName', 'SurName', 'JobTitle', 'LastPasswordChangeDateTime', 'Mail',
        'OnPremisesLastSyncDateTime', 'OnPremisesSyncEnabled', 'OnPremisesDistinguishedName',
        'SignInActivity', 'UserPrincipalName', 'UserType'
    )

    Write-Verbose -Message 'Get-MyUser - Getting list of licenses'
    $AllLicenses = Get-MyLicense -Internal
    $AllLicensesValues = $AllLicenses['Licenses'].Values | Sort-Object
    $AllServicePlansValues = $AllLicenses['ServicePlans'].Values | Sort-Object

    $getMgUserSplat = @{
        All      = $true
        Property = $Properties
    }

    Write-Verbose -Message 'Get-MyUser - Getting list of all users'
    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $AllUsers = Get-MgUser @getMgUserSplat -ExpandProperty Manager
    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyUser - Got $($AllUsers.Count) users in $EndTime. Now processing them."

    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $Count = 0
    foreach ($User in $AllUsers) {
        $Count++
        Write-Verbose -Message "Get-MyUser - Processing $($User.DisplayName) - $Count/$($AllUsers.Count)"

        if ($User.CreatedDateTime) {
            $CreatedDaysAgo = [math]::Floor((New-TimeSpan -Start $User.CreatedDateTime -End $Today).TotalDays)
        } else {
            $CreatedDaysAgo = $null
        }

        if ($User.LastPasswordChangeDateTime) {
            $LastPasswordChangeDays = [math]::Floor((New-TimeSpan -Start $User.LastPasswordChangeDateTime -End $Today).TotalDays)
        } else {
            $LastPasswordChangeDays = $null
        }

        if ($User.OnPremisesLastSyncDateTime) {
            $LastSynchronizedDays = [math]::Floor((New-TimeSpan -Start $User.OnPremisesLastSyncDateTime -End $Today).TotalDays)
        } else {
            $LastSynchronizedDays = $null
        }

        if ($User.SignInActivity -and $User.SignInActivity.LastSignInDateTime) {
            $LastSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $User.SignInActivity.LastSignInDateTime -End $Today).TotalDays)
        } else {
            $LastSignInDaysAgo = $null
        }

        if ($User.SignInActivity -and $User.SignInActivity.LastNonInteractiveSignInDateTime) {
            $LastNonInteractiveSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $User.SignInActivity.LastNonInteractiveSignInDateTime -End $Today).TotalDays)
        } else {
            $LastNonInteractiveSignInDaysAgo = $null
        }

        if ($User.SignInActivity -and $User.SignInActivity.LastSuccessfulSignInDateTime) {
            $LastSuccessfulSignInDaysAgo = [math]::Floor((New-TimeSpan -Start $User.SignInActivity.LastSuccessfulSignInDateTime -End $Today).TotalDays)
        } else {
            $LastSuccessfulSignInDaysAgo = $null
        }

        if ($null -ne $User.SignInActivity) {
            $NeverSignedIn = ($null -eq $LastSignInDaysAgo -and $null -eq $LastNonInteractiveSignInDaysAgo)
            $NeverSuccessfullySignedIn = ($null -eq $LastSuccessfulSignInDaysAgo)
        } else {
            $NeverSignedIn = $null
            $NeverSuccessfullySignedIn = $null
        }

        if ($null -ne $LastSignInDaysAgo -and $null -ne $LastNonInteractiveSignInDaysAgo) {
            $SignInPattern = 'Interactive + non-interactive'
        } elseif ($null -ne $LastSignInDaysAgo) {
            $SignInPattern = 'Interactive only'
        } elseif ($null -ne $LastNonInteractiveSignInDaysAgo) {
            $SignInPattern = 'Non-interactive only'
        } elseif ($null -ne $LastSuccessfulSignInDaysAgo) {
            $SignInPattern = 'Successful sign-in only'
        } elseif ($null -ne $User.SignInActivity) {
            $SignInPattern = 'No sign-in recorded'
        } else {
            $SignInPattern = 'No activity data'
        }

        $UserDomain = $null
        if ($User.UserPrincipalName -and $User.UserPrincipalName -like '*@*') {
            $UserDomain = ($User.UserPrincipalName -split '@', 2)[1]
        } elseif ($User.Mail -and $User.Mail -like '*@*') {
            $UserDomain = ($User.Mail -split '@', 2)[1]
        }

        $OutputUser = [ordered] @{
            DisplayName                      = $User.DisplayName
            Id                               = $User.Id
            UserPrincipalName                = $User.UserPrincipalName
            UserDomain                       = $UserDomain
            GivenName                        = $User.GivenName
            SurName                          = $User.SurName
            UserType                         = $User.UserType
            Enabled                          = $User.AccountEnabled
            JobTitle                         = $User.JobTitle
            Mail                             = $User.Mail
            CreatedDateTime                  = $User.CreatedDateTime
            CreatedDaysAgo                   = $CreatedDaysAgo
            Manager                          = if ($User.Manager.Id) { $User.Manager.Id } else { $null }
            ManagerDisplayName               = if ($User.Manager.Id) { $User.Manager.AdditionalProperties.displayName } else { $null }
            ManagerUserPrincipalName         = if ($User.Manager.Id) { $User.Manager.AdditionalProperties.userPrincipalName } else { $null }
            ManagerIsSynchronized            = if ($User.Manager.Id) { $User.Manager.AdditionalProperties.onPremisesSyncEnabled } else { $null }
            HasManager                       = [bool] $User.Manager.Id
            LastPasswordChangeDateTime       = $User.LastPasswordChangeDateTime
            LastPasswordChangeDays           = $LastPasswordChangeDays
            IsSynchronized                   = if ($null -ne $User.OnPremisesSyncEnabled) { [bool] $User.OnPremisesSyncEnabled } else { $null }
            LastSynchronized                 = $User.OnPremisesLastSyncDateTime
            LastSynchronizedDays             = $LastSynchronizedDays
            OnPremisesDistinguishedName      = $User.OnPremisesDistinguishedName
            LastSignInDateTime               = if ($User.SignInActivity) { $User.SignInActivity.LastSignInDateTime } else { $null }
            LastSignInDaysAgo                = $LastSignInDaysAgo
            LastNonInteractiveSignInDateTime = if ($User.SignInActivity) { $User.SignInActivity.LastNonInteractiveSignInDateTime } else { $null }
            LastNonInteractiveSignInDaysAgo  = $LastNonInteractiveSignInDaysAgo
            LastSuccessfulSignInDateTime     = if ($User.SignInActivity) { $User.SignInActivity.LastSuccessfulSignInDateTime } else { $null }
            LastSuccessfulSignInDaysAgo      = $LastSuccessfulSignInDaysAgo
            NeverSignedIn                    = $NeverSignedIn
            NeverSuccessfullySignedIn        = $NeverSuccessfullySignedIn
            SignInPattern                    = $SignInPattern
        }

        if ($PerLicense) {
            $LicensesErrors = [System.Collections.Generic.List[string]]::new()
            $OutputUser['DifferentLicense'] = [System.Collections.Generic.List[string]]::new()
            foreach ($License in $AllLicensesValues) {
                $OutputUser[$License] = [System.Collections.Generic.List[string]]::new()
            }

            foreach ($License in $User.LicenseAssignmentStates) {
                try {
                    $LicenseFound = $AllLicenses['Licenses'][$License.SkuId]
                    if ($LicenseFound) {
                        if ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -gt 0) {
                            $OutputUser[$LicenseFound].Add('Group')
                        } elseif ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -eq 0) {
                            $OutputUser[$LicenseFound].Add('Direct')
                        }
                    } else {
                        if ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -gt 0) {
                            $OutputUser['DifferentLicense'].Add("Group $($License.SkuId)")
                        } elseif ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -eq 0) {
                            $OutputUser['DifferentLicense'].Add("Direct $($License.SkuId)")
                        }
                        Write-Warning -Message "$($License.SkuId) not found in AllLicenses"
                        $LicensesErrors.Add("License ID $($License.SkuId) not found in All Licenses")
                    }
                } catch {
                    Write-Warning -Message "Error processing $($License.SkuId) for $($User.DisplayName)"
                }
            }
            $OutputUser['LicensesErrors'] = $LicensesErrors | Sort-Object -Unique
        } elseif ($PerServicePlan) {
            $OutputUser['DeletedServicePlans'] = [System.Collections.Generic.List[string]]::new()
            foreach ($ServicePlan in $AllServicePlansValues) {
                $OutputUser[$ServicePlan] = ''
            }
            foreach ($ServicePlan in $User.AssignedPlans) {
                if ($AllLicenses['ServicePlans'][$ServicePlan.ServicePlanId]) {
                    $OutputUser[$AllLicenses['ServicePlans'][$ServicePlan.ServicePlanId]] = 'Assigned'
                } else {
                    if ($ServicePlan.CapabilityStatus -ne 'Deleted') {
                        Write-Warning -Message "$($ServicePlan.ServicePlanId) $($ServicePlan.Service) not found in AllLicenses"
                    } else {
                        $OutputUser['DeletedServicePlans'].Add($ServicePlan.ServicePlanId)
                    }
                }
            }
        } else {
            $LicensesList = [System.Collections.Generic.List[string]]::new()
            $LicensesStatus = [System.Collections.Generic.List[string]]::new()
            $LicensesErrors = [System.Collections.Generic.List[string]]::new()
            foreach ($License in $User.LicenseAssignmentStates) {
                $LicenseFound = $AllLicenses['Licenses'][$License.SkuId]
                if ($LicenseFound -and $LicensesList -notcontains $LicenseFound) {
                    $LicensesList.Add($LicenseFound)
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
                } elseif (-not $LicenseFound) {
                    if ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -gt 0) {
                        $LicensesStatus.Add('Group')
                    } elseif ($License.State -eq 'Active' -and $License.AssignedByGroup.Count -eq 0) {
                        $LicensesStatus.Add('Direct')
                    }
                    $LicensesErrors.Add("License ID $($License.SkuId) not found in All Licenses")
                    Write-Warning -Message "Get-MyUser - License ID $($License.SkuId) not found in AllLicenses for $($User.DisplayName)"
                } else {
                    $LicensesStatus.Add('Duplicate')
                }
            }

            $Plans = foreach ($Object in $User.AssignedPlans) {
                if ($Object.CapabilityStatus -ne 'Deleted') {
                    $AllLicenses['ServicePlans'][$Object.ServicePlanId]
                }
            }

            $OutputUser['HasLicenses'] = $LicensesList.Count -gt 0
            $OutputUser['LicenseCount'] = $LicensesList.Count
            $OutputUser['LicensesStatus'] = $LicensesStatus | Sort-Object -Unique
            $OutputUser['LicensesErrors'] = $LicensesErrors
            $OutputUser['Licenses'] = $LicensesList
            $OutputUser['Plans'] = $Plans

            $IsCloudOnlyMemberCandidate = $User.AccountEnabled -eq $true -and $User.UserType -eq 'Member' -and $User.OnPremisesSyncEnabled -eq $false
            $CloudOnlyProfile = $null
            $CloudOnlyReviewPriority = $null
            $CloudOnlySignals = [System.Collections.Generic.List[string]]::new()

            if ($IsCloudOnlyMemberCandidate) {
                $CloudOnlySignals.Add('Enabled member account')
                $CloudOnlySignals.Add('Cloud-only identity source')

                if ($User.Manager.Id) {
                    $CloudOnlySignals.Add('Manager assigned')
                } else {
                    $CloudOnlySignals.Add('No manager assigned')
                }
                if ($User.GivenName -or $User.SurName) {
                    $CloudOnlySignals.Add('Given name or surname present')
                } else {
                    $CloudOnlySignals.Add('No given name or surname')
                }
                if ($User.JobTitle) {
                    $CloudOnlySignals.Add('Job title present')
                } else {
                    $CloudOnlySignals.Add('No job title')
                }
                if ($null -ne $LastSignInDaysAgo) {
                    $CloudOnlySignals.Add('Interactive sign-in observed')
                }
                if ($null -ne $LastNonInteractiveSignInDaysAgo -and $null -eq $LastSignInDaysAgo) {
                    $CloudOnlySignals.Add('Only non-interactive sign-in observed')
                }
                if ($null -ne $LastSuccessfulSignInDaysAgo) {
                    $CloudOnlySignals.Add("Successful sign-in recorded $LastSuccessfulSignInDaysAgo days ago")
                } elseif ($NeverSuccessfullySignedIn -eq $true) {
                    $CloudOnlySignals.Add('No successful sign-in recorded')
                }
                if (-not $LicensesList.Count) {
                    $CloudOnlySignals.Add('No licenses assigned')
                }

                $workloadLicenseKeywords = @(
                    'teams rooms',
                    'meeting room',
                    'common area phone',
                    'resource account',
                    'virtual user'
                )
                $hasWorkloadLicenseIndicator = $false

                foreach ($LicenseName in $LicensesList) {
                    $licenseValue = [string] $LicenseName
                    $licenseValueLower = $licenseValue.ToLowerInvariant()
                    foreach ($keyword in $workloadLicenseKeywords) {
                        if ($licenseValueLower -like "*$keyword*") {
                            $hasWorkloadLicenseIndicator = $true
                            $CloudOnlySignals.Add("Workload license: $licenseValue")
                            break
                        }
                    }
                    if ($hasWorkloadLicenseIndicator) {
                        break
                    }
                }

                if (-not $hasWorkloadLicenseIndicator) {
                    foreach ($PlanName in $Plans) {
                        if (-not $PlanName) {
                            continue
                        }

                        $planValue = [string] $PlanName
                        $planValueLower = $planValue.ToLowerInvariant()
                        foreach ($keyword in $workloadLicenseKeywords) {
                            if ($planValueLower -like "*$keyword*") {
                                $hasWorkloadLicenseIndicator = $true
                                $CloudOnlySignals.Add("Workload plan: $planValue")
                                break
                            }
                        }
                        if ($hasWorkloadLicenseIndicator) {
                            break
                        }
                    }
                }

                $hasHumanIndicators = $false
                if ($User.Manager.Id -or $User.GivenName -or $User.SurName -or $User.JobTitle -or $null -ne $LastSignInDaysAgo) {
                    $hasHumanIndicators = $true
                }

                $hasWorkloadBehaviorIndicators = $null -eq $LastSignInDaysAgo -and
                    $null -ne $LastNonInteractiveSignInDaysAgo -and
                    -not $User.Manager.Id -and
                    -not $User.GivenName -and
                    -not $User.SurName -and
                    -not $User.JobTitle

                if ($hasWorkloadBehaviorIndicators) {
                    $CloudOnlySignals.Add('Non-interactive-only activity with no manager or profile attributes')
                }

                if ($hasWorkloadLicenseIndicator -or $hasWorkloadBehaviorIndicators) {
                    $CloudOnlyProfile = 'Likely workload/resource'
                    $CloudOnlyReviewPriority = 'Low'
                } elseif ($hasHumanIndicators -and -not $hasWorkloadLicenseIndicator) {
                    $CloudOnlyProfile = 'Likely human account'
                    $CloudOnlyReviewPriority = 'High'
                } else {
                    $CloudOnlyProfile = 'Needs review'
                    $CloudOnlyReviewPriority = 'Medium'
                }
            }

            $OutputUser['IsCloudOnlyMemberCandidate'] = $IsCloudOnlyMemberCandidate
            $OutputUser['CloudOnlyProfile'] = $CloudOnlyProfile
            $OutputUser['CloudOnlyReviewPriority'] = $CloudOnlyReviewPriority
            $OutputUser['CloudOnlySignals'] = if ($CloudOnlySignals.Count -gt 0) { $CloudOnlySignals -join ', ' } else { $null }
        }

        [PSCustomObject] $OutputUser
    }

    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyUser - Processed all users in $EndTime."
}
