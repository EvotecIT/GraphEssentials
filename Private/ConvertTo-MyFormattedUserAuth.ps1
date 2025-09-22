function ConvertTo-MyFormattedUserAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$UserAuthData,

        [hashtable] $RolesLookup,
        [hashtable] $LicensesLookup,
        [hashtable] $LicenseServicesLookup
    )

    if (-not $UserAuthData) {
        return @()
    }

    Write-Verbose "ConvertTo-MyFormattedUserAuth: Formatting $($UserAuthData.Count) user records for display."
    $FormattedData = foreach ($User in $UserAuthData) {
        $row = [ordered]@{
            UserPrincipalName                = $User.UserPrincipalName
            DisplayName                      = $User.DisplayName
            Enabled                          = $User.Enabled
            IsCloudOnly                      = $User.IsCloudOnly

            LastSignInDateTime               = $User.LastSignInDateTime
            LastSignInDaysAgo                = $User.LastSignInDaysAgo
            LastNonInteractiveSignInDateTime = $User.LastNonInteractiveSignInDateTime
            LastNonInteractiveSignInDaysAgo  = $User.LastNonInteractiveSignInDaysAgo

            DefaultMfaMethod                 = $User.DefaultMfaMethod
            IsMfaCapable                     = $User.IsMfaCapable
            IsPasswordlessCapable            = $User.IsPasswordlessCapable
            TotalMethodsCount                = $User.TotalMethodsCount

            'PasswordMethodRegistered'       = $User.'PasswordMethodRegistered'
            'Microsoft Auth Passwordless'    = $User.'Microsoft Auth Passwordless'
            'FIDO2 Security Key'             = $User.'FIDO2 Security Key'
            'Device Bound PushKey'           = $User.'Device Bound PushKey'
            'Device Bound Push'              = $User.'Device Bound Push'
            'Microsoft Auth Push'            = $User.'Microsoft Auth Push'
            'Windows Hello'                  = $User.'Windows Hello'
            'Microsoft Auth App'             = $User.'Microsoft Auth App'
            'Hardware OTP'                   = $User.'Hardware OTP'
            'Software OTP'                   = $User.'Software OTP'
            'Temporary Pass'                 = $User.'Temporary Pass'
            'SMS'                            = $User.'SMS'
            'Email'                          = $User.'Email'
            'Security Questions Registered'  = $User.'Security Questions Registered'
            'Voice Call'                     = $User.'Voice Call'
            'Alternative Phone'              = $User.'Alternative Phone'

            # Counts
            DeviceBoundPushCount             = $User.DeviceBoundPushCount

            # Call formatter function for complex properties
            MethodTypesRegistered            = Format-MyUserAuthProperty -PropertyData $User.MethodTypesRegistered -PropertyType 'MethodTypesRegistered' -NotConfigured 'None'
            FIDO2Keys                        = Format-MyUserAuthProperty -PropertyData $User.FIDO2Keys -PropertyType 'FIDO2Keys'
            PhoneMethods                     = Format-MyUserAuthProperty -PropertyData $User.PhoneMethods -PropertyType 'PhoneMethods'
            EmailMethods                     = Format-MyUserAuthProperty -PropertyData $User.EmailMethods -PropertyType 'EmailMethods'
            MicrosoftAuthenticator           = Format-MyUserAuthProperty -PropertyData $User.MicrosoftAuthenticator -PropertyType 'MicrosoftAuthenticator'
            TemporaryAccessPass              = Format-MyUserAuthProperty -PropertyData $User.TemporaryAccessPass -PropertyType 'TemporaryAccessPass'
            WindowsHelloForBusiness          = Format-MyUserAuthProperty -PropertyData $User.WindowsHelloForBusiness -PropertyType 'WindowsHelloForBusiness'
            SoftwareOathMethods              = Format-MyUserAuthProperty -PropertyData $User.SoftwareOathMethods -PropertyType 'SoftwareOathMethods'
            HardwareOathMethods              = if ($User.PSObject.Properties.Name -contains 'HardwareOathMethods') { 
                                                  Format-MyUserAuthProperty -PropertyData $User.HardwareOathMethods -PropertyType 'HardwareOathMethods' 
                                              } else { 'Not Configured' }

            CreatedDateTime                  = $User.CreatedDateTime
        }

        # Optional augmentation
        if ($RolesLookup) {
            $roles = if ($RolesLookup.ContainsKey($User.UserPrincipalName)) { $RolesLookup[$User.UserPrincipalName] } else { $null }
            $row['Roles'] = $roles
        }
        if ($LicensesLookup) {
            $licenses = if ($LicensesLookup.ContainsKey($User.UserPrincipalName)) { $LicensesLookup[$User.UserPrincipalName] } else { $null }
            $row['Licenses'] = $licenses
        }
        if ($LicenseServicesLookup) {
            $licenseServices = if ($LicenseServicesLookup.ContainsKey($User.UserPrincipalName)) { $LicenseServicesLookup[$User.UserPrincipalName] } else { $null }
            $row['LicenseServices'] = $licenseServices
        }

        [PSCustomObject]$row
    }
    Write-Verbose "ConvertTo-MyFormattedUserAuth: Finished formatting."
    return $FormattedData
}
