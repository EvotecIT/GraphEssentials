function Show-MyConditionalAccess {
    <#
    .SYNOPSIS
    Generates an HTML report for conditional access policies.

    .DESCRIPTION
    This function retrieves conditional access policies and displays them in an HTML report using PSWriteHTML.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .EXAMPLE
    Show-MyConditionalAccess -FilePath "C:\Reports\ConditionalAccess.html"

    Generates a conditional access policies report and saves it to the specified path.

    .EXAMPLE
    Show-MyConditionalAccess -FilePath "C:\Reports\ConditionalAccess.html" -Online

    Generates a conditional access policies report, saves it to the specified path, and opens it in the default browser.
    #>

    [cmdletbinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    Write-Verbose -Message "Show-MyConditionalAccess - Getting conditional access policies"
    $CAData = Get-MyConditionalAccess -IncludeStatistics

    if (-not $CAData) {
        Write-Warning -Message "Show-MyConditionalAccess - Failed to retrieve conditional access policies"
        return
    }

    Write-Verbose -Message "Show-MyConditionalAccess - Preparing HTML report"
    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "GraphEssentials - $($Script:Reporting['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        New-HTMLTab -Name "Statistics" {
            New-HTMLSection -HeaderText "Conditional Access Policies - Statistics" {
                New-HTMLPanel {
                    New-HTMLList {
                        New-HTMLListItem -Text "Total Policies: ", "$($CAData.Statistics.TotalCount)" -FontWeight normal, bold
                        New-HTMLListItem -Text "Enabled: ", "$($CAData.Statistics.EnabledCount)" -FontWeight normal, bold
                        New-HTMLListItem -Text "Report-only: ", "$($CAData.Statistics.ReportOnlyCount)" -FontWeight normal, bold
                        New-HTMLListItem -Text "Disabled: ", "$($CAData.Statistics.DisabledCount)" -FontWeight normal, bold
                        New-HTMLListItem -Text "Microsoft-managed: ", "$($CAData.Statistics.MicrosoftManagedCount)" -FontWeight normal, bold
                    }
                }
            }
        }

        New-HTMLTab -Name "All Policies" {
            New-HTMLSection -HeaderText "All Conditional Access Policies" {
                New-HTMLTable -DataTable $CAData.Policies.All -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableCAPoliciesAll" -PagingLength 10 -ScrollX
            }
        }

        New-HTMLTab -Name "MFA For Admins" {
            New-HTMLSection -HeaderText "MFA For Admin Roles" {
                New-HTMLTable -DataTable $CAData.Policies.MFAforAdmins -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableMFAAdmins" -PagingLength 10 -ScrollX
            }

            if ($CAData.Policies.AdminRoleAnalysis) {
                New-HTMLSection -HeaderText "Admin Role Analysis" {
                    New-HTMLTable -DataTable $CAData.Policies.AdminRoleAnalysis -Filtering {
                        # You could add conditions here if needed
                    } -DataStore JavaScript -DataTableID "TableAdminRoleAnalysis" -PagingLength 10 -ScrollX
                }
            }
        }

        New-HTMLTab -Name "MFA For Users" {
            New-HTMLSection -HeaderText "MFA For Users" {
                New-HTMLTable -DataTable $CAData.Policies.MFAforUsers -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableMFAUsers" -ScrollX
            }
        }

        New-HTMLTab -Name "Block Legacy Access" {
            New-HTMLSection -HeaderText "Block Legacy Authentication" {
                New-HTMLTable -DataTable $CAData.Policies.BlockLegacyAccess -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableBlockLegacy" -ScrollX
            }
        }

        New-HTMLTab -Name "Device Compliance" {
            New-HTMLSection -HeaderText "Device Compliance Policies" {
                New-HTMLTable -DataTable $CAData.Policies.DeviceCompliance -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableDeviceCompliance" -ScrollX
            }
        }

        New-HTMLTab -Name "Risk-Based" {
            New-HTMLSection -HeaderText "Risk-Based Policies" {
                New-HTMLTable -DataTable $CAData.Policies.Risk -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableRisk" -ScrollX
            }
        }

        New-HTMLTab -Name "Other Categories" {
            New-HTMLSection -HeaderText "App Protection Policies" {
                New-HTMLTable -DataTable $CAData.Policies.AppProtection -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableAppProtection" -ScrollX
            }

            New-HTMLSection -HeaderText "Location-Based Policies" {
                New-HTMLTable -DataTable $CAData.Policies.UsingLocations -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableLocations" -ScrollX
            }

            New-HTMLSection -HeaderText "Admin Portal Restrictions" {
                New-HTMLTable -DataTable $CAData.Policies.RestrictAdminPortal -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableAdminPortal" -ScrollX
            }

            New-HTMLSection -HeaderText "MFA for Device Join" {
                New-HTMLTable -DataTable $CAData.Policies.MFAforDeviceJoin -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableDeviceJoin" -ScrollX
            }
        }

        New-HTMLTab -Name "Uncategorized" {
            New-HTMLSection -HeaderText "Uncategorized Policies" {
                New-HTMLTable -DataTable $CAData.Policies.Uncategorized -Filtering {
                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                } -DataStore JavaScript -DataTableID "TableUncategorized" -ScrollX
            }
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}