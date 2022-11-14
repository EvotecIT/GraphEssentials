﻿Clear-Host
Import-Module 'C:\Support\GitHub\PSPublishModule\PSPublishModule.psm1' -Force

$Configuration = @{
    Information = @{
        ModuleName        = 'GraphEssentials'
        DirectoryProjects = 'C:\Support\GitHub'

        FunctionsToExport = 'Public'
        AliasesToExport   = 'Public'

        LibrariesCore     = 'Lib\Core'
        LibrariesDefault  = 'Lib\Default'

        Manifest          = @{
            # Version number of this module.
            ModuleVersion              = '0.0.X'
            # Supported PSEditions
            CompatiblePSEditions       = @('Desktop', 'Core')
            # ID used to uniquely identify this module
            GUID                       = '75ef812f-6d8e-4898-81bb-8029e0560ef3'
            # Author of this module
            Author                     = 'Przemyslaw Klys'
            # Company or vendor of this module
            CompanyName                = 'Evotec'
            # Copyright statement for this module
            Copyright                  = "(c) 2011 - $((Get-Date).Year) Przemyslaw Klys @ Evotec. All rights reserved."
            # Description of the functionality provided by this module
            Description                = 'GraphEssentials is a PowerShell that help with Office 365 / Azure AD using mostly Graph'
            # Minimum version of the Windows PowerShell engine required by this module
            PowerShellVersion          = '5.1'
            # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
            Tags                       = @('Windows')

            #IconUri                    = 'https://evotec.xyz/wp-content/uploads/2020/07/MailoZaurr.png'

            #ProjectUri                 = 'https://github.com/EvotecIT/MailoZaurr'

            RequiredModules            = @(
                @{ ModuleName = 'PSSharedGoods'; ModuleVersion = "Latest"; Guid = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe' }
                @{ ModuleName = 'Microsoft.Graph.Applications'; ModuleVersion = 'Latest'; Guid = '467f54f2-44a8-4993-8e75-b96c3e443098' }
                @{ ModuleName = 'PSWriteHTML'; ModuleVersion = 'Latest'; Guid = 'a7bdf640-f5cb-4acf-9de0-365b322d245c' }
                @{ ModuleName = 'Microsoft.Graph.DeviceManagement.Enrolment'; ModuleVersion = 'Latest'; Guid = '447dd5b5-a01b-45bb-a55c-c9ecce3e820f' }
                @{ ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = 'Latest'; Guid = '71150504-37a3-48c6-82c7-7a00a12168db' }
                @{ ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = 'Latest'; Guid = '50bc9e18-e281-4208-8913-c9e1bef6083d' }
            )
            ExternalModuleDependencies = @(
                'Microsoft.PowerShell.Management'
                'Microsoft.PowerShell.Security'
                'Microsoft.PowerShell.Utility'
            )
        }
    }
    Options     = @{
        Merge             = @{
            Sort           = 'None'
            FormatCodePSM1 = @{
                Enabled           = $true
                RemoveComments    = $false
                FormatterSettings = @{
                    IncludeRules = @(
                        'PSPlaceOpenBrace',
                        'PSPlaceCloseBrace',
                        'PSUseConsistentWhitespace',
                        'PSUseConsistentIndentation',
                        'PSAlignAssignmentStatement',
                        'PSUseCorrectCasing'
                    )

                    Rules        = @{
                        PSPlaceOpenBrace           = @{
                            Enable             = $true
                            OnSameLine         = $true
                            NewLineAfter       = $true
                            IgnoreOneLineBlock = $true
                        }

                        PSPlaceCloseBrace          = @{
                            Enable             = $true
                            NewLineAfter       = $false
                            IgnoreOneLineBlock = $true
                            NoEmptyLineBefore  = $false
                        }

                        PSUseConsistentIndentation = @{
                            Enable              = $true
                            Kind                = 'space'
                            PipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
                            IndentationSize     = 4
                        }

                        PSUseConsistentWhitespace  = @{
                            Enable          = $true
                            CheckInnerBrace = $true
                            CheckOpenBrace  = $true
                            CheckOpenParen  = $true
                            CheckOperator   = $true
                            CheckPipe       = $true
                            CheckSeparator  = $true
                        }

                        PSAlignAssignmentStatement = @{
                            Enable         = $true
                            CheckHashtable = $true
                        }

                        PSUseCorrectCasing         = @{
                            Enable = $true
                        }
                    }
                }
            }
            FormatCodePSD1 = @{
                Enabled        = $true
                RemoveComments = $false
            }
            Integrate      = @{
                ApprovedModules = @('PSSharedGoods', 'PSWriteColor', 'Connectimo', 'PSUnifi', 'PSWebToolbox', 'PSMyPassword')
            }
        }
        Standard          = @{
            FormatCodePSM1 = @{

            }
            FormatCodePSD1 = @{
                Enabled = $true
                #RemoveComments = $true
            }
        }
        PowerShellGallery = @{
            ApiKey   = 'C:\Support\Important\PowerShellGalleryAPI.txt'
            FromFile = $true
        }
        GitHub            = @{
            ApiKey   = 'C:\Support\Important\GithubAPI.txt'
            FromFile = $true
            UserName = 'EvotecIT'
            #RepositoryName = 'PSWriteHTML'
        }
        Documentation     = @{
            Path       = 'Docs'
            PathReadme = 'Docs\Readme.md'
        }
    }
    Steps       = @{
        BuildModule        = @{  # requires Enable to be on to process all of that
            Enable              = $true
            DeleteBefore        = $true
            Merge               = $true
            MergeMissing        = $true
            SignMerged          = $true
            CreateFileCatalog   = $false # not working
            Releases            = $true
            LibrarySeparateFile = $false
            LibraryDotSource    = $true
            ClassesDotSource    = $true
            ReleasesUnpacked    = $true
            RefreshPSD1Only     = $false
        }
        BuildDocumentation = $true
        ImportModules      = @{
            Self            = $false
            RequiredModules = $false
            Verbose         = $false
        }
        PublishModule      = @{  # requires Enable to be on to process all of that
            Enabled      = $true
            Prerelease   = ''
            RequireForce = $false
            GitHub       = $true
        }
    }
}

New-PrepareModule -Configuration $Configuration