function Get-MyUser {
    <#
    .SYNOPSIS
    Retrieves detailed information about users from Microsoft Graph API.

    .DESCRIPTION
    Gets comprehensive user information from Microsoft Graph API with options to organize
    by license or service plan. Provides detailed user properties including account status,
    authentication methods, licenses, and on-premises synchronization details.

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
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ParameterSetName = 'PerLicense')][switch] $PerLicense,
        [Parameter(ParameterSetName = 'PerServicePlan')][switch] $PerServicePlan
    )
    $Today = Get-Date
    $Properties = @(
        'LicenseAssignmentStates', 'AccountEnabled', 'AssignedLicenses', 'AssignedPlans', 'DisplayName',
        'Id', 'GivenName', 'SurName', 'JobTitle', 'LastPasswordChangeDateTime', 'Mail', 'Manager'
        'OnPremisesLastSyncDateTime', 'OnPremisesSyncEnabled', 'OnPremisesDistinguishedName',
        'UserPrincipalName'
    )
    Write-Verbose -Message "Get-MyUser - Getting list of licenses"
    $AllLicenses = Get-MyLicense -Internal
    $AllLicensesValues = $AllLicenses['Licenses'].Values | Sort-Object
    $AllServicePlansValues = $AllLicenses['ServicePlans'].Values | Sort-Object

    $getMgUserSplat = @{
        All      = $true
        Property = $Properties
    }
    Write-Verbose -Message "Get-MyUser - Getting list of all users"
    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $AllUsers = Get-MgUser @getMgUserSplat -ExpandProperty Manager
    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyUser - Got $($AllUsers.Count) users in $($EndTime). Now processing them."

    $StartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $Count = 0
    foreach ($User in $AllUsers) {
        $Count++
        Write-Verbose -Message "Get-MyUser - Processing $($User.DisplayName) - $Count/$($AllUsers.Count)"

        if ($User.LastPasswordChangeDateTime) {
            $LastPasswordChangeDays = $( - $($User.LastPasswordChangeDateTime - $Today).Days)
        } else {
            $LastPasswordChangeDays = $null
        }

        if ($User.OnPremisesLastSyncDateTime) {
            $LastSynchronizedDays = $( - $($User.OnPremisesLastSyncDateTime - $Today).Days)
        } else {
            $LastSynchronizedDays = $null
        }

        $OutputUser = [ordered] @{
            'DisplayName'                 = $User.DisplayName
            'Id'                          = $User.Id
            'UserPrincipalName'           = $User.UserPrincipalName
            'GivenName'                   = $User.GivenName
            'SurName'                     = $User.SurName
            'Enabled'                     = $User.AccountEnabled
            'JobTitle'                    = $User.JobTitle
            'Mail'                        = $User.Mail
            'Manager'                     = if ($User.Manager.Id) { $User.Manager.Id } else { $null }
            'ManagerDisplayName'          = if ($User.Manager.Id) { $User.Manager.AdditionalProperties.displayName } else { $null }
            'ManagerUserPrincipalName'    = if ($User.Manager.Id) { $User.Manager.AdditionalProperties.userPrincipalName } else { $null }
            'ManagerIsSynchronized'       = if ($User.Manager.Id) { if ($User.Manager.AdditionalProperties.onPremisesSyncEnabled) { $User.Manager.AdditionalProperties.onPremisesSyncEnabled } else { $false } } else { $null }
            'LastPasswordChangeDateTime'  = $User.LastPasswordChangeDateTime
            'LastPasswordChangeDays'      = $LastPasswordChangeDays
            'IsSynchronized'              = if ($User.OnPremisesSyncEnabled) { $User.OnPremisesSyncEnabled } else { $null }
            'LastSynchronized'            = $User.OnPremisesLastSyncDateTime
            'LastSynchronizedDays'        = $LastSynchronizedDays
            'OnPremisesDistinguishedName' = $User.OnPremisesDistinguishedName
        }
        if ($PerLicense) {
            $LicensesErrors = [System.Collections.Generic.List[string]]::new()
            $OutputUser['NotMatched'] = [System.Collections.Generic.List[string]]::new()
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
            $User.LicenseAssignmentStates | ForEach-Object {
                if ($LicensesList -notcontains $AllLicenses['Licenses'][$_.SkuId]) {
                    $LicensesList.Add($AllLicenses['Licenses'][$_.SkuId])
                    if ($_.State -eq 'Active' -and $_.AssignedByGroup.Count -gt 0) {
                        $LicensesStatus.Add('Group')
                    } elseif ($_.State -eq 'Active' -and $_.AssignedByGroup.Count -eq 0) {
                        $LicensesStatus.Add('Direct')
                    } else {
                        $LicensesStatus.Add($_.State)
                        if ($LicensesErrors -notcontains $_.Error) {
                            $LicensesErrors.Add($_.Error)
                        }
                    }
                } else {
                    $LicensesStatus.Add("Duplicate")
                }
            }
            $Plans = foreach ($Object in $User.AssignedPlans) {
                if ($Object.CapabilityStatus -ne 'Deleted') {
                    $AllLicenses['ServicePlans'][$Object.ServicePlanId]
                }
            }

            $OutputUser['LicensesStatus'] = $LicensesStatus | Sort-Object -Unique
            $OutputUser['LicensesErrors'] = $LicensesErrors
            $OutputUser['Licenses'] = $LicensesList
            $OutputUser['Plans'] = $Plans
        }
        [PSCustomObject] $OutputUser
    }
    $EndTime = Stop-TimeLog -Time $StartTime -Option OneLiner
    Write-Verbose -Message "Get-MyUser - Processed all users in $($EndTime)."
}