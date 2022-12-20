@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2022 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'GraphEssentials is a PowerShell that help with Office 365 / Azure AD using mostly Graph'
    FunctionsToExport    = @('Get-MyApp', 'Get-MyAppCredentials', 'Get-MyRole', 'Get-MyRoleUsers', 'Invoke-MyGraphEssentials', 'New-MyApp', 'New-MyAppCredentials', 'Remove-MyAppCredentials', 'Send-MyApp', 'Show-MyApp')
    GUID                 = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
    ModuleVersion        = '0.0.11'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            Tags                       = @('Windows')
            ExternalModuleDependencies = @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility')
        }
    }
    RequiredModules      = @(@{
            ModuleVersion = '0.0.254'
            ModuleName    = 'PSSharedGoods'
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
        }, @{
            ModuleVersion = '1.19.0'
            ModuleName    = 'Microsoft.Graph.Applications'
            Guid          = '467f54f2-44a8-4993-8e75-b96c3e443098'
        }, @{
            ModuleVersion = '0.0.180'
            ModuleName    = 'PSWriteHTML'
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
        }, @{
            ModuleVersion = '1.19.0'
            ModuleName    = 'Microsoft.Graph.DeviceManagement.Enrolment'
            Guid          = '447dd5b5-a01b-45bb-a55c-c9ecce3e820f'
        }, @{
            ModuleVersion = '1.19.0'
            ModuleName    = 'Microsoft.Graph.Users'
            Guid          = '71150504-37a3-48c6-82c7-7a00a12168db'
        }, @{
            ModuleVersion = '1.19.0'
            ModuleName    = 'Microsoft.Graph.Groups'
            Guid          = '50bc9e18-e281-4208-8913-c9e1bef6083d'
        }, @{
            ModuleVersion = '0.0.11'
            ModuleName    = 'O365Essentials'
            Guid          = 'a8752d7b-17c8-41db-b3f9-b8f225de028d'
        }, @{
            ModuleVersion = '1.0.0'
            ModuleName    = 'Mailozaurr'
            Guid          = '2b0ea9f1-3ff1-4300-b939-106d5da608fa'
        }, 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility')
    RootModule           = 'GraphEssentials.psm1'
}