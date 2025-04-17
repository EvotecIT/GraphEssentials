function ConvertTo-MyFormattedUserAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$UserAuthData
    )

    if (-not $UserAuthData) {
        return @()
    }

    Write-Verbose "ConvertTo-MyFormattedUserAuth: Formatting $($UserAuthData.Count) user records for display."
    $FormattedData = foreach ($User in $UserAuthData) {
        [PSCustomObject]@{ # Indentation fixed
            # Copy simple properties directly
            UserPrincipalName                = $User.UserPrincipalName
            DisplayName                      = $User.DisplayName
            Enabled                          = $User.Enabled
            IsCloudOnly                      = $User.IsCloudOnly
            LastSignInDateTime               = $User.LastSignInDateTime
            LastSignInDaysAgo                = $User.LastSignInDaysAgo
            LastNonInteractiveSignInDateTime = $User.LastNonInteractiveSignInDateTime
            LastNonInteractiveSignInDaysAgo  = $User.LastNonInteractiveSignInDaysAgo
            MFA                              = $User.MFA
            PasswordMethodRegistered         = $User.PasswordMethodRegistered
            IsMfaCapable                     = $User.IsMfaCapable
            IsPasswordlessCapable            = $User.IsPasswordlessCapable
            'Microsoft Auth Passwordless'    = $User.'Microsoft Auth Passwordless'
            'FIDO2 Security Key'             = $User.'FIDO2 Security Key'
            'Device Bound PushKey'           = $User.'Device Bound PushKey'
            'Microsoft Auth Push'            = $User.'Microsoft Auth Push'
            'Windows Hello'                  = $User.'Windows Hello'
            'Microsoft Auth App'             = $User.'Microsoft Auth App'
            'Hardware OTP'                   = $User.'Hardware OTP'
            'Software OTP'                   = $User.'Software OTP'
            'Temporary Pass'                 = $User.'Temporary Pass'
            'SMS'                            = $User.'SMS'
            'Email'                          = $User.'Email'
            'Voice Call'                     = $User.'Voice Call'
            'Alternative Phone'              = $User.'Alternative Phone'
            TotalMethodsCount                = $User.TotalMethodsCount
            DefaultMfaMethod                 = $User.DefaultMfaMethod

            # Call formatter function for complex properties
            MethodTypesRegistered            = Format-MyUserAuthProperty -PropertyData $User.MethodTypesRegistered -PropertyType 'MethodTypesRegistered' -NotConfigured 'None'
            FIDO2Keys                        = Format-MyUserAuthProperty -PropertyData $User.FIDO2Keys -PropertyType 'FIDO2Keys'
            PhoneMethods                     = Format-MyUserAuthProperty -PropertyData $User.PhoneMethods -PropertyType 'PhoneMethods'
            EmailMethods                     = Format-MyUserAuthProperty -PropertyData $User.EmailMethods -PropertyType 'EmailMethods'
            MicrosoftAuthenticator           = Format-MyUserAuthProperty -PropertyData $User.MicrosoftAuthenticator -PropertyType 'MicrosoftAuthenticator'
            TemporaryAccessPass              = Format-MyUserAuthProperty -PropertyData $User.TemporaryAccessPass -PropertyType 'TemporaryAccessPass'
            WindowsHelloForBusiness          = Format-MyUserAuthProperty -PropertyData $User.WindowsHelloForBusiness -PropertyType 'WindowsHelloForBusiness'
            SoftwareOathMethods              = Format-MyUserAuthProperty -PropertyData $User.SoftwareOathMethods -PropertyType 'SoftwareOathMethods'
        }
    }
    Write-Verbose "ConvertTo-MyFormattedUserAuth: Finished formatting."
    return $FormattedData
}