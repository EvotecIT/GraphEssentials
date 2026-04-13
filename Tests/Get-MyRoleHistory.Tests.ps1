BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-GraphEssentialsErrorDetails.ps1')
    . (Join-Path $PSScriptRoot '..\Private\Write-RoleHistoryWarning.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-MyRoleHistory.ps1')

    foreach ($commandName in @(
            'Get-MgUser'
            'Get-MgGroup'
            'Get-MgServicePrincipal'
            'Get-MgRoleManagementDirectoryRoleDefinition'
            'Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest'
            'Get-MgRoleManagementDirectoryRoleEligibilityScheduleRequest'
        )) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            Set-Item -Path ("Function:\" + $commandName) -Value { throw 'Test stub should be mocked.' }
        }
    }
}

Describe 'Get-MyRoleHistory' {
    BeforeEach {
        Mock -CommandName Get-MgUser -MockWith { @() }
        Mock -CommandName Get-MgGroup -MockWith { @() }
        Mock -CommandName Get-MgServicePrincipal -MockWith { @() }
        Mock -CommandName Get-MgRoleManagementDirectoryRoleDefinition -MockWith { @() }
        Mock -CommandName Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -MockWith {
            throw [System.Exception]::new(@'
Status: 403 (Forbidden)
ErrorCode: UnknownError
{"errorCode":"PermissionScopeNotGranted","message":"Authorization failed due to missing permission scopes"}
'@)
        }
        Mock -CommandName Get-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -MockWith {
            throw [System.Exception]::new(@'
Status: 403 (Forbidden)
ErrorCode: UnknownError
{"errorCode":"PermissionScopeNotGranted","message":"Authorization failed due to missing permission scopes"}
'@)
        }
    }

    It 'returns no history instead of terminating when PIM history permissions are missing' {
        $warnings = $null
        $result = Get-MyRoleHistory -DaysBack 7 -WarningVariable warnings -WarningAction SilentlyContinue

        @($result).Count | Should -Be 0
        ($warnings -join ' ') | Should -Match 'Missing Microsoft Graph application permission'
    }
}
