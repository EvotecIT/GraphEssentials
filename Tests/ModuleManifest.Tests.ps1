Describe 'GraphEssentials module manifest' {
    BeforeAll {
        $testDirectory = Split-Path -Parent $PSCommandPath
        $modulePath = Resolve-Path (Join-Path $testDirectory '..\GraphEssentials.psd1')
        $moduleManifest = Import-PowerShellDataFile -Path $modulePath
    }

    It 'defines the expected root module' {
        $moduleManifest.RootModule | Should -Be 'GraphEssentials.psm1'
    }

    It 'exports key public commands' {
        $moduleManifest.FunctionsToExport | Should -Contain 'Get-MyRoleHistory'
        $moduleManifest.FunctionsToExport | Should -Contain 'Get-MyUserAuthentication'
        $moduleManifest.FunctionsToExport | Should -Contain 'Show-MyRole'
    }

    It 'declares Graph dependencies' {
        $moduleManifest.RequiredModules.ModuleName | Should -Contain 'Microsoft.Graph.Authentication'
        $moduleManifest.RequiredModules.ModuleName | Should -Contain 'Microsoft.Graph.Identity.Governance'
    }
}
