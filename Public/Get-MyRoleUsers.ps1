function Get-MyRoleUsers {
    <#
    .SYNOPSIS
    Retrieves detailed information about users assigned to Azure AD roles.

    .DESCRIPTION
    Gets comprehensive information about Azure AD/Entra ID role assignments and eligible assignments,
    including direct assignments and assignments through groups. The data can be presented in different formats
    to facilitate analysis of role assignments across your tenant.

    .PARAMETER OnlyWithRoles
    When specified, returns only users who have at least one role assignment.

    .PARAMETER RolePerColumn
    When specified, changes the output format to have each role as a column instead of as rows.
    This creates a matrix view with users on rows and roles on columns.

    .EXAMPLE
    Get-MyRoleUsers
    Returns all users with their role assignments in the default format.

    .EXAMPLE
    Get-MyRoleUsers -OnlyWithRoles
    Returns only users who have at least one role assignment.

    .EXAMPLE
    Get-MyRoleUsers -RolePerColumn
    Returns users with their role assignments in a matrix format with roles as columns.

    .NOTES
    This function requires the Microsoft.Graph.Identity.Governance module and appropriate permissions.
    Typically requires RoleManagement.Read.Directory or Directory.Read.All permissions.
    #>
    [CmdletBinding()]
    param(
        [switch] $OnlyWithRoles,
        [switch] $RolePerColumn
    )
    $ErrorsCount = 0
    try {
        $Users = Get-MgUser -ErrorAction Stop -All -Property DisplayName, CreatedDateTime, 'AccountEnabled', 'Mail', 'UserPrincipalName', 'Id', 'UserType', 'OnPremisesDistinguishedName', 'OnPremisesSamAccountName', 'OnPremisesLastSyncDateTime', 'OnPremisesSyncEnabled', 'OnPremisesUserPrincipalName'
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get users. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    try {
        $Groups = Get-MgGroup -ErrorAction Stop -All -Filter "IsAssignableToRole eq true" -Property CreatedDateTime, Id, DisplayName, Mail, OnPremisesLastSyncDateTime, SecurityEnabled
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get groups. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    #$Apps = Get-MgApplication -All
    try {
        $ServicePrincipals = Get-MgServicePrincipal -ErrorAction Stop -All -Property CreatedDateTime, 'ServicePrincipalType', 'DisplayName', 'AccountEnabled', 'Id', 'AppID'
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get service principals. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    #$DirectoryRole = Get-MgDirectoryRole -All
    try {
        $Roles = Get-MgRoleManagementDirectoryRoleDefinition -ErrorAction Stop -All
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get roles. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    try {
        $RolesAssignement = Get-MgRoleManagementDirectoryRoleAssignment -ErrorAction Stop -All #-ExpandProperty "principal"
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get roles assignement. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    try {
        $EligibilityAssignement = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ErrorAction Stop -All
    } catch {
        Write-Warning -Message "Get-MyRoleUsers - Failed to get eligibility assignement. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }
    if ($ErrorsCount -gt 0) {
        return
    }

    $CacheUsersAndApps = [ordered] @{}
    foreach ($User in $Users) {
        $CacheUsersAndApps[$User.Id] = @{
            Identity = $User
            Direct   = [System.Collections.Generic.List[object]]::new()
            Eligible = [System.Collections.Generic.List[object]]::new()
        }
    }
    foreach ($ServicePrincipal in $ServicePrincipals) {
        $CacheUsersAndApps[$ServicePrincipal.Id] = @{
            Identity = $ServicePrincipal
            Direct   = [System.Collections.Generic.List[object]]::new()
            Eligible = [System.Collections.Generic.List[object]]::new()
        }
    }
    foreach ($Group in $Groups) {
        $CacheUsersAndApps[$Group.Id] = @{
            Identity = $Group
            Direct   = [System.Collections.Generic.List[object]]::new()
            Eligible = [System.Collections.Generic.List[object]]::new()
        }
    }

    $CacheRoles = [ordered] @{}
    foreach ($Role in $Roles) {
        $CacheRoles[$Role.Id] = [ordered] @{
            Role              = $Role
            Members           = [System.Collections.Generic.List[object]]::new()
            Users             = [System.Collections.Generic.List[object]]::new()
            ServicePrincipals = [System.Collections.Generic.List[object]]::new()
            GroupsDirect      = [System.Collections.Generic.List[object]]::new()
            GroupsEligible    = [System.Collections.Generic.List[object]]::new()
        }
    }

    foreach ($Role in $RolesAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheUsersAndApps[$Role.PrincipalId].Direct.Add($CacheRoles[$Role.RoleDefinitionId].Role)
            if ($CacheUsersAndApps[$Role.PrincipalId].Identity.GetType().Name -eq 'MicrosoftGraphGroup') {
                $CacheRoles[$Role.RoleDefinitionId].GroupsDirect.Add($CacheUsersAndApps[$Role.PrincipalId].Identity)
            }
        } else {
            try {
                $TemporaryRole = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $Role.RoleDefinitionId -ErrorAction Stop
            } catch {
                Write-Warning -Message "Role $($Role.RoleDefinitionId) was not found. Using direct query failed."
            }
            if ($TemporaryRole) {
                Write-Verbose -Message "Role $($Role.RoleDefinitionId) was not found. Using direct query revealed $($TemporaryRole.DisplayName)."
                if (-not $CacheRoles[$Role.RoleDefinitionId]) {
                    $CacheRoles[$Role.RoleDefinitionId] = [ordered] @{
                        Role              = $TemporaryRole
                        Direct            = [System.Collections.Generic.List[object]]::new()
                        Eligible          = [System.Collections.Generic.List[object]]::new()
                        Users             = [System.Collections.Generic.List[object]]::new()
                        ServicePrincipals = [System.Collections.Generic.List[object]]::new()
                    }
                }
                $CacheUsersAndApps[$Role.PrincipalId].Direct.Add($CacheRoles[$Role.RoleDefinitionId].Role)
            }
        }
    }
    foreach ($Role in $EligibilityAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheUsersAndApps[$Role.PrincipalId].Eligible.Add($CacheRoles[$Role.RoleDefinitionId].Role)
            if ($CacheUsersAndApps[$Role.PrincipalId].Identity.GetType().Name -eq 'MicrosoftGraphGroup') {
                $CacheRoles[$Role.RoleDefinitionId].GroupsEligible.Add($CacheUsersAndApps[$Role.PrincipalId].Identity)
            }
        } else {
            Write-Warning -Message $Role
        }
    }
    $ListActiveRoles = foreach ($Identity in $CacheUsersAndApps.Keys) {
        if ($OnlyWithRoles) {
            if ($CacheUsersAndApps[$Identity].Direct.Count -eq 0 -and $CacheUsersAndApps[$Identity].Eligible.Count -eq 0) {
                continue
            }
            $CacheUsersAndApps[$Identity].Direct.DisplayName
            $CacheUsersAndApps[$Identity].Eligible.DisplayName
        }
    }

    # lets get group members of groups we have members in and roles are there too
    $CacheGroupMembers = [ordered] @{}
    $CacheUserMembers = [ordered] @{}
    foreach ($Role in $CacheRoles.Keys) {
        if ($CacheRoles[$Role].GroupsDirect.Count -gt 0) {
            foreach ($Group in $CacheRoles[$Role].GroupsDirect) {
                if (-not $CacheGroupMembers[$Group.DisplayName]) {
                    $CacheGroupMembers[$Group.DisplayName] = [ordered] @{
                        Group   = $Group
                        Members = Get-MgGroupMember -GroupId $Group.Id -All
                    }
                }
                foreach ($GroupMember in $CacheGroupMembers[$Group.DisplayName].Members) {
                    #$CacheGroupMembers[$Group.DisplayName].Add($CacheUsersAndApps[$GroupMember.Id])
                    if (-not $CacheUserMembers[$GroupMember.Id]) {
                        $CacheUserMembers[$GroupMember.Id] = [ordered] @{
                            Identity = $GroupMember
                            Role     = [ordered] @{}
                            #Direct   = [System.Collections.Generic.List[object]]::new()
                            #Eligible = [System.Collections.Generic.List[object]]::new()
                        }
                    }
                    #$CacheUserMembers[$GroupMember.Id].Direct.Add($Group)
                    $RoleDisplayName = $CacheRoles[$Role].Role.DisplayName
                    if (-not $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName]) {
                        $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName] = [ordered] @{
                            Role           = $CacheRoles[$Role].Role
                            GroupsDirect   = [System.Collections.Generic.List[object]]::new()
                            GroupsEligible = [System.Collections.Generic.List[object]]::new()
                        }
                    }
                    $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName].GroupsDirect.Add($Group)
                }
            }
        }
        if ($CacheRoles[$Role].GroupsEligible.Count -gt 0) {
            foreach ($Group in $CacheRoles[$Role].GroupsEligible) {
                if (-not $CacheGroupMembers[$Group.DisplayName]) {
                    $CacheGroupMembers[$Group.DisplayName] = [ordered] @{
                        Group   = $Group
                        Members = Get-MgGroupMember -GroupId $Group.Id -All
                    }
                }
                foreach ($GroupMember in $CacheGroupMembers[$Group.DisplayName].Members) {
                    if (-not $CacheUserMembers[$GroupMember.Id]) {
                        $CacheUserMembers[$GroupMember.Id] = [ordered] @{
                            Identity = $GroupMember
                            Role     = [ordered] @{}
                            #Direct   = [System.Collections.Generic.List[object]]::new()
                            #Eligible = [System.Collections.Generic.List[object]]::new()
                        }
                    }
                    $RoleDisplayName = $CacheRoles[$Role].Role.DisplayName
                    if (-not $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName]) {
                        $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName] = [ordered] @{
                            Role           = $CacheRoles[$Role].Role
                            GroupsDirect   = [System.Collections.Generic.List[object]]::new()
                            GroupsEligible = [System.Collections.Generic.List[object]]::new()
                        }
                    }
                    $CacheUserMembers[$GroupMember.Id]['Role'][$RoleDisplayName].GroupsEligible.Add($Group)
                    #$CacheUserMembers[$GroupMember.Id].Eligible.Add($Group)
                }
                #}
            }
        }
    }
    foreach ($Identity in $CacheUsersAndApps.Keys) {
        $Type = if ($CacheUsersAndApps[$Identity].Identity.ServicePrincipalType) {
            $CacheUsersAndApps[$Identity].Identity.ServicePrincipalType
        } elseif ($CacheUsersAndApps[$Identity].Identity.UserType) {
            $CacheUsersAndApps[$Identity].Identity.UserType
        } elseif ($null -ne $CacheUsersAndApps[$Identity].Identity.SecurityEnabled) {
            if ($CacheUsersAndApps[$Identity].Identity.SecurityEnabled) {
                "SecurityGroup"
            } else {
                "DistributionGroup"
            }
        } else {
            "Unknown"
        }
        $IsSynced = if ($CacheUsersAndApps[$Identity].Identity.OnPremisesLastSyncDateTime) {
            'Synchronized'
        } else {
            'Online'
        }
        $CanonicalName = if ($CacheUsersAndApps[$Identity].Identity.OnPremisesDistinguishedName) {
            ConvertFrom-DistinguishedName -DistinguishedName $CacheUsersAndApps[$Identity].Identity.OnPremisesDistinguishedName -ToOrganizationalUnit
        } else {
            $null
        }

        if (-not $RolePerColumn) {
            if ($OnlyWithRoles) {
                if ($CacheUsersAndApps[$Identity].Direct.Count -eq 0 -and $CacheUsersAndApps[$Identity].Eligible.Count -eq 0) {
                   continue
                }
            }
            [PSCustomObject] @{
                Name              = $CacheUsersAndApps[$Identity].Identity.DisplayName
                Enabled           = $CacheUsersAndApps[$Identity].Identity.AccountEnabled
                Status            = $IsSynced
                Type              = $Type
                CreatedDateTime   = $CacheUsersAndApps[$Identity].Identity.CreatedDateTime
                Mail              = $CacheUsersAndApps[$Identity].Identity.Mail
                UserPrincipalName = $CacheUsersAndApps[$Identity].Identity.UserPrincipalName
                AppId             = $CacheUsersAndApps[$Identity].Identity.AppID
                DirectCount       = $CacheUsersAndApps[$Identity].Direct.Count
                EligibleCount     = $CacheUsersAndApps[$Identity].Eligible.Count
                Direct            = $CacheUsersAndApps[$Identity].Direct.DisplayName
                Eligible          = $CacheUsersAndApps[$Identity].Eligible.DisplayName
                Location          = $CanonicalName

                #OnPremisesSamAccountName    = $CacheUsersAndApps[$Identity].Identity.OnPremisesSamAccountName
                #OnPremisesLastSyncDateTime  = $CacheUsersAndApps[$Identity].Identity.OnPremisesLastSyncDateTime
            }
        } else {
            # we need to use different way to count roles for each user
            # this is because we also count the roles of users nested in groups
            $RolesCount = 0
            $GroupNameMember = $CacheUserMembers[$CacheUsersAndApps[$Identity].Identity.Id]
            if ($GroupNameMember) {
                # $GroupNameMember['Role']

                # $DirectRoles = $CacheUsersAndApps[$GroupNameMember.id].Direct
                # $EligibleRoles = $CacheUsersAndApps[$GroupNameMember.id].Eligible
                # $IdentityOfGroup = $CacheUsersAndApps[$GroupNameMember.id].Identity.DisplayName
            } else {
                # $DirectRoles = $null
                # $EligibleRoles = $null
                # $IdentityOfGroup = $null
            }

            $UserIdentity = [ordered] @{
                Name              = $CacheUsersAndApps[$Identity].Identity.DisplayName
                Enabled           = $CacheUsersAndApps[$Identity].Identity.AccountEnabled
                Status            = $IsSynced
                Type              = $Type
                CreatedDateTime   = $CacheUsersAndApps[$Identity].Identity.CreatedDateTime
                Mail              = $CacheUsersAndApps[$Identity].Identity.Mail
                UserPrincipalName = $CacheUsersAndApps[$Identity].Identity.UserPrincipalName
            }
            foreach ($Role in $ListActiveRoles | Sort-Object -Unique) {
                $UserIdentity[$Role] = ''
            }
            foreach ($Role in $CacheUsersAndApps[$Identity].Eligible) {
                if (-not $UserIdentity[$Role.DisplayName] ) {
                    $UserIdentity[$Role.DisplayName] = [System.Collections.Generic.List[string]]::new()
                }
                $UserIdentity[$Role.DisplayName].Add('Eligible')
                $RolesCount++
            }
            foreach ($Role in $CacheUsersAndApps[$Identity].Direct) {
                if (-not $UserIdentity[$Role.DisplayName] ) {
                    $UserIdentity[$Role.DisplayName] = [System.Collections.Generic.List[string]]::new()
                }
                $UserIdentity[$Role.DisplayName].Add('Direct')
                $RolesCount++
            }
            if ($GroupNameMember) {
                foreach ($Role in $GroupNameMember['Role'].Keys) {
                    foreach ($Group in $GroupNameMember['Role'][$Role].GroupsDirect) {
                        if (-not $UserIdentity[$Role] ) {
                            $UserIdentity[$Role] = [System.Collections.Generic.List[string]]::new()
                        }
                        $UserIdentity[$Role].Add($Group.DisplayName)
                        $RolesCount++
                    }
                    foreach ($Group in $GroupNameMember['Role'][$Role].GroupsEligible) {
                        if (-not $UserIdentity[$Role] ) {
                            $UserIdentity[$Role] = [System.Collections.Generic.List[string]]::new()
                        }
                        $UserIdentity[$Role].Add($Group.DisplayName)
                        $RolesCount++
                    }
                }
                # foreach ($Role in $DirectRoles) {
                #     if (-not $UserIdentity[$Role.DisplayName] ) {
                #         $UserIdentity[$Role.DisplayName] = [System.Collections.Generic.List[string]]::new()
                #     }
                #     $UserIdentity[$Role.DisplayName].Add($IdentityOfGroup)
                # }
                # foreach ($Role in $EligibleRoles) {
                #     if (-not $UserIdentity[$Role.DisplayName]) {
                #         $UserIdentity[$Role.DisplayName] = [System.Collections.Generic.List[string]]::new()
                #     }
                #     $UserIdentity[$Role.DisplayName].Add($IdentityOfGroup)
                # }
            }
            $UserIdentity['Location'] = $CanonicalName
            if ($OnlyWithRoles) {
                if ($RolesCount -eq 0) {
                   continue
                }
            }
            [PSCustomObject] $UserIdentity
        }
    }
}