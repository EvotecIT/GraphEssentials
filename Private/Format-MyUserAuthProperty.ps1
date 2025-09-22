function Format-MyUserAuthProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()] # Property might be null
        $PropertyData,

        [Parameter(Mandatory)]
        [ValidateSet('FIDO2Keys', 'PhoneMethods', 'EmailMethods', 'MicrosoftAuthenticator', 'TemporaryAccessPass', 'WindowsHelloForBusiness', 'SoftwareOathMethods', 'HardwareOathMethods', 'MethodTypesRegistered')]
        [string]$PropertyType,

        [string]$NotConfigured = "Not Configured"
    )

    if (-not $PropertyData) {
        return $NotConfigured
    }

    $FormattedItems = switch ($PropertyType) {
        'FIDO2Keys' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    $createdDate = if ($item.CreatedDateTime) { $item.CreatedDateTime.ToString('yyyy-MM-dd') } else { 'N/A' }
                    $aaguid = if ($item.AAGuid) { $item.AAGuid } elseif ($item.AaGuid) { $item.AaGuid } else { $null }
                    if ($aaguid) {
                        "$($item.Model) - $($item.DisplayName) (AAGUID: $aaguid, Created: $createdDate)"
                    } else {
                        "$($item.Model) - $($item.DisplayName) (Created: $createdDate)"
                    }
                } else { $item } # Simple display name
            }
        }
        'PhoneMethods' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    "$($item.PhoneType): $($item.PhoneNumber) (SMS: $($item.SmsSignInState))"
                } else { $item }
            }
        }
        'EmailMethods' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    $item.EmailAddress
                } else { $item }
            }
        }
        'MicrosoftAuthenticator' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    "$($item.DisplayName) (Tag: $($item.DeviceTag), Ver: $($item.PhoneAppVersion))"
                } else { $item }
            }
        }
        'TemporaryAccessPass' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    "Usable: $($item.IsUsable), Reason: $($item.MethodUsabilityReason), Lifetime: $($item.LifetimeInMinutes)m"
                } else { $item }
            }
        }
        'WindowsHelloForBusiness' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    $createdDate = if ($item.CreatedDateTime) { $item.CreatedDateTime.ToString('yyyy-MM-dd') } else { 'N/A' }
                    "$($item.DisplayName) (Strength: $($item.KeyStrength), Device: $($item.Device), Created: $createdDate)"
                } else { $item } # Simple display name
            }
        }
        'SoftwareOathMethods' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    $item.DisplayName
                } else { $item }
            }
        }
        'HardwareOathMethods' {
            foreach ($item in $PropertyData) {
                if ($item -is [hashtable] -or $item -is [pscustomobject]) {
                    $issuer = $item.Issuer
                    $serial = $item.SerialNumber
                    $slot = $item.Slot
                    if ($issuer -or $serial -or $slot) {
                        "Issuer: $issuer; Serial: $serial; Slot: $slot"
                    } elseif ($item.DisplayName) {
                        $item.DisplayName
                    } else {
                        'Token registered'
                    }
                } else { $item }
            }
        }
        'MethodTypesRegistered' {
            # This expects an array of strings already
            $PropertyData -join '; '
        }
        default {
            # Should not happen with ValidateSet, but fallback
            if ($PropertyData -is [array]) { $PropertyData -join [environment]::NewLine } else { $PropertyData }
        }
    }

    if ($FormattedItems) {
        $FormattedItems -join [environment]::NewLine
    } else {
        $NotConfigured # Return default if loop produced no output
    }
}
