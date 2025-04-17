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
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuthentication.html"
    Generates a user authentication methods report and saves it to the specified path.

    .EXAMPLE
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuthentication.html" -Online
    Generates a user authentication methods report, saves it to the specified path, and opens it in the default browser.

    .EXAMPLE
    Show-MyUserAuthentication -FilePath "C:\Reports\UserAuthentication.html" -UserPrincipalName "user@contoso.com" -IncludeDeviceDetails
    Generates a detailed authentication report for a specific user including device details.

    .NOTES
    This function requires the PSWriteHTML module and appropriate Microsoft Graph permissions
    (typically UserAuthenticationMethod.Read.All).
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

    Write-Verbose -Message "Show-MyUserAuthentication - Preparing HTML report"
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

        New-HTMLTab -Name "User Authentication Overview" {
            New-HTMLSection -HeaderText "User Authentication Methods Summary" {
                New-HTMLPanel -Invisible {
                    New-HTMLContainer {
                        New-HTMLText -FontSize 11pt -TextBlock {
                            "This report provides an overview of authentication methods configured for users in your Azure AD/Entra ID environment. "
                            "Users may have multiple authentication methods configured, and this report shows both the primary and secondary methods available."
                        }
                    }

                    # Create summary overview
                    $Summary = @(
                        [PSCustomObject]@{
                            'Total Users' = $UserAuth.Count
                            'Users with FIDO2' = ($UserAuth | Where-Object { $_.FIDO2Keys.Count -gt 0 }).Count
                            'Users with Phone Auth' = ($UserAuth | Where-Object { $_.PhoneMethods.Count -gt 0 }).Count
                            'Users with MS Authenticator' = ($UserAuth | Where-Object { $_.MicrosoftAuthenticator.Count -gt 0 }).Count
                            'Users with Email Auth' = ($UserAuth | Where-Object { $_.EmailMethods.Count -gt 0 }).Count
                            'Users with Windows Hello' = ($UserAuth | Where-Object { $_.WindowsHelloForBusiness.Count -gt 0 }).Count
                        }
                    )

                    New-HTMLTable -DataTable $Summary -Filtering -HideButtons -DisableSearch -DisablePaging
                }
            }

            New-HTMLSection -HeaderText "User Authentication Details" {
                New-HTMLTable -DataTable $UserAuth -Filtering {
                    New-HTMLTableCondition -Name 'IsEnabled' -Value $true -BackgroundColor LightGreen -ComparisonType boolean
                    New-HTMLTableCondition -Name 'IsEnabled' -Value $false -BackgroundColor LightGray -ComparisonType boolean
                    New-HTMLTableCondition -Name 'TotalMethodsCount' -Value 1 -Operator le -BackgroundColor Orange -ComparisonType number
                } -DataStore JavaScript -DataTableID "TableUserAuth" -PagingLength 10 -ScrollX
            }
        }

        if ($IncludeDeviceDetails) {
            New-HTMLTab -Name "FIDO2 Keys & Device Details" {
                New-HTMLSection -HeaderText "FIDO2 Security Keys" {
                    $Fido2Details = foreach ($User in $UserAuth | Where-Object { $_.FIDO2Keys.Count -gt 0 }) {
                        foreach ($Key in $User.FIDO2Keys) {
                            [PSCustomObject]@{
                                UserPrincipalName = $User.UserPrincipalName
                                DisplayName = $User.DisplayName
                                KeyModel = $Key.Model
                                KeyName = $Key.DisplayName
                                CreatedDateTime = $Key.CreatedDateTime
                                AAGuid = $Key.AAGuid
                            }
                        }
                    }

                    if ($Fido2Details) {
                        New-HTMLTable -DataTable $Fido2Details -Filtering -DataStore JavaScript -DataTableID "TableFido2" -PagingLength 10 -ScrollX
                    } else {
                        New-HTMLText -Text "No FIDO2 security keys found." -Color Orange -FontSize 11pt
                    }
                }

                New-HTMLSection -HeaderText "Windows Hello for Business" {
                    $WHfBDetails = foreach ($User in $UserAuth | Where-Object { $_.WindowsHelloForBusiness.Count -gt 0 }) {
                        foreach ($Device in $User.WindowsHelloForBusiness) {
                            [PSCustomObject]@{
                                UserPrincipalName = $User.UserPrincipalName
                                DisplayName = $User.DisplayName
                                DeviceName = $Device.DisplayName
                                CreatedDateTime = $Device.CreatedDateTime
                                KeyStrength = $Device.KeyStrength
                                Device = $Device.Device
                            }
                        }
                    }

                    if ($WHfBDetails) {
                        New-HTMLTable -DataTable $WHfBDetails -Filtering -DataStore JavaScript -DataTableID "TableWHfB" -PagingLength 10 -ScrollX
                    } else {
                        New-HTMLText -Text "No Windows Hello for Business devices found." -Color Orange -FontSize 11pt
                    }
                }
            }
        }

        New-HTMLTab -Name "Phone & Email Methods" {
            New-HTMLSection -HeaderText "Phone Authentication Methods" {
                $PhoneDetails = foreach ($User in $UserAuth | Where-Object { $_.PhoneMethods.Count -gt 0 }) {
                    foreach ($Phone in $User.PhoneMethods) {
                        [PSCustomObject]@{
                            UserPrincipalName = $User.UserPrincipalName
                            DisplayName = $User.DisplayName
                            PhoneNumber = $Phone.PhoneNumber
                            PhoneType = $Phone.PhoneType
                            SmsSignInState = $Phone.SmsSignInState
                        }
                    }
                }

                if ($PhoneDetails) {
                    New-HTMLTable -DataTable $PhoneDetails -Filtering -DataStore JavaScript -DataTableID "TablePhone" -PagingLength 10 -ScrollX
                } else {
                    New-HTMLText -Text "No phone authentication methods found." -Color Orange -FontSize 11pt
                }
            }

            New-HTMLSection -HeaderText "Email Authentication Methods" {
                $EmailDetails = foreach ($User in $UserAuth | Where-Object { $_.EmailMethods.Count -gt 0 }) {
                    foreach ($Email in $User.EmailMethods) {
                        [PSCustomObject]@{
                            UserPrincipalName = $User.UserPrincipalName
                            DisplayName = $User.DisplayName
                            EmailAddress = $Email.EmailAddress
                        }
                    }
                }

                if ($EmailDetails) {
                    New-HTMLTable -DataTable $EmailDetails -Filtering -DataStore JavaScript -DataTableID "TableEmail" -PagingLength 10 -ScrollX
                } else {
                    New-HTMLText -Text "No email authentication methods found." -Color Orange -FontSize 11pt
                }
            }
        }

        New-HTMLTab -Name "Microsoft Authenticator" {
            New-HTMLSection -HeaderText "Microsoft Authenticator Apps" {
                $AuthenticatorDetails = foreach ($User in $UserAuth | Where-Object { $_.MicrosoftAuthenticator.Count -gt 0 }) {
                    foreach ($Auth in $User.MicrosoftAuthenticator) {
                        [PSCustomObject]@{
                            UserPrincipalName = $User.UserPrincipalName
                            DisplayName = $User.DisplayName
                            DeviceName = $Auth.DisplayName
                            DeviceTag = $Auth.DeviceTag
                            AppVersion = $Auth.PhoneAppVersion
                        }
                    }
                }

                if ($AuthenticatorDetails) {
                    New-HTMLTable -DataTable $AuthenticatorDetails -Filtering -DataStore JavaScript -DataTableID "TableAuthenticator" -PagingLength 10 -ScrollX
                } else {
                    New-HTMLText -Text "No Microsoft Authenticator apps found." -Color Orange -FontSize 11pt
                }
            }
        }

        New-HTMLTab -Name "Sign-in Activity" {
            New-HTMLSection -HeaderText "User Sign-in Activity" {
                $SignInDetails = $UserAuth | Select-Object UserPrincipalName, DisplayName, LastSignInDateTime, LastNonInteractiveSignInDateTime, IsEnabled, TotalMethodsCount

                New-HTMLTable -DataTable $SignInDetails -Filtering {
                    New-HTMLTableCondition -Name 'IsEnabled' -Value $true -BackgroundColor LightGreen -ComparisonType boolean
                    New-HTMLTableCondition -Name 'IsEnabled' -Value $false -BackgroundColor LightGray -ComparisonType boolean
                    New-HTMLTableCondition -Name 'TotalMethodsCount' -Value 1 -Operator le -BackgroundColor Orange -ComparisonType number
                } -DataStore JavaScript -DataTableID "TableSignIn" -PagingLength 10 -ScrollX
            }
        }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}
