function Show-MyUserAuthentication {
    <#
    .SYNOPSIS
    Generates an HTML report for user authentication methods.

    .DESCRIPTION
    Creates a comprehensive HTML report displaying information about user authentication methods
    including MFA status, FIDO2 keys, phone authentication, Microsoft Authenticator, and other
    authentication methods configured for users in Azure AD/Entra ID.

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
    other authentication device details in the report.

    .EXAMPLE
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuth.html"
    Generates a user authentication methods report and saves it to the specified path.

    .EXAMPLE
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuth.html" -Online
    Generates a user authentication methods report, saves it to the specified path, and opens it in the default browser.

    .EXAMPLE
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuth.html" -UserPrincipalName "user@contoso.com" -IncludeDeviceDetails
    Generates a detailed authentication report for a specific user including device details.

    .NOTES
    This function requires the PSWriteHTML module and appropriate Microsoft Graph permissions.
    #>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $UserPrincipalName,
        [switch] $IncludeDeviceDetails
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    Write-Verbose -Message "Show-MyUserAuthentication - Getting user authentication data"
    $UserAuth = Get-MyUserAuthentication -UserPrincipalName $UserPrincipalName -IncludeDeviceDetails:$IncludeDeviceDetails.IsPresent

    if (-not $UserAuth) {
        Write-Warning -Message "Show-MyUserAuthentication - No user authentication data found"
        return
    }

    # Calculate metrics
    $TotalUsers = $UserAuth.Count
    $MFACapable = ($UserAuth | Where-Object { $_.MethodTypes -match 'microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod' }).Count
    $StrongAuth = ($UserAuth | Where-Object { $_.MethodTypes -match 'fido2AuthenticationMethod|windowsHelloForBusinessAuthenticationMethod' }).Count
    $PasswordlessCapable = ($UserAuth | Where-Object {
            $_.MethodTypes -match 'fido2AuthenticationMethod' -and
            $_.MethodTypes -notmatch 'passwordAuthenticationMethod'
        }).Count
    $StrongWeakAuth = ($UserAuth | Where-Object {
            $_.MethodTypes -match '(fido2AuthenticationMethod|windowsHelloForBusinessAuthenticationMethod)' -and
            $_.MethodTypes -match '(phoneAuthenticationMethod|emailAuthenticationMethod)'
        }).Count

    # Create auth methods detail table
    $AuthMethodsTable = foreach ($User in $UserAuth) {
        [PSCustomObject]@{
            UserId                        = $User.Id
            UserPrincipalName             = $User.UserPrincipalName
            Enabled                       = $User.AccountEnabled
            DisplayName                   = $User.DisplayName
            MFA                           = $User.MethodTypes -match '(microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod)'
            Pass                          = $User.MethodTypes -contains 'passwordAuthenticationMethod'
            'Microsoft Auth Passwordless' = $User.MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod'
            'FIDO2 Security Key'          = $User.MethodTypes -contains 'fido2AuthenticationMethod'
            'Device Bound PushKey'        = $User.MethodTypes -contains 'deviceBasedPushAuthenticationMethod'
            'Microsoft Auth Push'         = $User.MethodTypes -match 'microsoftAuthenticatorAuthenticationMethod'
            'Windows Hello'               = $User.MethodTypes -contains 'windowsHelloForBusinessAuthenticationMethod'
            'Microsoft Auth App'          = $User.MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod'
            'Hardware OTP'                = $User.MethodTypes -contains 'hardwareOathAuthenticationMethod'
            'Temporary Pass'              = $User.MethodTypes -contains 'temporaryAccessPassAuthenticationMethod'
            'MacOS Secure Key'            = $false # Not directly available in Graph API
            'SMS'                         = $User.PhoneMethods.SmsSignInState -contains 'enabled'
            'Email'                       = $User.EmailMethods.Count -gt 0
            'Security Questions'          = $false # Not directly available in Graph API
        }
    }

    Write-Verbose -Message "Show-MyUserAuthentication - Preparing HTML report"
    New-HTML -TitleText "Authentication Methods Report" -Online:$Online.IsPresent -FilePath $FilePath -ShowHTML:$ShowHTML.IsPresent {
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

        # Key metrics section
        New-HTMLSection {
            New-HTMLPanel {
                New-HTMLText -Text "Total Users" -FontSize 14pt -Color '#666666'
                New-HTMLText -Text $TotalUsers -FontSize 24pt -Color '#0078d4'
            }
            New-HTMLPanel {
                New-HTMLText -Text "MFA Capable Users" -FontSize 14pt -Color '#666666'
                New-HTMLText -Text $MFACapable -FontSize 24pt -Color '#0078d4'
                New-HTMLText -Text "$([math]::Round(($MFACapable / $TotalUsers) * 100, 2))% of users" -Color '#666666'
            }
            New-HTMLPanel {
                New-HTMLText -Text "Strong Auth Methods" -FontSize 14pt -Color '#666666'
                New-HTMLText -Text $StrongAuth -FontSize 24pt -Color '#0078d4'
                New-HTMLText -Text "$([math]::Round(($StrongAuth / $TotalUsers) * 100, 2))% of users" -Color '#666666'
            }
            New-HTMLPanel {
                New-HTMLText -Text "Passwordless Capable" -FontSize 14pt -Color '#666666'
                New-HTMLText -Text $PasswordlessCapable -FontSize 24pt -Color '#0078d4'
                New-HTMLText -Text "$([math]::Round(($PasswordlessCapable / $TotalUsers) * 100, 2))% of users" -Color '#666666'
            }
            New-HTMLPanel {
                New-HTMLText -Text "Strong + Weak Auth" -FontSize 14pt -Color '#666666'
                New-HTMLText -Text $StrongWeakAuth -FontSize 24pt -Color '#0078d4'
                New-HTMLText -Text "$([math]::Round(($StrongWeakAuth / $TotalUsers) * 100, 2))% of users" -Color '#666666'
            }
        }

        # Statistics Section with Pie Charts
        New-HTMLSection -HeaderText 'Authentication Overview' {
            New-HTMLPanel {
                New-HTMLChart -Title 'MFA Status' {
                    New-ChartPie -Name 'MFA Enabled' -Value $MFACapable
                    New-ChartPie -Name 'No MFA' -Value ($TotalUsers - $MFACapable)
                }
            }
            New-HTMLPanel {
                New-HTMLChart -Title 'Authentication Type' {
                    New-ChartPie -Name 'Strong Auth' -Value $StrongAuth
                    New-ChartPie -Name 'Weak Auth' -Value ($MFACapable - $StrongAuth)
                    New-ChartPie -Name 'Password Only' -Value ($TotalUsers - $MFACapable)
                }
            }
        }

        # Authentication Methods Section with Table
        New-HTMLSection -HeaderText 'Authentication Methods Details' {
            New-HTMLTable -DataTable $AuthMethodsTable {
                $Columns = @('MFA', 'Pass', 'Microsoft Auth Passwordless', 'FIDO2 Security Key',
                    'Device Bound PushKey', 'Microsoft Auth Push', 'Windows Hello',
                    'Microsoft Auth App', 'Hardware OTP', 'Temporary Pass',
                    'MacOS Secure Key', 'SMS', 'Email', 'Security Questions')
                foreach ($Column in $Columns) {
                    New-TableCondition -Name $Column -Value $true -BackgroundColor '#00a36d' -Color White -ComparisonType bool
                    New-TableCondition -Name $Column -Value $false -BackgroundColor '#d13438' -Color White -ComparisonType bool
                }
            } -HideFooter -ScrollX -PagingLength 15 -Filtering
        }
    }
}
