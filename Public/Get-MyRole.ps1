function Get-MyRole {
    [CmdletBinding()]
    param(
        [switch] $OnlyWithMembers
    )
    $Users = Get-MgUser -All
    #$Apps = Get-MgApplication -All
    $Groups = Get-MgGroup -All
    $ServicePrincipals = Get-MgServicePrincipal -All
    #$DirectoryRole = Get-MgDirectoryRole -All
    $Roles = Get-MgRoleManagementDirectoryRoleDefinition -All
    $RolesAssignement = Get-MgRoleManagementDirectoryRoleAssignment -All #-ExpandProperty "principal"
    $EligibilityAssignement = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All

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
                $TemporaryRole = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $Role.RoleDefinitionId
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
                    $GroupMembers = Get-MgGroupMember -GroupId $Group.Id -All
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