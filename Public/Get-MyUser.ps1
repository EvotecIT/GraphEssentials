function Get-MyUser {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ParameterSetName = 'PerLicense')][switch] $PerLicense,
        [Parameter(ParameterSetName = 'PerServicePlan')][switch] $PerServicePlan
    )
    $Properties = @(
        #'LicenseDetails',
        'LicenseAssignmentStates', 'AccountEnabled', 'AssignedLicenses', 'AssignedPlans', 'DisplayName',
        'Id', 'GivenName', 'SurName', 'JobTitle', 'LastPasswordChangeDateTime', 'Mail', 'Manager'
    )
    $getMgUserSplat = @{
        All      = $true
        Property = $Properties
    }

    $AllLicenses = Get-MyLicense -Internal
    $AllUsers = Get-MgUser @getMgUserSplat
    foreach ($User in $AllUsers) {
        $OutputUser = [ordered] @{
            'DisplayName'                = $User.DisplayName
            'Id'                         = $User.Id
            'GivenName'                  = $User.GivenName
            'SurName'                    = $User.SurName
            'AccountEnabled'             = $User.AccountEnabled
            'JobTitle'                   = $User.JobTitle
            'Mail'                       = $User.Mail
            'Manager'                    = if ($User.Manager.Id) { $User.Manager.Id } else { $null }
            'LastPasswordChangeDateTime' = $User.LastPasswordChangeDateTime
            #'AssignedLicenses'           = $User.AssignedLicenses
        }
        if ($PerLicense) {
            $LicensesErrors = [System.Collections.Generic.List[string]]::new()
            $OutputUser['NotMatched'] = [System.Collections.Generic.List[string]]::new()
            foreach ($License in $AllLicenses['Licenses'].Values | Sort-Object) {
                $OutputUser[$License] = [System.Collections.Generic.List[string]]::new()
            }
            foreach ($License in $User.LicenseAssignmentStates) {
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
                    $LicensesErrors.Add("License ID $(License.SkuId) not found in All Licenses")
                }
            }
            $OutputUser['LicensesErrors'] = $LicensesErrors | Sort-Object -Unique
        } elseif ($PerServicePlan) {
            $OutputUser['DeletedServicePlans'] = [System.Collections.Generic.List[string]]::new()
            foreach ($ServicePlan in $AllLicenses['ServicePlans'].Values | Sort-Object) {
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
                        $LicensesErrors.Add($_.Error)
                    }
                } else {
                    $LicensesStatus.Add("Duplicate")
                }
                <#
AssignedByGroup                      DisabledPlans Error LastUpdatedDateTime SkuId                                State
---------------                      ------------- ----- ------------------- -----                                -----
afcbd319-f9d2-45b2-b7a4-6024ed6bb6a2 {}            None  2023-01-15 09:46:31 6fd2c87f-b296-42f0-b197-1e91e994b900 Active
                                     {}            None  2022-05-12 12:50:06 26124093-3d78-432b-b5dc-48bf992543d5 Active
                                     {}            None  2022-05-12 12:50:06 6fd2c87f-b296-42f0-b197-1e91e994b900 Active
                                     {}            None  2022-05-12 12:50:06 b05e124f-c7cc-45a0-a6aa-8cf78c946968 Active
                                     {}            None  2022-05-12 12:50:06 f30db892-07e9-47e9-837c-80727f46fd3d Active
                                     {}            None  2022-05-12 12:50:06 f8a1db68-be16-40ed-86d5-cb42ce701560 Active
#>
            }

            $OutputUser['LicensesStatus'] = $LicensesStatus | Sort-Object -Unique
            $OutputUser['LicensesErrors'] = $LicensesErrors | Sort-Object -Unique
            $OutputUser['Licenses'] = $LicensesList
            $OutputUser['Plans'] = $User.AssignedPlans | ForEach-Object {
                if ($_.CapabilityStatus -ne 'Deleted') {
                    #$_.Service
                    #Convert-Office365License -License $_.ServicePlanId
                    $AllLicenses['ServicePlans'][$_.ServicePlanId]
                }
            }
        }
        [PSCustomObject] $OutputUser
        #}

        # if ($User.AssignedLicenses) {
        <#
DisabledPlans SkuId
------------- -----
{}            f30db892-07e9-47e9-837c-80727f46fd3d
{}            6fd2c87f-b296-42f0-b197-1e91e994b900
#>

        #$User.AssignedLicenses | Format-List

        #  }
        # if ($User.LicenseAssignmentStates) {
        #$User.LicenseAssignmentStates | Format-List
        <#
AssignedByGroup      :
DisabledPlans        : {}
Error                : None
LastUpdatedDateTime  : 2020-02-07 08:56:49
SkuId                : 6fd2c87f-b296-42f0-b197-1e91e994b900
State                : Active
AdditionalProperties : {}

AssignedByGroup      :
DisabledPlans        : {}
Error                : None
LastUpdatedDateTime  : 2020-02-07 08:56:49
SkuId                : f30db892-07e9-47e9-837c-80727f46fd3d
State                : Active
AdditionalProperties : {}
#>

        # }
        #if ($User.AssignedPlans) {
        #   $User.AssignedPlans | Format-List

        <#
AssignedDateTime     : 2019-06-10 12:53:08
CapabilityStatus     : Deleted
Service              : Sway
ServicePlanId        : a23b959c-7ce8-4e57-9140-b90eb88a9e97
AdditionalProperties : {}

AssignedDateTime     : 2019-06-10 12:53:08
CapabilityStatus     : Deleted
Service              : YammerEnterprise
ServicePlanId        : 7547a3fe-08ee-4ccb-b430-5077c5041653
AdditionalProperties : {}
            #>

        #}
    }

    # return $AllUsers | Select-Object -Property $Properties
}