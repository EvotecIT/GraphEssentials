function Get-MyRole {
    <#
    .SYNOPSIS
    Retrieves Azure AD directory roles and their assignments.

    .DESCRIPTION
    Gets detailed information about Azure AD/Entra ID directory roles, including role assignments
    for users, groups, and service principals. Categorizes assignments as direct or eligible
    and provides statistics about the number of members in each role.

    .PARAMETER OnlyWithMembers
    When specified, returns only roles that have at least one member (direct or eligible).

    .EXAMPLE
    Get-MyRole
    Returns all Azure AD directory roles along with member information.

    .EXAMPLE
    Get-MyRole -OnlyWithMembers
    Returns only Azure AD directory roles that have at least one member assigned.

    .NOTES
    This function requires the Microsoft.Graph.Identity.Governance module and appropriate permissions.
    Typically requires RoleManagement.Read.Directory or Directory.Read.All permissions.
    #>
    [CmdletBinding()]
    param(
        [switch] $OnlyWithMembers
    )
    # $Users = Get-MgUser -All
    # #$Apps = Get-MgApplication -All
    # $Groups = Get-MgGroup -All -Filter "IsAssignableToRole eq true"
    # $ServicePrincipals = Get-MgServicePrincipal -All
    # #$DirectoryRole = Get-MgDirectoryRole -All
    # $Roles = Get-MgRoleManagementDirectoryRoleDefinition -All
    # $RolesAssignement = Get-MgRoleManagementDirectoryRoleAssignment -All #-ExpandProperty "principal"
    # $EligibilityAssignement = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All

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
        $CacheUsersAndApps[$User.Id] = $User
    }
    foreach ($ServicePrincipal in $ServicePrincipals) {
        $CacheUsersAndApps[$ServicePrincipal.Id] = $ServicePrincipal
    }
    foreach ($Group in $Groups) {
        $CacheUsersAndApps[$Group.Id] = $Group
    }


    $CacheRoles = [ordered] @{}
    foreach ($Role in $Roles) {
        $CacheRoles[$Role.Id] = [ordered] @{
            Role              = $Role
            Direct            = [System.Collections.Generic.List[object]]::new()
            Eligible          = [System.Collections.Generic.List[object]]::new()
            Users             = [System.Collections.Generic.List[object]]::new()
            ServicePrincipals = [System.Collections.Generic.List[object]]::new()
            Groups            = [System.Collections.Generic.List[object]]::new()
        }
    }

    foreach ($Role in $RolesAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheRoles[$Role.RoleDefinitionId].Direct.Add($CacheUsersAndApps[$Role.PrincipalId])
            if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphUser') {
                $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
            } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphGroup') {
                $CacheRoles[$Role.RoleDefinitionId].Groups.Add($CacheUsersAndApps[$Role.PrincipalId])
            } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphServicePrincipal') {
                $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
            } else {
                Write-Warning -Message "Unknown type for principal id $($Role.PrincipalId) - not supported yet!"
            }
            # MicrosoftGraphServicePrincipal, MicrosoftGraphUser,MicrosoftGraphGroup
        } else {
            try {
                $TemporaryRole = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $Role.RoleDefinitionId -ErrorAction Stop
            } catch {
                Write-Warning -Message "Role $($Role.RoleDefinitionId) was not found. Using direct query failed."
            }
            if ($TemporaryRole) {
                Write-Verbose -Message "Role $($Role.RoleDefinitionId) was not found. Using direct query revealed $($TemporaryRole.DisplayName)."
                $CacheRoles[$Role.RoleDefinitionId] = [ordered] @{
                    Role              = $TemporaryRole
                    Direct            = [System.Collections.Generic.List[object]]::new()
                    Eligible          = [System.Collections.Generic.List[object]]::new()
                    Users             = [System.Collections.Generic.List[object]]::new()
                    ServicePrincipals = [System.Collections.Generic.List[object]]::new()
                    Groups            = [System.Collections.Generic.List[object]]::new()
                }
                $CacheRoles[$Role.RoleDefinitionId].Direct.Add($CacheUsersAndApps[$Role.PrincipalId])
                if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphUser') {
                    $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
                } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphGroup') {
                    $CacheRoles[$Role.RoleDefinitionId].Groups.Add($CacheUsersAndApps[$Role.PrincipalId])
                } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphServicePrincipal') {
                    $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
                } else {
                    Write-Warning -Message "Unknown type for principal id $($Role.PrincipalId) - not supported yet!"
                }
            }
        }
    }

    foreach ($Role in $EligibilityAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheRoles[$Role.RoleDefinitionId].Eligible.Add($CacheUsersAndApps[$Role.PrincipalId])
            if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphUser') {
                $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
            } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphGroup') {
                $CacheRoles[$Role.RoleDefinitionId].Groups.Add($CacheUsersAndApps[$Role.PrincipalId])
            } elseif ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphServicePrincipal') {
                $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
            } else {
                Write-Warning -Message "Unknown type for principal id $($Role.PrincipalId) - not supported yet!"
            }
        } else {
            Write-Warning -Message $Role
        }
    }
    # lets get group members of groups we have members in and roles are there too
    $CacheGroupMembers = [ordered] @{}
    foreach ($Role in $CacheRoles.Keys) {
        if ($CacheRoles[$Role].Groups.Count -gt 0) {
            foreach ($Group in $CacheRoles[$Role].Groups) {
                if (-not $CacheGroupMembers[$Group.DisplayName]) {
                    $CacheGroupMembers[$Group.DisplayName] = [System.Collections.Generic.List[object]]::new()
                    $GroupMembers = Get-MgGroupMember -GroupId $Group.Id -All #-ErrorAction Stop
                    foreach ($GroupMember in $GroupMembers) {
                        $CacheGroupMembers[$Group.DisplayName].Add($CacheUsersAndApps[$GroupMember.Id])
                    }
                }
            }
        }
    }

    foreach ($Role in $CacheRoles.Keys) {
        if ($OnlyWithMembers) {
            if ($CacheRoles[$Role].Direct.Count -eq 0 -and $CacheRoles[$Role].Eligible.Count -eq 0) {
                continue
            }
        }
        $GroupMembersTotal = 0
        foreach ($Group in $CacheRoles[$Role].Groups) {
            $GroupMembersTotal = + $CacheGroupMembers[$Group.DisplayName].Count
        }
        [PSCustomObject] @{
            Name                   = $CacheRoles[$Role].Role.DisplayName
            Description            = $CacheRoles[$Role].Role.Description
            IsBuiltin              = $CacheRoles[$Role].Role.IsBuiltIn
            IsEnabled              = $CacheRoles[$Role].Role.IsEnabled
            AllowedResourceActions = $CacheRoles[$Role].Role.RolePermissions[0].AllowedResourceActions.Count
            TotalMembers           = $CacheRoles[$Role].Direct.Count + $CacheRoles[$Role].Eligible.Count + $GroupMembersTotal
            DirectMembers          = $CacheRoles[$Role].Direct.Count
            EligibleMembers        = $CacheRoles[$Role].Eligible.Count
            GroupsMembers          = $GroupMembersTotal
            # here's a split by numbers
            Users                  = $CacheRoles[$Role].Users.Count
            ServicePrincipals      = $CacheRoles[$Role].ServicePrincipals.Count
            Groups                 = $CacheRoles[$Role].Groups.Count
        }
    }
}