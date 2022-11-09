﻿function Get-MyRoleUsers {
    [CmdletBinding()]
    param(
        [switch] $OnlyWithRoles,
        [switch] $RolePerColumn
    )
    $Users = Get-MgUser -All -Property DisplayName, 'AccountEnabled', 'Mail', 'UserPrincipalName', 'Id'
    #$Apps = Get-MgApplication -All
    $ServicePrincipals = Get-MgServicePrincipal -All
    #$DirectoryRole = Get-MgDirectoryRole -All
    $Roles = Get-MgRoleManagementDirectoryRoleDefinition -All
    $RolesAssignement = Get-MgRoleManagementDirectoryRoleAssignment -All #-ExpandProperty "principal"
    $EligibilityAssignement = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All

    $CacheUsersAndApps = [ordered] @{}
    foreach ($User in $Users) {
        $CacheUsersAndApps[$User.Id] = @{
            Identity = $User
            Roles    = [System.Collections.Generic.List[object]]::new()
            Eligible = [System.Collections.Generic.List[object]]::new()
        }
    }
    foreach ($ServicePrincipal in $ServicePrincipals) {
        $CacheUsersAndApps[$ServicePrincipal.Id] = @{
            Identity = $ServicePrincipal
            Roles    = [System.Collections.Generic.List[object]]::new()
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
        }
    }

    foreach ($Role in $RolesAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheUsersAndApps[$Role.PrincipalId].Roles.Add($CacheRoles[$Role.RoleDefinitionId].Role)
        } else {
            try {
                $TemporaryRole = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $Role.RoleDefinitionId
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
                $CacheUsersAndApps[$Role.PrincipalId].Roles.Add($CacheRoles[$Role.RoleDefinitionId].Role)
            }
        }
    }
    foreach ($Role in $EligibilityAssignement) {
        if ($CacheRoles[$Role.RoleDefinitionId]) {
            $CacheUsersAndApps[$Role.PrincipalId].Eligible.Add($CacheRoles[$Role.RoleDefinitionId].Role)
        } else {
            Write-Warning -Message $Role
        }
    }
    $ListActiveRoles = foreach ($Identity in $CacheUsersAndApps.Keys) {
        if ($OnlyWithRoles) {
            if ($CacheUsersAndApps[$Identity].Roles.Count -eq 0 -and $CacheUsersAndApps[$Identity].Eligible.Count -eq 0) {
                continue
            }
            $CacheUsersAndApps[$Identity].Roles.DisplayName
            $CacheUsersAndApps[$Identity].Eligible.DisplayName
        }
    }

    foreach ($Identity in $CacheUsersAndApps.Keys) {
        if ($OnlyWithRoles) {
            if ($CacheUsersAndApps[$Identity].Roles.Count -eq 0 -and $CacheUsersAndApps[$Identity].Eligible.Count -eq 0) {
                continue
            }
        }

        if (-not $RolePerColumn) {
            [PSCustomObject] @{
                Name              = $CacheUsersAndApps[$Identity].Identity.DisplayName
                Enabled           = $CacheUsersAndApps[$Identity].Identity.AccountEnabled
                Mail              = $CacheUsersAndApps[$Identity].Identity.Mail
                UserPrincipalName = $CacheUsersAndApps[$Identity].Identity.UserPrincipalName
                DirectCount       = $CacheUsersAndApps[$Identity].Roles.Count
                EligibleCount     = $CacheUsersAndApps[$Identity].Eligible.Count
                Direct            = $CacheUsersAndApps[$Identity].Roles.DisplayName
                Eligible          = $CacheUsersAndApps[$Identity].Eligible.DisplayName
            }
        } else {
            $UserIdentity = [ordered] @{
                Name              = $CacheUsersAndApps[$Identity].Identity.DisplayName
                Enabled           = $CacheUsersAndApps[$Identity].Identity.AccountEnabled
                Mail              = $CacheUsersAndApps[$Identity].Identity.Mail
                UserPrincipalName = $CacheUsersAndApps[$Identity].Identity.UserPrincipalName
            }
            foreach ($Role in $ListActiveRoles | Sort-Object -Unique) {
                $UserIdentity[$Role] = ''
            }
            foreach ($Role in $CacheUsersAndApps[$Identity].Eligible) {
                $UserIdentity[$Role.DisplayName] = 'Eligible'
            }
            foreach ($Role in $CacheUsersAndApps[$Identity].Roles) {
                $UserIdentity[$Role.DisplayName] = 'Direct'
            }
            [PSCustomObject] $UserIdentity
        }
    }


}