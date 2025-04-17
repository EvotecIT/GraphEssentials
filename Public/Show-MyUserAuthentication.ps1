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
    $MFACapable = ($UserAuth | Where-Object { $_.IsMfaCapable }).Count
    $StrongAuth = ($UserAuth | Where-Object { $_.'FIDO2 Security Key' -or $_.'Windows Hello' }).Count
    $PasswordlessCapable = ($UserAuth | Where-Object { $_.IsPasswordlessCapable }).Count
    $StrongWeakAuth = ($UserAuth | Where-Object {
            ($_.'FIDO2 Security Key' -or $_.'Windows Hello') -and
            ($_.'SMS' -or $_.'Email' -or $_.'Voice Call' -or $_.'Alternative Phone')
        }).Count

    # Create overview table
    $OverviewTable = foreach ($User in $UserAuth) {
        [PSCustomObject]@{
            UserPrincipalName  = $User.UserPrincipalName
            DisplayName        = $User.DisplayName
            Enabled            = $User.Enabled
            IsCloudOnly        = $User.IsCloudOnly
            DefaultMfaMethod   = $User.DefaultMfaMethod
            HasMFA             = $User.MFA
            IsPasswordless     = $User.IsPasswordlessCapable
            'Password'         = $User.Pass
            'FIDO2'            = $User.'FIDO2 Security Key'
            'Windows Hello'    = $User.'Windows Hello'
            'MS Authenticator' = $User.'Microsoft Auth App'
            'SMS'              = $User.'SMS'
            'Voice'            = $User.'Voice Call'
            'Email'            = $User.'Email'
            LastSignIn         = $User.LastSignInDateTime
            CreatedDateTime    = $User.CreatedDateTime
        }
    }

    # Create detailed methods table
    $MethodsTable = foreach ($User in $UserAuth) {
        [PSCustomObject]@{
            UserPrincipalName          = $User.UserPrincipalName
            'FIDO2 Details'            = if ($User.FIDO2Keys) {
                ($User.FIDO2Keys | ForEach-Object {
                    if ($_ -is [hashtable]) { "$($_.Model) - $($_.DisplayName)" } else { $_ }
                }) -join ', '
            } else { 'Not configured' }
            'Windows Hello Details'    = if ($User.WindowsHelloForBusiness) {
                ($User.WindowsHelloForBusiness | ForEach-Object {
                    if ($_ -is [hashtable]) { "$($_.DisplayName) ($($_.KeyStrength))" } else { $_ }
                }) -join ', '
            } else { 'Not configured' }
            'MS Authenticator Details' = if ($User.MicrosoftAuthenticator) {
                ($User.MicrosoftAuthenticator | ForEach-Object { "$($_.DisplayName) (v$($_.PhoneAppVersion))" }) -join ', '
            } else { 'Not configured' }
            'Phone Details'            = if ($User.PhoneMethods) {
                ($User.PhoneMethods | ForEach-Object { "$($_.PhoneType): $($_.PhoneNumber) ($($_.SmsSignInState))" }) -join ', '
            } else { 'Not configured' }
            'Email Details'            = if ($User.EmailMethods) {
                ($User.EmailMethods | ForEach-Object { $_.EmailAddress }) -join ', '
            } else { 'Not configured' }
            'Temporary Access Pass'    = if ($User.TemporaryAccessPass) {
                ($User.TemporaryAccessPass | ForEach-Object {
                    "Valid: $($_.IsUsable), Minutes: $($_.LifetimeInMinutes)"
                }) -join ', '
            } else { 'Not configured' }
            'Software Token'           = if ($User.SoftwareOathMethods) {
                ($User.SoftwareOathMethods | ForEach-Object { $_.DisplayName }) -join ', '
            } else { 'Not configured' }
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

        # Statistics Section with Pie Charts
        New-HTMLSection -HeaderText 'Authentication Overview' {
            New-HTMLPanel {
                New-HTMLChart -Title 'MFA Status' {
                    New-ChartPie -Name 'MFA Enabled' -Value $MFACapable
                    New-ChartPie -Name 'No MFA' -Value ($TotalUsers - $MFACapable)
                }
            }
            New-HTMLPanel {
                New-HTMLChart -Title 'Authentication Type Distribution' {
                    New-ChartPie -Name 'Strong Auth' -Value $StrongAuth
                    New-ChartPie -Name 'Weak Auth' -Value ($MFACapable - $StrongAuth)
                    New-ChartPie -Name 'Password Only' -Value ($TotalUsers - $MFACapable)
                }
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

        New-HTMLSection -HeaderText 'All Data' {
            New-HTMLTable -DataTable $UserAuth {
                foreach ($Column in @('Enabled', 'HasMFA', 'IsPasswordless', 'FIDO2', 'Windows Hello', 'MS Authenticator', 'SMS', 'Voice', 'Email')) {
                    New-TableCondition -Name $Column -Value $true -BackgroundColor '#00a36d' -Color White -ComparisonType bool
                    New-TableCondition -Name $Column -Value $false -BackgroundColor '#d13438' -Color White -ComparisonType bool
                }
                New-TableCondition -Name 'IsCloudOnly' -Value $true -BackgroundColor '#0078d4' -Color White -ComparisonType bool
            } -ScrollX -Filtering
        }

        # Authentication Overview Section
        New-HTMLSection -HeaderText 'Authentication Methods Overview' {
            New-HTMLTable -DataTable $OverviewTable {
                foreach ($Column in @('Enabled', 'HasMFA', 'IsPasswordless', 'FIDO2', 'Windows Hello', 'MS Authenticator', 'SMS', 'Voice', 'Email')) {
                    New-TableCondition -Name $Column -Value $true -BackgroundColor '#00a36d' -Color White -ComparisonType bool
                    New-TableCondition -Name $Column -Value $false -BackgroundColor '#d13438' -Color White -ComparisonType bool
                }
                New-TableCondition -Name 'IsCloudOnly' -Value $true -BackgroundColor '#0078d4' -Color White -ComparisonType bool
                #New-TableEvent -ID 'UserAuthDetails' -SourceColumnID 'UserPrincipalName' -TargetColumnID 'UserPrincipalName'
            } -ScrollX -Filtering
        }

        # Authentication Details Section
        New-HTMLSection -HeaderText 'Authentication Methods Details' {
            New-HTMLTable -DataTable $MethodsTable {
                foreach ($Column in @('FIDO2 Details', 'Windows Hello Details', 'MS Authenticator Details', 'Phone Details', 'Email Details', 'Temporary Access Pass', 'Software Token')) {
                    New-TableCondition -Name $Column -Value 'Not configured' -BackgroundColor '#d13438' -Color White -ComparisonType string
                }
            } -ScrollX -Filtering -DataTableID 'UserAuthDetails'
        }
    }
}
