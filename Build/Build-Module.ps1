﻿Clear-Host

Invoke-ModuleBuild -ModuleName 'GraphEssentials' {
    # Usual defaults as per standard module
    $Manifest = [ordered] @{
        ModuleVersion        = '0.0.X'
        CompatiblePSEditions = @('Desktop', 'Core')
        GUID                 = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
        Author               = 'Przemyslaw Klys'
        CompanyName          = 'Evotec'
        Copyright            = "(c) 2011 - $((Get-Date).Year) Przemyslaw Klys @ Evotec. All rights reserved."
        Description          = 'GraphEssentials is a PowerShell module that helps with Office 365 / Azure AD using mostly Graph'
        PowerShellVersion    = '5.1'
        Tags                 = @('Windows')
        #IconUri              = 'https://evotec.xyz/wp-content/uploads/2023/04/CleanupMonster.png'
        #ProjectUri           = 'https://github.com/EvotecIT/CleanupMonster'
        #DotNetFrameworkVersion = '4.5.2'
    }
    New-ConfigurationManifest @Manifest

    New-ConfigurationModule -Type RequiredModule -Name @(
        'PSSharedGoods'
        'PSWriteColor'
        'PSWriteHTML'
        #'O365Essentials'
    ) -Guid Auto -Version Latest

    New-ConfigurationModule -Type RequiredModule -Name @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Applications'
        'Microsoft.Graph.Identity.DirectoryManagement'
        'Microsoft.Graph.Identity.Governance'
        'Microsoft.Graph.Identity.SignIns'
        'Microsoft.Graph.DeviceManagement.Enrollment'
        'Microsoft.Graph.Users'
        'Microsoft.Graph.Groups'
        'Microsoft.Graph.DeviceManagement'
        'Microsoft.Graph.Teams'
        'Microsoft.Graph.Beta.Security'
        'Microsoft.Graph.Reports'
    ) -Guid Auto -Version '2.25.0'

    New-ConfigurationModule -Type RequiredModule -Name Mailozaurr -Guid Auto -Version '1.0.0'

    New-ConfigurationModuleSkip -IgnoreModuleName @(
        'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Security',
        'DSInternals.Passkeys'
    ) -IgnoreFunctionName @(
        'Get-PasskeyRegistrationOptions'
        'New-Passkey'
    )
    New-ConfigurationModule -Type ApprovedModule -Name 'PSSharedGoods', 'PSWriteColor', 'Connectimo', 'PSUnifi', 'PSWebToolbox', 'PSMyPassword' #, 'PSPublishModule'


    $ConfigurationFormat = [ordered] @{
        RemoveComments                              = $false

        PlaceOpenBraceEnable                        = $true
        PlaceOpenBraceOnSameLine                    = $true
        PlaceOpenBraceNewLineAfter                  = $true
        PlaceOpenBraceIgnoreOneLineBlock            = $false

        PlaceCloseBraceEnable                       = $true
        PlaceCloseBraceNewLineAfter                 = $false
        PlaceCloseBraceIgnoreOneLineBlock           = $false
        PlaceCloseBraceNoEmptyLineBefore            = $true

        UseConsistentIndentationEnable              = $true
        UseConsistentIndentationKind                = 'space'
        UseConsistentIndentationPipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
        UseConsistentIndentationIndentationSize     = 4

        UseConsistentWhitespaceEnable               = $true
        UseConsistentWhitespaceCheckInnerBrace      = $true
        UseConsistentWhitespaceCheckOpenBrace       = $true
        UseConsistentWhitespaceCheckOpenParen       = $true
        UseConsistentWhitespaceCheckOperator        = $true
        UseConsistentWhitespaceCheckPipe            = $true
        UseConsistentWhitespaceCheckSeparator       = $true

        AlignAssignmentStatementEnable              = $true
        AlignAssignmentStatementCheckHashtable      = $true

        UseCorrectCasingEnable                      = $true
    }
    # format PSD1 and PSM1 files when merging into a single file
    # enable formatting is not required as Configuration is provided
    New-ConfigurationFormat -ApplyTo 'OnMergePSM1', 'OnMergePSD1' -Sort None @ConfigurationFormat
    # format PSD1 and PSM1 files within the module
    # enable formatting is required to make sure that formatting is applied (with default settings)
    New-ConfigurationFormat -ApplyTo 'DefaultPSD1', 'DefaultPSM1' -EnableFormatting -Sort None
    # when creating PSD1 use special style without comments and with only required parameters
    New-ConfigurationFormat -ApplyTo 'DefaultPSD1', 'OnMergePSD1' -PSD1Style 'Minimal'
    # configuration for documentation, at the same time it enables documentation processing
    New-ConfigurationDocumentation -Enable:$false -StartClean -UpdateWhenNew -PathReadme 'Docs\Readme.md' -Path 'Docs'

    New-ConfigurationImportModule -ImportSelf

    New-ConfigurationBuild -Enable:$true -SignModule -MergeModuleOnBuild -MergeFunctionsFromApprovedModules -CertificateThumbprint '483292C9E317AA13B07BB7A96AE9D1A5ED9E7703'

    #New-ConfigurationArtefact -Type Unpacked -Enable -Path "$PSScriptRoot\..\Artefacts\Unpacked" -ModulesPath "$PSScriptRoot\..\Artefacts\Unpacked\Modules" -RequiredModulesPath "$PSScriptRoot\..\Artefacts\Unpacked\Modules" -AddRequiredModules
    New-ConfigurationArtefact -Type Packed -Enable -Path "$PSScriptRoot\..\Artefacts\Packed" -ArtefactName '<ModuleName>.v<ModuleVersion>.zip'

    # options for publishing to github/psgallery
    #New-ConfigurationPublish -Type PowerShellGallery -FilePath 'C:\Support\Important\PowerShellGalleryAPI.txt' -Enabled:$true
    #New-ConfigurationPublish -Type GitHub -FilePath 'C:\Support\Important\GitHubAPI.txt' -UserName 'EvotecIT' -Enabled:$true
}