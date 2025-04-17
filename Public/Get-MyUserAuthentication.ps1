function Get-MyUserAuthentication {
    <#
    .SYNOPSIS
    Retrieves detailed authentication method information for users from Microsoft Graph API.

    .DESCRIPTION
    Gets comprehensive authentication method information for users including MFA status,
    registered authentication methods (FIDO2, Phone, SMS, Email, etc.), and detailed
    configuration of each method. The function provides a detailed view of how users
    are authenticating in your Azure AD/Entra ID environment.

    Returns an array of objects with authentication details and status for each method type.

    .PARAMETER UserPrincipalName
    Optional. The UserPrincipalName of a specific user to retrieve authentication information for.
    If not specified, returns information for all users.

    .PARAMETER IncludeDeviceDetails
    When specified, includes detailed information about FIDO2 security keys and
    other authentication device details.
    #>
    [CmdletBinding()]
    param(
        [string] $UserPrincipalName,
        [switch] $IncludeDeviceDetails
    )

    $Today = Get-Date

    try {
        Write-Verbose -Message "Get-MyUserAuthentication - Getting users"

        # Get users in one call with required properties
        $Properties = @(
            'accountEnabled'
            'displayName'
            'id'
            'userPrincipalName'
            'onPremisesSyncEnabled'
            'createdDateTime'
            'signInActivity'
        )

        if ($UserPrincipalName) {
            $Users = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -Property $Properties -ErrorAction Stop
        } else {
            $Users = Get-MgUser -All -Property $Properties -ErrorAction Stop
        }

        Write-Verbose -Message "Get-MyUserAuthentication - Retrieved $($Users.Count) users"

        $Results = foreach ($User in $Users) {
            try {
                # Get authentication methods for the user
                $AuthMethods = Get-MgUserAuthenticationMethod -UserId $User.Id -ErrorAction Stop
                $MethodTypes = $AuthMethods.AdditionalProperties."@odata.type" | ForEach-Object { $_ -replace '#microsoft.graph.', '' }

                # Initialize collections
                $Details = @{
                    Fido2Keys              = @()
                    PhoneMethods           = @()
                    EmailMethods           = @()
                    MicrosoftAuthenticator = @()
                    TemporaryAccessPass    = @()
                    WindowsHelloMethods    = @()
                    PasswordMethods        = @()
                    SoftwareOath           = @()
                }

                # Process each method and gather details
                foreach ($Method in $AuthMethods) {
                    $MethodDetail = $null
                    switch ($Method.AdditionalProperties."@odata.type") {
                        "#microsoft.graph.fido2AuthenticationMethod" {
                            if ($IncludeDeviceDetails) {
                                $MethodDetail = Get-MgUserAuthenticationFido2Method -UserId $User.Id -Fido2AuthenticationMethodId $Method.Id
                                $Details.Fido2Keys += @{
                                    Model           = $MethodDetail.Model
                                    DisplayName     = $MethodDetail.DisplayName
                                    CreatedDateTime = $MethodDetail.CreatedDateTime
                                    AAGuid          = $MethodDetail.AaGuid
                                }
                            } else {
                                $Details.Fido2Keys += $Method.AdditionalProperties.displayName
                            }
                        }
                        "#microsoft.graph.phoneAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationPhoneMethod -UserId $User.Id -PhoneAuthenticationMethodId $Method.Id
                            $Details.PhoneMethods += @{
                                PhoneNumber    = $MethodDetail.PhoneNumber
                                PhoneType      = $MethodDetail.PhoneType
                                SmsSignInState = $MethodDetail.SmsSignInState
                            }
                        }
                        "#microsoft.graph.emailAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationEmailMethod -UserId $User.Id -EmailAuthenticationMethodId $Method.Id
                            $Details.EmailMethods += @{
                                EmailAddress = $MethodDetail.EmailAddress
                            }
                        }
                        "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $User.Id -MicrosoftAuthenticatorAuthenticationMethodId $Method.Id
                            $Details.MicrosoftAuthenticator += @{
                                DisplayName     = $MethodDetail.DisplayName
                                DeviceTag       = $MethodDetail.DeviceTag
                                PhoneAppVersion = $MethodDetail.PhoneAppVersion
                            }
                        }
                        "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $User.Id -TemporaryAccessPassAuthenticationMethodId $Method.Id
                            $Details.TemporaryAccessPass += @{
                                LifetimeInMinutes     = $MethodDetail.LifetimeInMinutes
                                IsUsable              = $MethodDetail.IsUsable
                                MethodUsabilityReason = $MethodDetail.MethodUsabilityReason
                            }
                        }
                        "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                            if ($IncludeDeviceDetails) {
                                $MethodDetail = Get-MgUserAuthenticationWindowsHelloForBusinessMethod -UserId $User.Id -WindowsHelloForBusinessAuthenticationMethodId $Method.Id
                                $Details.WindowsHelloMethods += @{
                                    DisplayName     = $MethodDetail.DisplayName
                                    CreatedDateTime = $MethodDetail.CreatedDateTime
                                    KeyStrength     = $MethodDetail.KeyStrength
                                    Device          = $MethodDetail.Device.DisplayName
                                }
                            } else {
                                $Details.WindowsHelloMethods += $Method.AdditionalProperties.displayName
                            }
                        }
                        "#microsoft.graph.softwareOathAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationSoftwareOathMethod -UserId $User.Id -SoftwareOathAuthenticationMethodId $Method.Id
                            $Details.SoftwareOath += @{
                                DisplayName = $MethodDetail.DisplayName
                            }
                        }
                    }
                }

                # Create output object with all authentication information
                [PSCustomObject]@{
                    UserId                           = $User.Id
                    UserPrincipalName                = $User.UserPrincipalName
                    Enabled                          = $User.AccountEnabled
                    DisplayName                      = $User.DisplayName
                    CreatedDateTime                  = $User.CreatedDateTime
                    IsCloudOnly                      = -not $User.OnPremisesSyncEnabled
                    #OnPremisesSyncEnabled            = $User.OnPremisesSyncEnabled
                    LastSignInDateTime               = $User.SignInActivity.LastSignInDateTime
                    LastSignInDaysAgo                = if ($User.SignInActivity.LastSignInDateTime) {
                        [math]::Round((New-TimeSpan -Start $User.SignInActivity.LastSignInDateTime -End ($Today)).TotalDays, 0)
                    } else {
                        $null
                    }
                    LastNonInteractiveSignInDateTime = $User.SignInActivity.LastNonInteractiveSignInDateTime
                    LastNonInteractiveSignInDaysAgo  = if ($User.SignInActivity.LastNonInteractiveSignInDateTime) {
                        [math]::Round((New-TimeSpan -Start $User.SignInActivity.LastNonInteractiveSignInDateTime -End ($Today)).TotalDays, 0)
                    } else {
                        $null
                    }

                    # Authentication Status
                    MFA                              = $MethodTypes -match '(microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod)'
                    PasswordMethod                   = $MethodTypes -contains 'passwordAuthenticationMethod'
                    IsMfaCapable                     = $MethodTypes -match '(microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod)'
                    IsPasswordlessCapable            = ($MethodTypes -match 'fido2AuthenticationMethod') -and (-not ($MethodTypes -match 'passwordAuthenticationMethod'))

                    # Method Types (Boolean)
                    'Microsoft Auth Passwordless'    = $MethodTypes -match 'microsoftAuthenticatorAuthenticationMethod'
                    'FIDO2 Security Key'             = $MethodTypes -match 'fido2AuthenticationMethod'
                    'Device Bound PushKey'           = $MethodTypes -match 'deviceBasedPushAuthenticationMethod'
                    'Microsoft Auth Push'            = $MethodTypes -match 'microsoftAuthenticatorAuthenticationMethod'
                    'Windows Hello'                  = $MethodTypes -match 'windowsHelloForBusinessAuthenticationMethod'
                    'Microsoft Auth App'             = $MethodTypes -match 'microsoftAuthenticatorAuthenticationMethod'
                    'Hardware OTP'                   = $MethodTypes -match 'hardwareOathAuthenticationMethod'
                    'Temporary Pass'                 = $MethodTypes -match 'temporaryAccessPassAuthenticationMethod'
                    'MacOS Secure Key'               = $false # Not directly available in Graph API
                    'SMS'                            = $Details.PhoneMethods.SmsSignInState -contains 'enabled'
                    'Email'                          = $Details.EmailMethods.Count -gt 0
                    'Security Questions'             = $false # Not directly available in Graph API
                    'Voice Call'                     = $Details.PhoneMethods.PhoneType -contains 'voice'
                    'Alternative Phone'              = $Details.PhoneMethods.Count -gt 1

                    # Method Details
                    FIDO2Keys                        = $Details.Fido2Keys
                    PhoneMethods                     = $Details.PhoneMethods
                    EmailMethods                     = $Details.EmailMethods
                    MicrosoftAuthenticator           = $Details.MicrosoftAuthenticator
                    TemporaryAccessPass              = $Details.TemporaryAccessPass
                    WindowsHelloForBusiness          = $Details.WindowsHelloMethods
                    PasswordMethods                  = $Details.PasswordMethods
                    SoftwareOathMethods              = $Details.SoftwareOath

                    # Additional Info
                    TotalMethodsCount                = $AuthMethods.Count
                    MethodTypes                      = $MethodTypes
                    DefaultMfaMethod                 = if ($Details.MicrosoftAuthenticator) { 'Microsoft Authenticator' }
                    elseif ($Details.Fido2Keys) { 'FIDO2 Security Key' }
                    elseif ($Details.PhoneMethods) { 'Phone' }
                    elseif ($Details.WindowsHelloMethods) { 'Windows Hello' }
                    else { 'none' }
                }
            } catch {
                Write-Warning -Message "Get-MyUserAuthentication - Failed to get authentication methods for $($User.UserPrincipalName). Error: $($_.Exception.Message)"
                continue
            }
        }

        # Return results
        $Results
    } catch {
        Write-Warning -Message "Get-MyUserAuthentication - Failed to get users. Error: $($_.Exception.Message)"
    }
}
