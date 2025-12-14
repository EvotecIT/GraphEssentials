@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2025 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'GraphEssentials is a PowerShell module that helps with Office 365 / Azure AD using mostly Graph'
    FunctionsToExport    = @('Get-MgToken', 'Get-MyApp', 'Get-MyAppCredentials', 'Get-MyConditionalAccess', 'Get-MyDefenderDeploymentKey', 'Get-MyDefenderHealthIssues', 'Get-MyDefenderSecureScore', 'Get-MyDefenderSecureScoreProfile', 'Get-MyDefenderSensor', 'Get-MyDefenderSummary', 'Get-MyDevice', 'Get-MyDeviceIntune', 'Get-MyLicense', 'Get-MyRole', 'Get-MyRoleHistory', 'Get-MyRoleUsers', 'Get-MyTeam', 'Get-MyTenantName', 'Get-MyUsageReports', 'Get-MyUser', 'Get-MyUserAuthentication', 'Invoke-MyGraphEssentials', 'Invoke-MyGraphUsageReports', 'New-MyApp', 'New-MyAppCredentials', 'Register-FIDO2Key', 'Remove-MyAppCredentials', 'Send-MyApp', 'Show-MyApp', 'Show-MyConditionalAccess', 'Show-MyDefender', 'Show-MyRole', 'Show-MyUserAuthentication')
    GUID                 = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
    ModuleVersion        = '0.0.53'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            RequireLicenseAcceptance = $false
            Tags                     = @('Windows')
        }
    }
    RequiredModules      = @(@{
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
            ModuleName    = 'PSSharedGoods'
            ModuleVersion = '0.0.312'
        }, @{
            Guid          = '0b0ba5c5-ec85-4c2b-a718-874e55a8bc3f'
            ModuleName    = 'PSWriteColor'
            ModuleVersion = '1.0.4'
        }, @{
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
            ModuleName    = 'PSWriteHTML'
            ModuleVersion = '1.39.0'
        }, @{
            Guid          = '883916f2-9184-46ee-b1f8-b6a2fb784cee'
            ModuleName    = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '467f54f2-44a8-4993-8e75-b96c3e443098'
            ModuleName    = 'Microsoft.Graph.Applications'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = 'c767240d-585c-42cb-bb2f-6e76e6d639d4'
            ModuleName    = 'Microsoft.Graph.Identity.DirectoryManagement'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '530fc574-049c-42cc-810e-8835853204b7'
            ModuleName    = 'Microsoft.Graph.Identity.Governance'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '60f889fa-f873-43ad-b7d3-b7fc1273a44f'
            ModuleName    = 'Microsoft.Graph.Identity.SignIns'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = 'cb05f22d-85cd-4b42-b99c-b713e0b9fbd3'
            ModuleName    = 'Microsoft.Graph.DeviceManagement.Enrollment'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '71150504-37a3-48c6-82c7-7a00a12168db'
            ModuleName    = 'Microsoft.Graph.Users'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '50bc9e18-e281-4208-8913-c9e1bef6083d'
            ModuleName    = 'Microsoft.Graph.Groups'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '4131557d-8635-4903-9cfd-d59ddef4a597'
            ModuleName    = 'Microsoft.Graph.DeviceManagement'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = 'f8619bb2-8640-4d8d-baf5-0829db98fbe2'
            ModuleName    = 'Microsoft.Graph.Teams'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '987c645b-9ff9-4398-8963-19739c27f5c3'
            ModuleName    = 'Microsoft.Graph.Beta.Security'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '0bfc88b7-a8ad-471a-8c86-5f0aa3c84217'
            ModuleName    = 'Microsoft.Graph.Reports'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '51fa7a02-1099-4183-b155-e14ffb788a3c'
            ModuleName    = 'Microsoft.Graph.Beta.Reports'
            ModuleVersion = '2.25.0'
        }, @{
            Guid          = '2b0ea9f1-3ff1-4300-b939-106d5da608fa'
            ModuleName    = 'Mailozaurr'
            ModuleVersion = '1.0.0'
        })
    RootModule           = 'GraphEssentials.psm1'
}