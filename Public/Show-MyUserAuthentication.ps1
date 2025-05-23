function Show-MyUserAuthentication {
    <#
    .SYNOPSIS
    Generates an HTML report for user authentication methods and related tenant policies.

    .DESCRIPTION
    Creates a comprehensive HTML report displaying information about user authentication methods
    (MFA status, FIDO2 keys, etc.), Authentication Methods Policy configurations, and
    Authentication Strength policies.

    .PARAMETER FilePath
    The path where the HTML report will be saved.

    .PARAMETER Online
    If specified, opens the HTML report in the default browser after generation.

    .PARAMETER ShowHTML
    If specified, displays the HTML content in the PowerShell console after generation.

    .PARAMETER UserPrincipalName
    Optional. The UserPrincipalName of a specific user to generate the report for.
    If not specified, generates report for all users.

    .PARAMETER IncludeDeviceDetails
    When specified, includes detailed information about FIDO2 security keys and
    other authentication device details in the user data section.

    .PARAMETER IncludeSecurityQuestionStatus
    Optional. If specified, checks if each user has registered security questions.
    WARNING: This can significantly increase execution time and memory usage.
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $UserPrincipalName,
        [switch] $IncludeDeviceDetails,
        [switch] $IncludeSecurityQuestionStatus
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    # --- Get Data ---
    Write-Verbose -Message "Show-MyUserAuthentication - Getting user authentication data"
    $getAuthParams = @{}
    if ($UserPrincipalName) { $getAuthParams['UserPrincipalName'] = $UserPrincipalName }
    if ($IncludeDeviceDetails) { $getAuthParams['IncludeDeviceDetails'] = $true }
    if ($IncludeSecurityQuestionStatus) { $getAuthParams['IncludeSecurityQuestionStatus'] = $true }
    $UserAuth = Get-MyUserAuthentication @getAuthParams

    Write-Verbose -Message "Show-MyUserAuthentication - Getting authentication methods policy"
    $AuthMethodsPolicy = Get-MyAuthenticationMethodsPolicy

    Write-Verbose -Message "Show-MyUserAuthentication - Getting authentication strength policies"
    $AuthStrengths = Get-MyAuthenticationStrength

    # --- Prepare User Metrics (Only if User Data exists) ---
    $TotalUsers = 0
    $MFACapable = 0
    $StrongAuth = 0
    $PasswordlessCapable = 0
    $StrongWeakAuth = 0
    $ExcludedUserProperties = @(
        if (-not $IncludeSecurityQuestionStatus) { 'Security Questions Registered' }
    )

    if ($UserAuth) {
        # Calculate metrics
        $TotalUsers = $UserAuth.Count
        $MFACapable = ($UserAuth | Where-Object { $_.IsMfaCapable }).Count
        # Define strong auth based on passwordless methods
        $StrongAuth = ($UserAuth | Where-Object { $_.IsPasswordlessCapable -or $_.'Software OTP' }).Count # Include Software OTP as strong
        $PasswordlessCapable = ($UserAuth | Where-Object { $_.IsPasswordlessCapable }).Count
        # Define Strong+Weak (User has a passwordless method AND a weak method like SMS/Email/Voice)
        $StrongWeakAuth = ($UserAuth | Where-Object {
                ($_.IsPasswordlessCapable -or $_.'Software OTP') -and
                ($_.'SMS' -or $_.'Email' -or $_.'Voice Call')
            }).Count
    } else {
        Write-Warning -Message "Show-MyUserAuthentication - No user authentication data found to display."
        # Allow report generation to continue to show policy info if available
    }

    # --- Pre-format UserAuth data for better table display ---
    $FormattedUserAuth = @()
    if ($UserAuth) {
        # Use the new private function to format the data
        $FormattedUserAuth = ConvertTo-MyFormattedUserAuth -UserAuthData $UserAuth
    }

    # --- Prepare Auth Strength Metrics ---
    $ExcludedAuthStrengthProperties = @(
        'RawAllowedCombinations' # Exclude the raw list
    )
    $AuthMethodsUsageTable = $null
    if ($AuthStrengths) {
        # Create a summary table of methods usage by policy
        $AuthMethodsUsageTable = foreach ($Strength in $AuthStrengths) {
            foreach ($Combination in $Strength.RawAllowedCombinations) {
                # Attempt to find the corresponding friendly name
                $friendlyName = $Strength.AllowedCombinations | Where-Object { $Strength.RawAllowedCombinations.IndexOf($Combination) -eq $Strength.AllowedCombinations.IndexOf($_) } | Select-Object -First 1
                [PSCustomObject]@{
                    PolicyName   = $Strength.DisplayName
                    PolicyType   = $Strength.PolicyType
                    AuthMethod   = $Combination
                    FriendlyName = if ($friendlyName) { $friendlyName } else { $Combination } # Fallback to raw if no match
                }
            }
        }
    }

    # --- Calculate Detailed User Stats ---
    $Stats = @{ TotalUsers = $TotalUsers } # Start with total from earlier
    if ($FormattedUserAuth.Count -gt 0) {
        $Stats['EnabledUsers'] = ($FormattedUserAuth | Where-Object { $_.Enabled }).Count
        $Stats['CloudOnlyUsers'] = ($FormattedUserAuth | Where-Object { $_.IsCloudOnly }).Count
        $Stats['UsersWithFIDO2'] = ($FormattedUserAuth | Where-Object { $_.'FIDO2 Security Key' }).Count
        $Stats['UsersWithWHFB'] = ($FormattedUserAuth | Where-Object { $_.'Windows Hello' }).Count
        $Stats['UsersWithMSAuthApp'] = ($FormattedUserAuth | Where-Object { $_.'Microsoft Auth App' }).Count
        $Stats['UsersWithSoftwareOTP'] = ($FormattedUserAuth | Where-Object { $_.'Software OTP' }).Count
        $Stats['UsersWithSMS'] = ($FormattedUserAuth | Where-Object { $_.SMS }).Count
        $Stats['UsersWithEmail'] = ($FormattedUserAuth | Where-Object { $_.Email }).Count
        $Stats['UsersWithVoice'] = ($FormattedUserAuth | Where-Object { $_.'Voice Call' }).Count
        $Stats['UsersWithPassword'] = ($FormattedUserAuth | Where-Object { $_.PasswordMethodRegistered }).Count
        $Stats['UsersWithTAP'] = ($FormattedUserAuth | Where-Object { $_.'Temporary Pass' }).Count
        $Stats['UsersWithSecQuestions'] = if ($IncludeSecurityQuestionStatus) { ($FormattedUserAuth | Where-Object { $_.'Security Questions Registered' }).Count } else { $null } # Only count if flag was used

        # Derived counts
        $Stats['DisabledUsers'] = $Stats.TotalUsers - $Stats.EnabledUsers
        $Stats['SyncedUsers'] = $Stats.TotalUsers - $Stats.CloudOnlyUsers
        $Stats['ZeroMfaUsers'] = $Stats.TotalUsers - $MFACapable # Use $MFACapable calculated earlier

        # Default MFA method breakdown
        $Stats['DefaultMethodCounts'] = $FormattedUserAuth | Group-Object -Property DefaultMfaMethod | Select-Object -Property Name, Count
    }

    # --- Generate HTML Report ---
    Write-Verbose -Message "Show-MyUserAuthentication - Preparing HTML report"
    New-HTML -TitleText "User Authentication Methods Report" -Online:$Online.IsPresent -FilePath $FilePath -ShowHTML:$ShowHTML.IsPresent {
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

        # Use Tab Panel to organize sections
        New-HTMLTabPanel {

            # --- Tab 1: User Authentication Data ---
            New-HTMLTab -Name "User Data ($($TotalUsers))" {
                if ($FormattedUserAuth.Count -gt 0) {
                    # Check the formatted data
                    # Statistics Section with Pie Charts
                    New-HTMLSection -HeaderText 'User Authentication Overview' {
                        # Key metrics section - Extended
                        New-HTMLSection {
                            New-HTMLPanel {
                                New-HTMLText -Text "Total Users" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text $TotalUsers -FontSize 24pt -Color '#0078d4'
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "MFA Capable Users" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text $MFACapable -FontSize 24pt -Color '#0078d4'
                                if ($TotalUsers -gt 0) {
                                    New-HTMLText -Text "$([math]::Round(($MFACapable / $TotalUsers) * 100, 2))% of users" -Color '#666666'
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "Strong Auth Registered" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text $StrongAuth -FontSize 24pt -Color '#0078d4'
                                if ($TotalUsers -gt 0) {
                                    New-HTMLText -Text "$([math]::Round(($StrongAuth / $TotalUsers) * 100, 2))% of users" -Color '#666666'
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "Passwordless Capable" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text $PasswordlessCapable -FontSize 24pt -Color '#0078d4'
                                if ($TotalUsers -gt 0) {
                                    New-HTMLText -Text "$([math]::Round(($PasswordlessCapable / $TotalUsers) * 100, 2))% of users" -Color '#666666'
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "Strong + Weak Auth User" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text $StrongWeakAuth -FontSize 24pt -Color '#0078d4'
                                if ($TotalUsers -gt 0) {
                                    New-HTMLText -Text "$([math]::Round(($StrongWeakAuth / $TotalUsers) * 100, 2))% of users" -Color '#666666'
                                }
                            }
                            # Add new panels for Enabled/Disabled, Cloud/Synced, Zero MFA
                            New-HTMLPanel {
                                New-HTMLText -Text "Enabled / Disabled" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text "$($Stats.EnabledUsers) / $($Stats.DisabledUsers)" -FontSize 24pt -Color '#0078d4'
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "Cloud Only / Synced" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text "$($Stats.CloudOnlyUsers) / $($Stats.SyncedUsers)" -FontSize 24pt -Color '#0078d4'
                            }
                            New-HTMLPanel {
                                New-HTMLText -Text "Users without MFA" -FontSize 14pt -Color '#666666'
                                New-HTMLText -Text "$($Stats.ZeroMfaUsers)" -FontSize 24pt -Color '#d13438' # Highlight in red
                                if ($TotalUsers -gt 0) {
                                    New-HTMLText -Text "$([math]::Round(($Stats.ZeroMfaUsers / $TotalUsers) * 100, 2))% of users" -Color '#666666'
                                }
                            }
                        } -Invisible
                        New-HTMLSection -Invisible {
                            New-HTMLPanel {
                                New-HTMLChart -Title 'MFA Status' {
                                    New-ChartPie -Name 'MFA Capable' -Value $MFACapable
                                    New-ChartPie -Name 'Password Only' -Value ($TotalUsers - $MFACapable)
                                }
                            }
                            New-HTMLPanel {
                                New-HTMLChart -Title 'Strong Authentication Distribution' {
                                    New-ChartPie -Name 'Strong Auth' -Value $StrongAuth # Based on passwordless or Software OTP
                                    New-ChartPie -Name 'Other MFA (Weak)' -Value ($MFACapable - $StrongAuth) # MFA capable but not using strong methods
                                    New-ChartPie -Name 'Password Only' -Value ($TotalUsers - $MFACapable)
                                }
                            }

                        }
                        # New section for method breakdown charts
                        if ($FormattedUserAuth.Count -gt 0) {
                            New-HTMLSection -HeaderText 'Method Registration & Usage Breakdown' {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Users Registered per Method' {
                                        New-ChartBar -Name 'Password' -Value $Stats.UsersWithPassword
                                        New-ChartBar -Name 'MS Auth App' -Value $Stats.UsersWithMSAuthApp
                                        New-ChartBar -Name 'FIDO2' -Value $Stats.UsersWithFIDO2
                                        New-ChartBar -Name 'Windows Hello' -Value $Stats.UsersWithWHFB
                                        New-ChartBar -Name 'Software OTP' -Value $Stats.UsersWithSoftwareOTP
                                        New-ChartBar -Name 'SMS' -Value $Stats.UsersWithSMS
                                        New-ChartBar -Name 'Voice Call' -Value $Stats.UsersWithVoice
                                        New-ChartBar -Name 'Email' -Value $Stats.UsersWithEmail
                                        if ($null -ne $Stats.UsersWithSecQuestions) {
                                            # Only show if fetched
                                            New-ChartBar -Name 'Security Questions' -Value $Stats.UsersWithSecQuestions
                                        }
                                        New-ChartBar -Name 'Temporary Pass' -Value $Stats.UsersWithTAP
                                    }
                                }
                                New-HTMLPanel {
                                    if ($Stats.DefaultMethodCounts) {
                                        New-HTMLChart -Title 'Default MFA Method Distribution' {
                                            foreach ($group in $Stats.DefaultMethodCounts) {
                                                New-ChartPie -Name $group.Name -Value $group.Count
                                            }
                                        }
                                    }
                                }
                            } -Invisible
                        }
                    } -Wrap wrap

                    # Consolidated User Details Table
                    New-HTMLSection -HeaderText 'User Authentication Details' {
                        # Use the pre-formatted data
                        New-HTMLTable -DataTable $FormattedUserAuth { # <-- Use $FormattedUserAuth
                            # Apply conditional formatting for boolean flags
                            foreach ($Column in @('Enabled', 'MFA', 'IsMfaCapable', 'IsPasswordlessCapable', 'PasswordMethodRegistered',
                                    'Microsoft Auth Passwordless', 'FIDO2 Security Key', 'Device Bound PushKey',
                                    'Microsoft Auth Push', 'Windows Hello', 'Microsoft Auth App', 'Hardware OTP',
                                    'Software OTP', 'Temporary Pass', 'MacOS Secure Key', 'SMS', 'Email',
                                    'Security Questions Registered', 'Voice Call', 'Alternative Phone')) {
                                # Check if column exists on the formatted object
                                if ($FormattedUserAuth[0].PSObject.Properties.Name -contains $Column) {
                                    New-TableCondition -Name $Column -Value $true -BackgroundColor '#00a36d' -Color White -ComparisonType bool
                                    New-TableCondition -Name $Column -Value $false -BackgroundColor '#d13438' -Color White -ComparisonType bool
                                }
                            }
                            New-TableCondition -Name 'IsCloudOnly' -Value $true -BackgroundColor '#0078d4' -Color White -ComparisonType bool
                        } -ScrollX -Filtering -ExcludeProperty $ExcludedUserProperties # No ArrayJoin needed
                    }
                } else {
                    # Display message if no user data
                    New-HTMLSection -HeaderText 'User Authentication Details' {
                        New-HTMLText -Text "No user authentication data found matching the criteria." -Color Orange -FontSize 12pt
                    }
                }
            }

            # --- Tab 2: Authentication Methods Policy ---
            New-HTMLTab -Name "Auth Methods Policy" {
                if ($AuthMethodsPolicy) {
                    New-HTMLSection -HeaderText "General Settings" {
                        New-HTMLTable -DataTable ([PSCustomObject]@{
                                LastModified = $AuthMethodsPolicy.LastModifiedDateTime
                                Description  = $AuthMethodsPolicy.Description
                            }) -Filtering -DataStore JavaScript -DataTableID "TableAuthMethodsGeneral" -ScrollX -WarningAction SilentlyContinue
                    }

                    New-HTMLSection -HeaderText "Authentication Methods Overview" {
                        New-HTMLTable -DataTable $AuthMethodsPolicy.Summary -Filtering {
                            New-HTMLTableCondition -Name 'State' -Value 'enabled' -BackgroundColor LightGreen -ComparisonType string
                            New-HTMLTableCondition -Name 'State' -Value 'disabled' -BackgroundColor LightGray -ComparisonType string
                        } -DataStore JavaScript -DataTableID "TableAuthMethodsSummary" -ScrollX -WarningAction SilentlyContinue
                    }

                    New-HTMLSection -HeaderText "Detailed Method Settings" -Collapsable {
                        foreach ($Method in $AuthMethodsPolicy.Methods.Keys) {
                            $MethodConfig = $AuthMethodsPolicy.Methods.$Method
                            New-HTMLSection -HeaderText $Method -CanCollapse {
                                $settingsData = $null
                                switch ($Method) {
                                    'X509' {
                                        if ($MethodConfig.CertificateUserBindings) {
                                            New-HTMLTable -DataTable $MethodConfig.CertificateUserBindings -Filtering -DataStore JavaScript -DataTableID "TableAuthMethod$($Method)Bindings" -ScrollX -WarningAction SilentlyContinue
                                        }
                                    }
                                    'FIDO2' {
                                        $settingsData = @(
                                            [PSCustomObject]@{ Setting = 'State'; Value = $MethodConfig.State }
                                            [PSCustomObject]@{ Setting = 'Attestation Enforced'; Value = $MethodConfig.IsAttestationEnforced }
                                        )
                                        if ($MethodConfig.KeyRestrictions) {
                                            $settingsData += [PSCustomObject]@{ Setting = 'Key AAGUIDs'; Value = $MethodConfig.KeyRestrictions.AAGUIDs }
                                            $settingsData += [PSCustomObject]@{ Setting = 'Key Enforcement Type'; Value = $MethodConfig.KeyRestrictions.EnforcementType }
                                            $settingsData += [PSCustomObject]@{ Setting = 'Key Restrictions Enforced'; Value = $MethodConfig.KeyRestrictions.IsEnforced }
                                        }
                                        New-HTMLTable -DataTable $settingsData -Filtering -DataStore JavaScript -DataTableID "TableAuthMethod$($Method)Settings" -ScrollX -WarningAction SilentlyContinue
                                    }
                                    default {
                                        # Generic handling for other methods
                                        $settingsData = $MethodConfig.PSObject.Properties | Where-Object { $_.Name -ne 'ExcludeTargets' } | ForEach-Object {
                                            [PSCustomObject]@{ Setting = $_.Name; Value = $_.Value }
                                        }
                                        if ($settingsData) {
                                            New-HTMLTable -DataTable $settingsData -Filtering -DataStore JavaScript -DataTableID "TableAuthMethod$($Method)Settings" -ScrollX -WarningAction SilentlyContinue
                                        }
                                    }
                                } # End Switch

                                if ($MethodConfig.ExcludeTargets -and $MethodConfig.ExcludeTargets.Count -gt 0) {
                                    New-HTMLSection -HeaderText "Excluded Targets" {
                                        New-HTMLTable -DataTable $MethodConfig.ExcludeTargets -Filtering -DataStore JavaScript -DataTableID "TableAuthMethod$($Method)Excludes" -ScrollX -WarningAction SilentlyContinue
                                    }
                                }
                            }
                        }
                    }
                } else {
                    New-HTMLSection -HeaderText "Authentication Methods Policy" {
                        New-HTMLText -Text "Failed to retrieve Authentication Methods Policy data." -Color Red -FontSize 12pt
                    }
                }
            }

            # --- Tab 3: Authentication Strengths ---
            New-HTMLTab -Name "Auth Strengths ($($AuthStrengths.Count))" {
                if ($AuthStrengths) {
                    New-HTMLSection -HeaderText "Authentication Strength Policies" {
                        New-HTMLPanel -Invisible {
                            New-HTMLContainer {
                                New-HTMLText -FontSize 11pt -TextBlock {
                                    "Authentication strength policies define which authentication methods are allowed for accessing resources. "
                                    "These policies can be referenced by conditional access rules to enforce specific authentication requirements based on risk level, application sensitivity, or other criteria."
                                }
                                New-HTMLTable -DataTable $AuthStrengths -Filtering {
                                    New-HTMLTableCondition -Name 'PolicyType' -Value 'Built-in' -BackgroundColor LightBlue -ComparisonType string
                                    New-HTMLTableCondition -Name 'PolicyType' -Value 'Custom' -BackgroundColor LightGreen -ComparisonType string
                                } -DataStore JavaScript -DataTableID "TableAuthStrengths" -PagingLength 10 -ScrollX -ExcludeProperty $ExcludedAuthStrengthProperties -WarningAction SilentlyContinue
                            }
                        }
                    }

                    if ($AuthMethodsUsageTable) {
                        New-HTMLSection -HeaderText "Authentication Methods Usage within Strengths" {
                            New-HTMLPanel -Invisible {
                                New-HTMLContainer {
                                    New-HTMLText -FontSize 11pt -TextBlock {
                                        "This table shows detailed information about each authentication strength policy including the specific authentication methods combinations they allow. "
                                    }
                                    New-HTMLTable -DataTable $AuthMethodsUsageTable -Filtering {
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Built-in' -BackgroundColor LightBlue -ComparisonType string
                                        New-HTMLTableCondition -Name 'PolicyType' -Value 'Custom' -BackgroundColor LightGreen -ComparisonType string
                                    } -DataStore JavaScript -DataTableID "TableAuthMethodsUsage" -PagingLength 10 -ScrollX -WarningAction SilentlyContinue
                                }
                            }
                        }
                    }
                } else {
                    New-HTMLSection -HeaderText "Authentication Strengths" {
                        New-HTMLText -Text "Failed to retrieve Authentication Strength policy data." -Color Red -FontSize 12pt
                    }
                }
            }
        }
    }
}
