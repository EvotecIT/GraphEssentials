@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2023 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'GraphEssentials is a PowerShell module that helps with Office 365 / Azure AD using mostly Graph'
    FunctionsToExport    = @('Get-MgToken', 'Get-MyApp', 'Get-MyAppCredentials', 'Get-MyDevice', 'Get-MyDeviceIntune', 'Get-MyLicense', 'Get-MyRole', 'Get-MyRoleUsers', 'Get-MyTeam', 'Get-MyUsageReports', 'Get-MyUser', 'Invoke-MyGraphEssentials', 'Invoke-MyGraphUsageReports', 'New-MyApp', 'New-MyAppCredentials', 'Remove-MyAppCredentials', 'Send-MyApp', 'Show-MyApp')
    GUID                 = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
    ModuleVersion        = '0.0.31'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            Tags                       = @('Windows')
            ExternalModuleDependencies = @('Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security')
        }
    }
    RequiredModules      = @(@{
            ModuleName    = 'PSSharedGoods'
            ModuleVersion = '0.0.264'
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
        }, @{
            ModuleName    = 'PSWriteColor'
            ModuleVersion = '1.0.1'
            Guid          = '0b0ba5c5-ec85-4c2b-a718-874e55a8bc3f'
        }, @{
            ModuleName    = 'Microsoft.Graph.Applications'
            ModuleVersion = '1.28.0'
            Guid          = '467f54f2-44a8-4993-8e75-b96c3e443098'
        }, @{
            ModuleName    = 'Microsoft.Graph.Identity.DirectoryManagement'
            ModuleVersion = '1.28.0'
            Guid          = 'c767240d-585c-42cb-bb2f-6e76e6d639d4'
        }, @{
            ModuleName    = 'PSWriteHTML'
            ModuleVersion = '0.0.191'
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
        }, @{
            ModuleName    = 'Microsoft.Graph.DeviceManagement.Enrolment'
            ModuleVersion = '1.28.0'
            Guid          = '447dd5b5-a01b-45bb-a55c-c9ecce3e820f'
        }, @{
            ModuleName    = 'Microsoft.Graph.Users'
            ModuleVersion = '1.28.0'
            Guid          = '71150504-37a3-48c6-82c7-7a00a12168db'
        }, @{
            ModuleName    = 'Microsoft.Graph.Groups'
            ModuleVersion = '1.28.0'
            Guid          = '50bc9e18-e281-4208-8913-c9e1bef6083d'
        }, @{
            ModuleName    = 'Microsoft.Graph.DeviceManagement'
            ModuleVersion = '1.28.0'
            Guid          = '4131557d-8635-4903-9cfd-d59ddef4a597'
        }, @{
            ModuleName    = 'Microsoft.Graph.Teams'
            ModuleVersion = '1.28.0'
            Guid          = 'f8619bb2-8640-4d8d-baf5-0829db98fbe2'
        }, @{
            ModuleName    = 'O365Essentials'
            ModuleVersion = '0.0.11'
            Guid          = 'a8752d7b-17c8-41db-b3f9-b8f225de028d'
        }, @{
            ModuleName    = 'Mailozaurr'
            ModuleVersion = '1.0.0'
            Guid          = '2b0ea9f1-3ff1-4300-b939-106d5da608fa'
        }, 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security')
    RootModule           = 'GraphEssentials.psm1'
}