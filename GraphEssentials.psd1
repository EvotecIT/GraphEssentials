@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2022 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'GraphEssentials is a PowerShell that help with Office 365 / Azure AD using mostly Graph'
    FunctionsToExport    = @('Get-MyApp', 'Get-MyAppCredentials', 'New-MyApp', 'New-MyAppCredentials', 'Show-MyApp')
    GUID                 = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
    ModuleVersion        = '0.0.1'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            Tags                       = @('Windows')
            ExternalModuleDependencies = @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility')
        }
    }
    RequiredModules      = @(@{
            ModuleVersion = '0.0.246'
            ModuleName    = 'PSSharedGoods'
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
        }, @{
            ModuleVersion = '1.10.0'
            ModuleName    = 'Microsoft.Graph.Applications'
            Guid          = '467f54f2-44a8-4993-8e75-b96c3e443098'
        }, @{
            ModuleVersion = '0.0.177'
            ModuleName    = 'PSWriteHTML'
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
        }, 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility')
    RootModule           = 'GraphEssentials.psm1'
}