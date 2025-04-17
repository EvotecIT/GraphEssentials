function New-MyUserAuthenticationObject {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$User,

        [Parameter(Mandatory)]
        [array]$AuthMethods, # Summary methods for this user

        [Parameter(Mandatory)]
        [array]$MethodTypes, # Derived from AuthMethods (@odata.type)

        [Parameter(Mandatory)]
        [hashtable]$Details, # Populated details hashtable for this user

        [Parameter(Mandatory)]
        [datetime]$Today
    )

    # Calculate Default MFA Method (Example logic, might need refinement based on policy)
    $defaultMfaMethod = 'none'
    if ($Details.MicrosoftAuthenticator.Count -gt 0) {
        $defaultMfaMethod = 'Microsoft Authenticator'
    } elseif ($Details.Fido2Keys.Count -gt 0) {
        $defaultMfaMethod = 'FIDO2 Security Key'
    } elseif ($Details.PhoneMethods.Count -gt 0) {
        $defaultMfaMethod = 'Phone'
    } elseif ($Details.WindowsHelloMethods.Count -gt 0) {
        $defaultMfaMethod = 'Windows Hello'
    } elseif ($Details.SoftwareOath.Count -gt 0) {
        $defaultMfaMethod = 'Software Oath'
    }

    # Build the final object
    $resultObject = [PSCustomObject]@{
        UserId                           = $User.Id
        UserPrincipalName                = $User.UserPrincipalName
        Enabled                          = $User.AccountEnabled
        DisplayName                      = $User.DisplayName
        CreatedDateTime                  = $User.CreatedDateTime
        IsCloudOnly                      = -not $User.OnPremisesSyncEnabled
        LastSignInDateTime               = if ($User.SignInActivity) { $User.SignInActivity.LastSignInDateTime } else { $null }
        LastSignInDaysAgo                = if ($User.SignInActivity -and $User.SignInActivity.LastSignInDateTime) { [math]::Round((New-TimeSpan -Start $User.SignInActivity.LastSignInDateTime -End $Today).TotalDays, 0) } else { $null }
        LastNonInteractiveSignInDateTime = if ($User.SignInActivity) { $User.SignInActivity.LastNonInteractiveSignInDateTime } else { $null }
        LastNonInteractiveSignInDaysAgo  = if ($User.SignInActivity -and $User.SignInActivity.LastNonInteractiveSignInDateTime) { [math]::Round((New-TimeSpan -Start $User.SignInActivity.LastNonInteractiveSignInDateTime -End $Today).TotalDays, 0) } else { $null }

        # Authentication Status
        DefaultMfaMethod                 = $defaultMfaMethod
        IsMfaCapable                     = $MethodTypes -match '(microsoftAuthenticatorAuthenticationMethod|phoneAuthenticationMethod|fido2AuthenticationMethod|softwareOathAuthenticationMethod)' | Sort-Object -Unique
        IsPasswordlessCapable            = $MethodTypes -match '(fido2AuthenticationMethod|windowsHelloForBusinessAuthenticationMethod)' -and (-not $Details.PasswordMethods)

        # Method Types (Boolean Flags)
        'PasswordMethod'                 = $Details.PasswordMethods # This is just a boolean derived earlier
        'Microsoft Auth Passwordless'    = $MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod' # Check specific type
        'FIDO2 Security Key'             = $MethodTypes -contains 'fido2AuthenticationMethod'
        'Device Bound PushKey'           = $MethodTypes -contains 'deviceBasedPushAuthenticationMethod' # Keep if needed, rare
        'Microsoft Auth Push'            = $MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod' # Same as passwordless bool for now
        'Windows Hello'                  = $MethodTypes -contains 'windowsHelloForBusinessAuthenticationMethod'
        'Microsoft Auth App'             = $MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod' # Same as passwordless bool for now
        'Hardware OTP'                   = $MethodTypes -contains 'hardwareOathAuthenticationMethod' # Requires detail call not implemented yet
        'Software OTP'                   = $MethodTypes -contains 'softwareOathAuthenticationMethod'
        'Temporary Pass'                 = $MethodTypes -contains 'temporaryAccessPassAuthenticationMethod'
        #'MacOS Secure Key'               = $false # Not directly available
        'SMS'                            = $Details.PhoneMethods.SmsSignInState -contains 'ready' # Changed from 'enabled' to 'ready' based on docs
        'Email'                          = $Details.EmailMethods.Count -gt 0
        #'Security Questions'             = $false # Not available
        'Voice Call'                     = ($Details.PhoneMethods | Where-Object { $_.PhoneType -eq 'mobile' -or $_.PhoneType -eq 'alternateMobile' -or $_.PhoneType -eq 'office' }).Count -gt 0 # Check specific types
        'Alternative Phone'              = ($Details.PhoneMethods | Where-Object { $_.PhoneType -eq 'alternateMobile' }).Count -gt 0 # Specific check

        # Method Details
        FIDO2Keys                        = $Details.Fido2Keys
        PhoneMethods                     = $Details.PhoneMethods
        EmailMethods                     = $Details.EmailMethods
        MicrosoftAuthenticator           = $Details.MicrosoftAuthenticator
        TemporaryAccessPass              = $Details.TemporaryAccessPass
        WindowsHelloForBusiness          = $Details.WindowsHelloMethods
        PasswordMethodRegistered         = $Details.PasswordMethods # Renamed for clarity
        SoftwareOathMethods              = $Details.SoftwareOath

        # Additional Info
        TotalMethodsCount                = $AuthMethods.Count
        MethodTypesRegistered            = $MethodTypes | Sort-Object -Unique # Renamed for clarity
    }
    $resultObject
}