function Get-MyRole {
    [CmdletBinding()]
    param(
        [switch] $OnlyWithMembers
    )
    $Users = Get-MgUser -All
    #$Apps = Get-MgApplication -All
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


    $CacheRoles = [ordered] @{}
    foreach ($Role in $Roles) {
        $CacheRoles[$Role.Id] = [ordered] @{
            Role              = $Role
            Direct            = [System.Collections.Generic.List[object]]::new()
            Eligible          = [System.Collections.Generic.List[object]]::new()
            Users             = [System.Collections.Generic.List[object]]::new()
            ServicePrincipals = [System.Collections.Generic.List[object]]::new()
        }
    }

    foreach ($Role in $RolesAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheRoles[$Role.RoleDefinitionId].Direct.Add($CacheUsersAndApps[$Role.PrincipalId])
            if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -eq 'MicrosoftGraphServicePrincipal') {
                $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
            } else {
                $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
            }
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
                }
                $CacheRoles[$Role.RoleDefinitionId].Direct.Add($CacheUsersAndApps[$Role.PrincipalId])
                if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -ne 'MicrosoftGraphServicePrincipal') {
                    $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
                } else {
                    $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
                }
            }
        }
    }

    foreach ($Role in $EligibilityAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheRoles[$Role.RoleDefinitionId].Eligible.Add($CacheUsersAndApps[$Role.PrincipalId])
            if ($CacheUsersAndApps[$Role.PrincipalId].GetType().Name -ne 'MicrosoftGraphServicePrincipal') {
                $CacheRoles[$Role.RoleDefinitionId].Users.Add($CacheUsersAndApps[$Role.PrincipalId])
            } else {
                $CacheRoles[$Role.RoleDefinitionId].ServicePrincipals.Add($CacheUsersAndApps[$Role.PrincipalId])
            }
        } else {
            Write-Warning -Message $Role
        }
    }

    foreach ($Role in $CacheRoles.Keys) {
        if ($OnlyWithMembers) {
            if ($CacheRoles[$Role].Direct.Count -eq 0 -and $CacheRoles[$Role].Eligible.Count -eq 0) {
                continue
            }
        }
        [PSCustomObject] @{
            Name                   = $CacheRoles[$Role].Role.DisplayName
            Description            = $CacheRoles[$Role].Role.Description
            IsBuiltin              = $CacheRoles[$Role].Role.IsBuiltIn
            IsEnabled              = $CacheRoles[$Role].Role.IsEnabled
            AllowedResourceActions = $CacheRoles[$Role].Role.RolePermissions[0].AllowedResourceActions.Count
            DirectMembers          = $CacheRoles[$Role].Direct.Count
            EligibleMembers        = $CacheRoles[$Role].Eligible.Count
            Users                  = $CacheRoles[$Role].Users.Count
            ServicePrincipals      = $CacheRoles[$Role].ServicePrincipals.Count
        }
    }
}