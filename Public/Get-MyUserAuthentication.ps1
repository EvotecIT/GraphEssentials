function Get-MyUserAuthentication {
    <#
    .SYNOPSIS
    Retrieves detailed authentication method information for users from Microsoft Graph API.

    .DESCRIPTION
    Gets comprehensive authentication method information for users including MFA status,
    registered authentication methods (FIDO2, Phone, SMS, Email, etc.), and detailed
    configuration of each method. The function provides a detailed view of how users
    are authenticating in your Azure AD/Entra ID environment.

    .PARAMETER UserPrincipalName
    Optional. The UserPrincipalName of a specific user to retrieve authentication information for.
    If not specified, returns information for all users.

    .PARAMETER IncludeDeviceDetails
    When specified, includes detailed information about FIDO2 security keys and
    other authentication device details.

    .EXAMPLE
    Get-MyUserAuthentication
    Returns authentication method information for all users.

    .EXAMPLE
    Get-MyUserAuthentication -UserPrincipalName "user@contoso.com"
    Returns authentication method information for a specific user.

    .EXAMPLE
    Get-MyUserAuthentication -IncludeDeviceDetails
    Returns authentication method information including detailed device information for all users.

    .NOTES
    This function requires the Microsoft.Graph.Users and Microsoft.Graph.Identity.SignIns modules
    with appropriate permissions. Typically requires UserAuthenticationMethod.Read.All permission.
    #>
    [CmdletBinding()]
    param(
        [string] $UserPrincipalName,
        [switch] $IncludeDeviceDetails
    )

    try {
        Write-Verbose -Message "Get-MyUserAuthentication - Getting users"

        # Define required properties to minimize API data transfer
        $Properties = @(
            'accountEnabled'
            'displayName'
            'id'
            'userPrincipalName'
            'onPremisesSyncEnabled'
            'createdDateTime'
            'signInActivity'
        )

        # Get user(s) based on parameter
        if ($UserPrincipalName) {
            $Users = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -Property $Properties -ErrorAction Stop
        } else {
            $Users = Get-MgUser -All -Property $Properties -ErrorAction Stop
        }

        Write-Verbose -Message "Get-MyUserAuthentication - Retrieved $($Users.Count) users"

        foreach ($User in $Users) {
            Write-Verbose -Message "Get-MyUserAuthentication - Processing methods for $($User.UserPrincipalName)"

            try {
                # Get authentication methods for the user
                $AuthMethods = Get-MgUserAuthenticationMethod -UserId $User.Id -ErrorAction Stop

                # Initialize collections for different method types
                $Fido2Keys = @()
                $PhoneMethods = @()
                $EmailMethods = @()
                $MicrosoftAuthenticator = @()
                $TemporaryAccessPass = @()
                $WindowsHelloMethods = @()
                $PasswordMethods = @()
                $SoftwareOath = @()

                foreach ($Method in $AuthMethods) {
                    $MethodDetail = $null

                    switch ($Method.AdditionalProperties["@odata.type"]) {
                        "#microsoft.graph.fido2AuthenticationMethod" {
                            if ($IncludeDeviceDetails) {
                                $MethodDetail = Get-MgUserAuthenticationFido2Method -UserId $User.Id -Fido2AuthenticationMethodId $Method.Id
                                $Fido2Keys += @{
                                    Model           = $MethodDetail.Model
                                    DisplayName     = $MethodDetail.DisplayName
                                    CreatedDateTime = $MethodDetail.CreatedDateTime
                                    AAGuid          = $MethodDetail.AaGuid
                                }
                            } else {
                                $Fido2Keys += $Method.AdditionalProperties["displayName"]
                            }
                        }
                        "#microsoft.graph.phoneAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationPhoneMethod -UserId $User.Id -PhoneAuthenticationMethodId $Method.Id
                            $PhoneMethods += @{
                                PhoneNumber    = $MethodDetail.PhoneNumber
                                PhoneType      = $MethodDetail.PhoneType
                                SmsSignInState = $MethodDetail.SmsSignInState
                            }
                        }
                        "#microsoft.graph.emailAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationEmailMethod -UserId $User.Id -EmailAuthenticationMethodId $Method.Id
                            $EmailMethods += @{
                                EmailAddress = $MethodDetail.EmailAddress
                            }
                        }
                        "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $User.Id `
                                -MicrosoftAuthenticatorAuthenticationMethodId $Method.Id
                            $MicrosoftAuthenticator += @{
                                DisplayName     = $MethodDetail.DisplayName
                                DeviceTag       = $MethodDetail.DeviceTag
                                PhoneAppVersion = $MethodDetail.PhoneAppVersion
                            }
                        }
                        "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $User.Id `
                                -TemporaryAccessPassAuthenticationMethodId $Method.Id
                            $TemporaryAccessPass += @{
                                LifetimeInMinutes     = $MethodDetail.LifetimeInMinutes
                                IsUsable              = $MethodDetail.IsUsable
                                MethodUsabilityReason = $MethodDetail.MethodUsabilityReason
                            }
                        }
                        "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                            if ($IncludeDeviceDetails) {
                                $MethodDetail = Get-MgUserAuthenticationWindowsHelloForBusinessMethod -UserId $User.Id `
                                    -WindowsHelloForBusinessAuthenticationMethodId $Method.Id
                                $WindowsHelloMethods += @{
                                    DisplayName     = $MethodDetail.DisplayName
                                    CreatedDateTime = $MethodDetail.CreatedDateTime
                                    KeyStrength     = $MethodDetail.KeyStrength
                                    Device          = $MethodDetail.Device.DisplayName
                                }
                            } else {
                                $WindowsHelloMethods += $Method.AdditionalProperties["displayName"]
                            }
                        }
                        "#microsoft.graph.passwordAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationPasswordMethod -UserId $User.Id `
                                -PasswordAuthenticationMethodId $Method.Id
                            $PasswordMethods += @{
                                CreatedDateTime = $MethodDetail.CreatedDateTime
                            }
                        }
                        "#microsoft.graph.softwareOathAuthenticationMethod" {
                            $MethodDetail = Get-MgUserAuthenticationSoftwareOathMethod -UserId $User.Id `
                                -SoftwareOathAuthenticationMethodId $Method.Id
                            $SoftwareOath += @{
                                DisplayName = $MethodDetail.DisplayName
                            }
                        }
                    }
                }

                # Calculate MFA and passwordless status
                $methodTypes = $AuthMethods.AdditionalProperties."@odata.type"
                $isMfaCapable = $methodTypes -match 'microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod'
                $isPasswordlessCapable = ($methodTypes -match 'fido2AuthenticationMethod') -and
                ($methodTypes -notmatch 'passwordAuthenticationMethod')

                # Determine default MFA method
                $defaultMethod = 'none'
                if ($MicrosoftAuthenticator) { $defaultMethod = 'Microsoft Authenticator' }
                elseif ($Fido2Keys) { $defaultMethod = 'FIDO2 Security Key' }
                elseif ($PhoneMethods) { $defaultMethod = 'Phone' }
                elseif ($WindowsHelloMethods) { $defaultMethod = 'Windows Hello' }

                # Create output object with all authentication information
                [PSCustomObject]@{
                    DisplayName                      = $User.DisplayName
                    UserPrincipalName                = $User.UserPrincipalName
                    AccountEnabled                   = $User.AccountEnabled
                    IsEnabled                        = $User.AccountEnabled
                    Id                               = $User.Id
                    CreatedDateTime                  = $User.CreatedDateTime
                    IsCloudOnly                      = -not $User.OnPremisesSyncEnabled
                    OnPremisesSyncEnabled            = $User.OnPremisesSyncEnabled
                    IsMfaCapable                     = $isMfaCapable
                    IsPasswordlessCapable            = $isPasswordlessCapable
                    FIDO2Keys                        = $Fido2Keys
                    PhoneMethods                     = $PhoneMethods
                    EmailMethods                     = $EmailMethods
                    MicrosoftAuthenticator           = $MicrosoftAuthenticator
                    TemporaryAccessPass              = $TemporaryAccessPass
                    WindowsHelloForBusiness          = $WindowsHelloMethods
                    PasswordMethods                  = $PasswordMethods
                    SoftwareOathMethods              = $SoftwareOath
                    TotalMethodsCount                = $AuthMethods.Count
                    MethodTypes                      = $methodTypes | ForEach-Object { $_ -replace '#microsoft.graph.', '' }
                    DefaultMfaMethod                 = $defaultMethod
                    LastSignInDateTime               = $User.SignInActivity.LastSignInDateTime
                    LastNonInteractiveSignInDateTime = $User.SignInActivity.LastNonInteractiveSignInDateTime
                }
            } catch {
                Write-Warning -Message "Get-MyUserAuthentication - Failed to get authentication methods for $($User.UserPrincipalName). Error: $($_.Exception.Message)"
                continue
            }
        }
    } catch {
        Write-Warning -Message "Get-MyUserAuthentication - Failed to get users. Error: $($_.Exception.Message)"
    }
}
