function Show-MyConditionalAccess {
    <#
    .SYNOPSIS
    Generates an HTML report for conditional access policies.

    .DESCRIPTION
    This function retrieves conditional access policies and displays them in an HTML report using PSWriteHTML.
    The report includes information about policy categorization, authentication strength policies, and usage statistics.

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

    Write-Verbose -Message "Show-MyConditionalAccess - Getting authentication strength policies"
    $AuthStrengths = Get-MyAuthenticationStrength

    if (-not $AuthStrengths) {
        Write-Warning -Message "Show-MyConditionalAccess - Failed to retrieve authentication strength policies"
    }

    # Properties to exclude from HTML tables for cleaner display
    $ExcludedProperties = @(
        'IncludedRolesGuid',
        'ExcludedRolesGuid',
        'IncludedUsersGuid',
        'ExcludedUsersGuid',
        'IncludedGroupsGuid',
        'ExcludedGroupsGuid',
        'ApplicationsGuid',
        'AuthStrengthGuid'
    )

    # Properties to exclude from Authentication Strength tables
    $ExcludedAuthProperties = @(
        'RawAllowedCombinations'
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

        New-HTMLTab -Name "All Policies ($($CAData.Policies.All.Count))" {
            New-HTMLTabPanel {
                New-HTMLTab -Name 'Policies' {
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
                                    "You can use the filtering options to focus on specific policies or states. Days since creation and modification are shown to help identify stale or recent changes."
                                }
                            }

                            New-HTMLContainer {
                                New-HTMLTable -DataTable $CAData.Policies.All -Filtering {
                                    New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor Conifer -ComparisonType string
                                    New-HTMLTableCondition -Name 'State' -Value 'enabledForReportingButNotEnforced' -BackgroundColor Orange -ComparisonType string
                                    New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGrey -ComparisonType string
                                    New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                                    New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                                } -DataStore JavaScript -DataTableID "TableCAPoliciesAll" -PagingLength 10 -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                            }
                        }
                    }

                }

                if ($AuthStrengths) {
                    New-HTMLTab -Name "Auth Strength Policies ($($AuthStrengths.Count))" {
                        New-HTMLSection -HeaderText "Authentication Strength Policies" {
                            New-HTMLPanel -Invisible {
                                New-HTMLContainer {
                                    New-HTMLText -FontSize 11pt -TextBlock {
                                        "Authentication strength policies define which authentication methods are allowed for accessing resources. "
                                        "These policies can be referenced by conditional access rules to enforce specific authentication requirements based on risk level, application sensitivity, or other criteria."
                                    }

                                    New-HTMLText -FontSize 11pt -TextBlock {
                                        "Built-in policies are predefined by Microsoft while custom policies can be created to meet specific organizational requirements. "
                                        "Each policy contains combinations of authentication methods that are permitted when that policy is applied."
                                    }
                                }

                                New-HTMLContainer {
                                    New-HTMLTable -DataTable $AuthStrengths -Filtering {
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Built-in' -BackgroundColor LightBlue -ComparisonType string
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Custom' -BackgroundColor LightGreen -ComparisonType string
                                    } -DataStore JavaScript -DataTableID "TableAuthStrengths" -PagingLength 10 -ScrollX -ExcludeProperty $ExcludedAuthProperties -WarningAction SilentlyContinue
                                }
                            }
                        }

                        New-HTMLSection -HeaderText "Authentication Methods Usage" {
                            New-HTMLPanel -Invisible {
                                New-HTMLContainer {
                                    New-HTMLText -FontSize 11pt -TextBlock {
                                        "This table shows detailed information about each authentication strength policy including the specific authentication methods combinations they allow. "
                                        "These combinations determine what authentication methods users can use when accessing resources protected by conditional access policies that reference these strength policies."
                                    }
                                }

                                # Create a summary table of methods by policy
                                $AuthMethodsTable = foreach ($Strength in $AuthStrengths) {
                                    foreach ($Combination in $Strength.RawAllowedCombinations) {
                                        [PSCustomObject]@{
                                            PolicyName   = $Strength.DisplayName
                                            PolicyType   = $Strength.PolicyType
                                            AuthMethod   = $Combination
                                            FriendlyName = ($Strength.AllowedCombinations | Where-Object { $Strength.RawAllowedCombinations.IndexOf($Combination) -eq $Strength.AllowedCombinations.IndexOf($_) })
                                        }
                                    }
                                }

                                New-HTMLContainer {
                                    New-HTMLTable -DataTable $AuthMethodsTable -Filtering {
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Built-in' -BackgroundColor LightBlue -ComparisonType string
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Custom' -BackgroundColor LightGreen -ComparisonType string
                                    } -DataStore JavaScript -DataTableID "TableAuthMethods" -PagingLength 10 -ScrollX -WarningAction SilentlyContinue
                                }
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Named Locations" {
                    New-HTMLSection -HeaderText "Named Locations" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Named locations define trusted IP ranges or countries/regions used in conditional access policies. "
                                    "These locations can be used to require additional verification when accessing from untrusted locations "
                                    "or to allow access without additional checks from trusted locations."
                                }
                            }

                            $NamedLocations = Get-MyNamedLocation
                            if ($NamedLocations) {
                                New-HTMLContainer {
                                    New-HTMLTable -DataTable $NamedLocations -Filtering {
                                        New-HTMLTableCondition -Name 'Type' -Value 'IP' -BackgroundColor LightBlue -ComparisonType string
                                        New-HTMLTableCondition -Name 'Type' -Value 'CountryRegion' -BackgroundColor LightGreen -ComparisonType string
                                    } -DataStore JavaScript -DataTableID "TableNamedLocations" -ScrollX -WarningAction SilentlyContinue
                                }
                            } else {
                                New-HTMLContainer {
                                    New-HTMLText -Text "No named locations found in the tenant." -Color Orange -FontSize 11pt
                                }
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Terms of Use" {
                    New-HTMLSection -HeaderText "Terms of Use Agreements" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Terms of Use agreements require users to accept terms before accessing resources. "
                                    "These agreements can be enforced through conditional access policies and can require periodic re-acceptance."
                                }
                            }

                            $TermsOfUse = Get-MyTermsOfUse
                            if ($TermsOfUse) {
                                foreach ($Agreement in $TermsOfUse) {
                                    New-HTMLSection -HeaderText "Agreement: $($Agreement.DisplayName)" {
                                        # Basic Agreement Settings
                                        New-HTMLSection -HeaderText "Agreement Settings" {
                                            New-HTMLTable -DataTable $([PSCustomObject]@{
                                                    'Agreement ID'                   = $Agreement.Id
                                                    'Version'                        = $Agreement.Version
                                                    'Viewing Required Before Accept' = $Agreement.IsViewingBeforeAcceptanceRequired
                                                    'Acceptance Required'            = $Agreement.IsAcceptanceRequired
                                                    'Created'                        = $Agreement.CreatedDateTime
                                                    'Modified'                       = $Agreement.ModifiedDateTime
                                                }) -Filtering -DataStore JavaScript -DataTableID "TableToU$($Agreement.Id)Settings" -ScrollX -WarningAction SilentlyContinue
                                        }

                                        # Expiration and Reacceptance Settings
                                        New-HTMLSection -HeaderText "Expiration Settings" {
                                            New-HTMLTable -DataTable $([PSCustomObject]@{
                                                    'Terms Expiration'                = $Agreement.TermsExpiration
                                                    'Reacceptance Required Frequency' = $Agreement.UserReacceptRequiredFrequency
                                                }) -Filtering -DataStore JavaScript -DataTableID "TableToU$($Agreement.Id)Expiration" -ScrollX -WarningAction SilentlyContinue
                                        }

                                        # File and Language Information
                                        New-HTMLSection -HeaderText "Agreement Files" {
                                            New-HTMLTable -DataTable $(
                                                if ($Agreement.Files -and $Agreement.FileLanguages) {
                                                    $Languages = $Agreement.FileLanguages
                                                    $Files = $Agreement.Files
                                                    0..([Math]::Max($Languages.Count, $Files.Count) - 1) | ForEach-Object {
                                                        [PSCustomObject]@{
                                                            'File Name' = if ($_ -lt $Files.Count) { $Files[$_] } else { 'N/A' }
                                                            'Language'  = if ($_ -lt $Languages.Count) { $Languages[$_] } else { 'N/A' }
                                                        }
                                                    }
                                                } else {
                                                    [PSCustomObject]@{
                                                        'File Name' = 'No files'
                                                        'Language'  = 'No languages'
                                                    }
                                                }
                                            ) -Filtering -DataStore JavaScript -DataTableID "TableToU$($Agreement.Id)Files" -ScrollX -WarningAction SilentlyContinue
                                        }

                                        # User Scope Settings
                                        New-HTMLSection -HeaderText "User Scope" {
                                            New-HTMLTable -DataTable $([PSCustomObject]@{
                                                    'All Users'      = $Agreement.AcceptanceRequiredBy.AllUsers
                                                    'External Users' = $Agreement.AcceptanceRequiredBy.ExternalUsers
                                                    'Internal Users' = $Agreement.AcceptanceRequiredBy.InternalUsers
                                                }) -Filtering {
                                                New-HTMLTableCondition -Name 'All Users' -Value $true -BackgroundColor LightBlue -ComparisonType boolean
                                                New-HTMLTableCondition -Name 'External Users' -Value $true -BackgroundColor LightGreen -ComparisonType boolean
                                                New-HTMLTableCondition -Name 'Internal Users' -Value $true -BackgroundColor LightYellow -ComparisonType boolean
                                            } -DataStore JavaScript -DataTableID "TableToU$($Agreement.Id)Scope" -ScrollX -WarningAction SilentlyContinue
                                        }
                                    }
                                }
                            } else {
                                New-HTMLContainer {
                                    New-HTMLText -Text "No Terms of Use agreements found in the tenant." -Color Orange -FontSize 11pt
                                }
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Cross-tenant Access" {
                    New-HTMLSection -HeaderText "Cross-tenant Access Policies" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Cross-tenant access policies control how your organization collaborates with other Azure AD organizations. "
                                    "These policies define trust settings for inbound and outbound access, including B2B collaboration and B2B direct connect."
                                }
                            }

                            $CrossTenantAccess = Get-MyCrossTenantAccess
                            if ($CrossTenantAccess) {
                                New-HTMLSection -HeaderText "Default Configuration - Inbound Trust Settings" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'MFA Accepted'                           = $CrossTenantAccess.DefaultPolicy.InboundTrust.IsMfaAccepted
                                            'Compliant Device Accepted'              = $CrossTenantAccess.DefaultPolicy.InboundTrust.IsCompliantDeviceAccepted
                                            'Hybrid Azure AD Joined Device Accepted' = $CrossTenantAccess.DefaultPolicy.InboundTrust.IsHybridAzureADJoinedDeviceAccepted
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantDefaultInboundTrust" -ScrollX -WarningAction SilentlyContinue
                                }

                                New-HTMLSection -HeaderText "Default Configuration - Inbound/Outbound Access" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'Inbound Access Allowed'  = $CrossTenantAccess.DefaultPolicy.InboundAllowed
                                            'Outbound Access Allowed' = $CrossTenantAccess.DefaultPolicy.OutboundAllowed
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantDefaultAccess" -ScrollX -WarningAction SilentlyContinue
                                }

                                New-HTMLSection -HeaderText "Default Configuration - B2B Direct Connect Settings" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'Applications Enabled' = $CrossTenantAccess.DefaultPolicy.B2BDirectConnect.ApplicationsEnabled
                                            'Users Enabled'        = $CrossTenantAccess.DefaultPolicy.B2BDirectConnect.UsersEnabled
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantDefaultB2BDirect" -ScrollX -WarningAction SilentlyContinue
                                }

                                New-HTMLSection -HeaderText "Default Configuration - B2B Collaboration Settings" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'Applications Enabled' = $CrossTenantAccess.DefaultPolicy.B2BCollaboration.ApplicationsEnabled
                                            'Users Enabled'        = $CrossTenantAccess.DefaultPolicy.B2BCollaboration.UsersEnabled
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantDefaultB2BCollab" -ScrollX -WarningAction SilentlyContinue
                                }

                                if ($CrossTenantAccess.TenantPolicies) {
                                    New-HTMLSection -HeaderText "Tenant-Specific Policies" {
                                        foreach ($TenantPolicy in $CrossTenantAccess.TenantPolicies) {
                                            New-HTMLSection -HeaderText "Policy for $($TenantPolicy.DisplayName) ($($TenantPolicy.TenantId))" {
                                                New-HTMLPanel {
                                                    New-HTMLSection -HeaderText "Inbound Trust Settings" {
                                                        New-HTMLTable -DataTable $([PSCustomObject]@{
                                                                'MFA Accepted'                           = $TenantPolicy.InboundTrust.IsMfaAccepted
                                                                'Compliant Device Accepted'              = $TenantPolicy.InboundTrust.IsCompliantDeviceAccepted
                                                                'Hybrid Azure AD Joined Device Accepted' = $TenantPolicy.InboundTrust.IsHybridAzureADJoinedDeviceAccepted
                                                            }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantPolicy$($TenantPolicy.TenantId)Trust" -ScrollX -WarningAction SilentlyContinue
                                                    }

                                                    New-HTMLSection -HeaderText "Access Settings" {
                                                        New-HTMLTable -DataTable $([PSCustomObject]@{
                                                                'Inbound Access Allowed'  = $TenantPolicy.InboundAllowed
                                                                'Outbound Access Allowed' = $TenantPolicy.OutboundAllowed
                                                                'Created'                 = $TenantPolicy.CreatedDateTime
                                                                'Modified'                = $TenantPolicy.ModifiedDateTime
                                                            }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantPolicy$($TenantPolicy.TenantId)Access" -ScrollX -WarningAction SilentlyContinue
                                                    }

                                                    New-HTMLSection -HeaderText "B2B Settings" {
                                                        New-HTMLTable -DataTable $([PSCustomObject]@{
                                                                'Direct Connect - Applications' = $TenantPolicy.B2BDirectConnect.ApplicationsEnabled
                                                                'Direct Connect - Users'        = $TenantPolicy.B2BDirectConnect.UsersEnabled
                                                                'Collaboration - Applications'  = $TenantPolicy.B2BCollaboration.ApplicationsEnabled
                                                                'Collaboration - Users'         = $TenantPolicy.B2BCollaboration.UsersEnabled
                                                            }) -Filtering -DataStore JavaScript -DataTableID "TableCrossTenantPolicy$($TenantPolicy.TenantId)B2B" -ScrollX -WarningAction SilentlyContinue
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                New-HTMLContainer {
                                    New-HTMLText -Text "Unable to retrieve cross-tenant access policies." -Color Orange -FontSize 11pt
                                }
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Authentication Context" {
                    New-HTMLSection -HeaderText "Authentication Contexts" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Authentication contexts define specific authentication requirements that can be applied to sensitive applications. "
                                    "These contexts can be referenced in conditional access policies to require stronger authentication for specific resources."
                                }
                            }

                            $AuthContexts = Get-MyAuthenticationContext
                            if ($AuthContexts) {
                                New-HTMLContainer {
                                    New-HTMLTable -DataTable $AuthContexts -Filtering {
                                        New-HTMLTableCondition -Name 'IsAvailable' -Value $true -BackgroundColor LightGreen -ComparisonType boolean
                                    } -DataStore JavaScript -DataTableID "TableAuthContexts" -ScrollX -WarningAction SilentlyContinue
                                }
                            } else {
                                New-HTMLContainer {
                                    New-HTMLText -Text "No authentication contexts found in the tenant." -Color Orange -FontSize 11pt
                                }
                            }
                        }
                    }
                }

                New-HTMLTab -Name "Auth Methods" {
                    New-HTMLSection -HeaderText "Authentication Methods Policy" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "The authentication methods policy defines which authentication methods are enabled in your tenant "
                                    "and how they are configured. This includes settings for MFA methods, passwordless options, and "
                                    "temporary access credentials."
                                }
                            }

                            $AuthMethods = Get-MyAuthenticationMethodsPolicy
                            if ($AuthMethods) {
                                New-HTMLSection -HeaderText "General Settings" {
                                    New-HTMLTable -DataTable ([PSCustomObject]@{
                                            LastModified = $AuthMethods.LastModifiedDateTime
                                            Description  = $AuthMethods.Description
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsGeneral" -ScrollX -WarningAction SilentlyContinue
                                }

                                # Microsoft Authenticator Settings
                                New-HTMLSection -HeaderText "Microsoft Authenticator" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'State'                      = $AuthMethods.Methods.Authenticator.State
                                            'Require Number Matching'    = $AuthMethods.Methods.Authenticator.RequireNumberMatching
                                            'Allow Without Number Match' = $AuthMethods.Methods.Authenticator.AllowWithoutNumberMatch
                                            'Excluded Groups'            = ($AuthMethods.Methods.Authenticator.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsAuthenticator" -ScrollX -WarningAction SilentlyContinue
                                }

                                # FIDO2 Security Key Settings
                                New-HTMLSection -HeaderText "FIDO2 Security Keys" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'State'                = $AuthMethods.Methods.FIDO2.State
                                            'Attestation Enforced' = $AuthMethods.Methods.FIDO2.IsAttestationEnforced
                                            'Excluded Groups'      = ($AuthMethods.Methods.FIDO2.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsFIDO2" -ScrollX -WarningAction SilentlyContinue
                                }

                                # Temporary Access Pass Settings
                                New-HTMLSection -HeaderText "Temporary Access Pass" {
                                    New-HTMLTable -DataTable $([PSCustomObject]@{
                                            'State'                      = $AuthMethods.Methods.TemporaryAccess.State
                                            'Default Length'             = $AuthMethods.Methods.TemporaryAccess.DefaultLength
                                            'Default Lifetime (Minutes)' = $AuthMethods.Methods.TemporaryAccess.DefaultLifetimeInMinutes
                                            'Maximum Lifetime (Minutes)' = $AuthMethods.Methods.TemporaryAccess.MaximumLifetimeInMinutes
                                            'Excluded Groups'            = ($AuthMethods.Methods.TemporaryAccess.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                        }) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsTAP" -ScrollX -WarningAction SilentlyContinue
                                }

                                # Email and SMS Settings
                                New-HTMLSection -HeaderText "Email and SMS Authentication" {
                                    New-HTMLTable -DataTable $(
                                        @(
                                            [PSCustomObject]@{
                                                'Method'                             = 'Email'
                                                'State'                              = $AuthMethods.Methods.Email.State
                                                'Allow External ID to Use Email OTP' = $AuthMethods.Methods.Email.AllowExternalIdToUseEmailOtp
                                                'Excluded Groups'                    = ($AuthMethods.Methods.Email.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                            [PSCustomObject]@{
                                                'Method'                             = 'SMS'
                                                'State'                              = $AuthMethods.Methods.SMS.State
                                                'Allow External ID to Use Email OTP' = 'N/A'
                                                'Excluded Groups'                    = ($AuthMethods.Methods.SMS.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                        )
                                    ) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsEmailSMS" -ScrollX -WarningAction SilentlyContinue
                                }

                                # Voice and Software Token Settings
                                New-HTMLSection -HeaderText "Voice and Software Token Authentication" {
                                    New-HTMLTable -DataTable $(
                                        @(
                                            [PSCustomObject]@{
                                                'Method'          = 'Voice'
                                                'State'           = $AuthMethods.Methods.Voice.State
                                                'Excluded Groups' = ($AuthMethods.Methods.Voice.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                            [PSCustomObject]@{
                                                'Method'          = 'Software Token'
                                                'State'           = $AuthMethods.Methods.Software.State
                                                'Excluded Groups' = ($AuthMethods.Methods.Software.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                        )
                                    ) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsVoiceSoftware" -ScrollX -WarningAction SilentlyContinue
                                }

                                # Windows Hello and X.509 Certificate Settings
                                New-HTMLSection -HeaderText "Windows Hello and Certificate Authentication" {
                                    New-HTMLTable -DataTable $(
                                        @(
                                            [PSCustomObject]@{
                                                'Method'                = 'Windows Hello for Business'
                                                'State'                 = $AuthMethods.Methods.WindowsHello.State
                                                'Security Keys Enabled' = $AuthMethods.Methods.WindowsHello.SecurityKeys
                                                'Excluded Groups'       = ($AuthMethods.Methods.WindowsHello.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                            [PSCustomObject]@{
                                                'Method'                    = 'X.509 Certificate'
                                                'State'                     = $AuthMethods.Methods.X509.State
                                                'Certificate User Bindings' = ($AuthMethods.Methods.X509.CertificateUserBindings | ConvertTo-Json)
                                                'Excluded Groups'           = ($AuthMethods.Methods.X509.ExcludeTargets | ForEach-Object { $_.TargetType }) -join ', '
                                            }
                                        )
                                    ) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsHelloX509" -ScrollX -WarningAction SilentlyContinue
                                }
                            } else {
                                New-HTMLContainer {
                                    New-HTMLText -Text "Unable to retrieve authentication methods policy." -Color Orange -FontSize 11pt
                                }
                            }
                        }
                    }
                }
            }
        }

        New-HTMLTab -Name "MFA For Admins ($($CAData.Policies.MFAforAdmins.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
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

        New-HTMLTab -Name "MFA For Users ($($CAData.Policies.MFAforUsers.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableMFAUsers" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Block Legacy Access ($($CAData.Policies.BlockLegacyAccess.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableBlockLegacy" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Device Compliance ($($CAData.Policies.DeviceCompliance.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableDeviceCompliance" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Risk-Based ($($CAData.Policies.Risk.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableRisk" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "App Protection ($($CAData.Policies.AppProtection.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableAppProtection" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Location-Based ($($CAData.Policies.UsingLocations.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableLocations" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Admin Portal ($($CAData.Policies.RestrictAdminPortal.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableAdminPortal" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Device Join MFA ($($CAData.Policies.MFAforDeviceJoin.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableDeviceJoin" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }

        New-HTMLTab -Name "Uncategorized ($($CAData.Policies.Uncategorized.Count))" {
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
                            New-HTMLTableCondition -Name 'CreatedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                            New-HTMLTableCondition -Name 'ModifiedDays' -Value 7 -Operator le -BackgroundColor LightBlue -ComparisonType number
                        } -DataStore JavaScript -DataTableID "TableUncategorized" -ScrollX -ExcludeProperty $ExcludedProperties -WarningAction SilentlyContinue
                    }
                }
            }
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}