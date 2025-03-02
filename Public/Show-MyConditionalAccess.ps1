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

    # Properties to exclude from HTML tables for cleaner display
    $ExcludedProperties = @(
        'IncludedRolesGuid',
        'ExcludedRolesGuid',
        'IncludedUsersGuid',
        'ExcludedUsersGuid',
        'IncludedGroupsGuid',
        'ExcludedGroupsGuid'
    )

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

        New-HTMLTab -Name "All Policies" {
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 12pt -TextBlock {
                            "Conditional Access is an Azure AD feature that allows administrators to define policies that control access to resources. "
                            "These policies can be based on identity, device, location, and risk signals to determine when to require additional verification or block access."
                        }

                        New-HTMLText -FontSize 12pt -TextBlock {
                            "This report provides a comprehensive view of all conditional access policies in your environment, categorized by their purpose. "
                            "Each tab focuses on a specific category of policies, making it easier to audit and manage your security posture."
                        } -LineBreak

                        New-HTMLText -Text "Policy Statistics Overview" -FontSize 14pt -FontWeight bold
                        New-HTMLList {
                            New-HTMLListItem -Text "Total Policies: ", "$($CAData.Statistics.TotalCount)" -FontWeight normal, bold
                            New-HTMLListItem -Text "Enabled: ", "$($CAData.Statistics.EnabledCount)" -FontWeight normal, bold -Color Black, ForestGreen
                            New-HTMLListItem -Text "Report-only: ", "$($CAData.Statistics.ReportOnlyCount)" -FontWeight normal, bold -Color Black, Orange
                            New-HTMLListItem -Text "Disabled: ", "$($CAData.Statistics.DisabledCount)" -FontWeight normal, bold -Color Black, Gray
                            New-HTMLListItem -Text "Microsoft-managed: ", "$($CAData.Statistics.MicrosoftManagedCount)" -FontWeight normal, bold -Color Black, RoyalBlue
                        } -FontSize 12pt
                    }
                }
                New-HTMLPanel {
                    New-HTMLContainer {
                        New-HTMLChart {
                            New-ChartLegend -Name 'Enabled', 'Report-only', 'Disabled' -Color ForestGreen, Orange, Gray
                            New-ChartPie -Name 'Enabled' -Value $CAData.Statistics.EnabledCount
                            New-ChartPie -Name 'Report Only' -Value $CAData.Statistics.ReportOnlyCount
                            New-ChartPie -Name 'Disabled' -Value $CAData.Statistics.DisabledCount
                        } -Title 'Conditional Access Policies by Status' -TitleAlignment center

                        if ($CAData.Statistics.MicrosoftManagedCount -gt 0) {
                            New-HTMLChart {
                                New-ChartLegend -Name 'Microsoft-managed', 'Customer-managed' -Color RoyalBlue, MediumPurple
                                New-ChartPie -Name 'Microsoft managed' -Value $CAData.Statistics.MicrosoftManagedCount
                                New-ChartPie -Name 'Customer managed' -Value ($CAData.Statistics.TotalCount - $CAData.Statistics.MicrosoftManagedCount)
                            } -Title 'Policy Management Type' -TitleAlignment center
                        }
                    }
                }
            }

            New-HTMLSection -HeaderText "All Conditional Access Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "The table below lists all conditional access policies in your environment. Each policy is categorized by its primary purpose, indicated in the 'Type' column. "
                            "You can use the filtering options to focus on specific policies or states."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.All -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableCAPoliciesAll" -PagingLength 10 -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "MFA For Admins" {
            New-HTMLSection -HeaderText "MFA For Admin Roles" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Multi-factor authentication (MFA) for administrative roles is a critical security practice. "
                            "These policies specifically target users with administrative privileges in your Microsoft 365 or Azure environment. "
                            "By requiring MFA for administrative actions, you significantly reduce the risk of privileged account compromise."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.MFAforAdmins -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableMFAAdmins" -PagingLength 10 -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }

            if ($CAData.Policies.AdminRoleAnalysis) {
                New-HTMLSection -HeaderText "Admin Role Analysis" {
                    New-HTMLPanel -Invisible {
                        New-HTMLContainer {
                            New-HTMLText -FontSize 11pt -TextBlock {
                                "Microsoft recommends that at least 14 critical administrative roles should be protected with MFA policies. "
                                "This table shows which of your admin MFA policies cover these critical roles and how many additional roles they include."
                            }

                            if ($CAData.Policies.DefaultRoles) {
                                New-HTMLText -FontSize 11pt -Text "Critical admin roles that should be protected:" -FontWeight bold
                                New-HTMLList {
                                    foreach ($roleName in $CAData.Policies.DefaultRoles) {
                                        New-HTMLListItem -Text $roleName
                                    }
                                } -FontSize 10pt
                            }
                        }

                        New-HTMLContainer {
                            New-HTMLTable -DataTable $CAData.Policies.AdminRoleAnalysis -Filtering {
                                # You could add conditions here if needed
                            } -DataStore JavaScript -DataTableID "TableAdminRoleAnalysis" -PagingLength 10 -ScrollX -WarningAction SilentlyContinue
                        }
                    }
                }
            }
        }

        New-HTMLTab -Name "MFA For Users" {
            New-HTMLSection -HeaderText "MFA For Users" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "These policies require multi-factor authentication for general users in your environment. "
                            "MFA for users provides an additional layer of security beyond passwords, helping protect against stolen credentials and phishing attacks. "
                            "These policies typically target all users or specific groups rather than administrative roles."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.MFAforUsers -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableMFAUsers" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Block Legacy Access" {
            New-HTMLSection -HeaderText "Block Legacy Authentication" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Legacy authentication protocols (like basic authentication in Exchange) don't support modern security features like MFA. "
                            "These policies specifically block legacy authentication methods, which are commonly used in attacks. "
                            "Microsoft recommends blocking legacy authentication for all users to improve your security posture."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.BlockLegacyAccess -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableBlockLegacy" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Device Compliance" {
            New-HTMLSection -HeaderText "Device Compliance Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Device compliance policies ensure that only devices meeting specific security requirements can access your resources. "
                            "These policies help maintain a secure device posture by requiring devices to be either Intune compliant or domain joined. "
                            "This practice helps prevent access from potentially compromised or unmanaged devices."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.DeviceCompliance -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableDeviceCompliance" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Risk-Based" {
            New-HTMLSection -HeaderText "Risk-Based Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Risk-based policies respond to detected risk signals in your environment. "
                            "These policies can target user risk (compromised credentials) or sign-in risk (suspicious sign-in patterns). "
                            "By tailoring authentication requirements based on risk level, you can balance security and user experience."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.Risk -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableRisk" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Other Categories" {
            New-HTMLSection -HeaderText "App Protection Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "App protection policies target mobile platforms to ensure secure access from Android and iOS devices. "
                            "These policies can require specific app protection measures for accessing corporate resources from mobile devices."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.AppProtection -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableAppProtection" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }

            New-HTMLSection -HeaderText "Location-Based Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Location-based policies use named network locations (IP ranges) to control access based on where users are connecting from. "
                            "These policies can require additional verification when accessing from unfamiliar locations or block access from certain regions."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.UsingLocations -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableLocations" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }

            New-HTMLSection -HeaderText "Admin Portal Restrictions" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "Admin portal restriction policies specifically target Microsoft administrative portals. "
                            "These policies help protect your administrative interfaces with additional security requirements, "
                            "which is essential since these portals provide privileged access to your environment."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.RestrictAdminPortal -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableAdminPortal" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }

            New-HTMLSection -HeaderText "MFA for Device Join" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "These policies require additional verification when joining or registering devices to your Azure AD. "
                            "This security measure helps prevent unauthorized devices from being registered to your environment."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.MFAforDeviceJoin -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableDeviceJoin" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Uncategorized" {
            New-HTMLSection -HeaderText "Uncategorized Policies" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "These conditional access policies don't fit into any of the standard categories recognized by this report. "
                            "They may be custom policies designed for specific scenarios in your environment. "
                            "Review these policies to understand their purpose and ensure they align with your security objectives."
                        }
                    }

                    New-HTMLContainer {
                        New-HTMLTable -DataTable $CAData.Policies.Uncategorized -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableUncategorized" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}