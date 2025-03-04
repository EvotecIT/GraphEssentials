function Get-MyAuthenticationMethodsPolicy {
    <#
    .SYNOPSIS
    Retrieves Authentication Methods Policy configuration from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about Authentication Methods Policy configured in Azure AD/Entra ID,
    including which authentication methods are enabled and their specific configurations.
    If any individual method fails to retrieve, the function will continue with the others.

    .EXAMPLE
    Get-MyAuthenticationMethodsPolicy
    Returns the authentication methods policy configuration.

    .NOTES
    This function requires the Microsoft.Graph.Identity.SignIns module and appropriate permissions.
    Typically requires Policy.Read.All permission.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Getting authentication methods policy"
        $Policy = Get-MgPolicyAuthenticationMethodPolicy -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyAuthenticationMethodsPolicy - Failed to get base authentication methods policy. Error: $($_.Exception.Message)"
        return
    }

    Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Getting method configurations"
    $Methods = @{}

    # Helper function to safely get method configuration
    function Get-AuthMethodConfig {
        param (
            [string] $MethodName,
            [string] $ConfigId
        )
        try {
            Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Getting configuration for $MethodName"
            $Config = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $ConfigId -ErrorAction Stop
            return $Config
        } catch {
            Write-Warning -Message "Get-MyAuthenticationMethodsPolicy - Failed to get configuration for $MethodName. Error: $($_.Exception.Message)"
            return $null
        }
    }

    # Helper function to convert excludeTargets to a more readable format
    function ConvertTo-FlattenedExcludeTargets {
        param (
            [Array]$ExcludeTargets
        )

        if (-not $ExcludeTargets -or $ExcludeTargets.Count -eq 0) {
            return @()
        }

        $ExcludeTargets | ForEach-Object {
            [PSCustomObject]@{
                TargetType  = $_.TargetType
                Id          = $_.Id
                DisplayName = $_.TargetType -eq 'group' ? (Get-MgGroup -GroupId $_.Id -ErrorAction SilentlyContinue).DisplayName : $null
            }
        }
    }

    # Get each method configuration independently
    $AuthenticatorConfig = Get-AuthMethodConfig -MethodName "Microsoft Authenticator" -ConfigId "MicrosoftAuthenticator"
    $FIDO2Config = Get-AuthMethodConfig -MethodName "FIDO2" -ConfigId "Fido2"
    $SMSConfig = Get-AuthMethodConfig -MethodName "SMS" -ConfigId "Sms"
    $TempAccessConfig = Get-AuthMethodConfig -MethodName "Temporary Access Pass" -ConfigId "TemporaryAccessPass"
    $EmailConfig = Get-AuthMethodConfig -MethodName "Email" -ConfigId "Email"
    $VoiceConfig = Get-AuthMethodConfig -MethodName "Voice" -ConfigId "Voice"
    $SoftwareConfig = Get-AuthMethodConfig -MethodName "Software Token" -ConfigId "SoftwareOath"
    $PasswordConfig = Get-AuthMethodConfig -MethodName "Password" -ConfigId "Password"
    $WindowsHelloConfig = Get-AuthMethodConfig -MethodName "Windows Hello for Business" -ConfigId "WindowsHelloForBusiness"
    $X509Config = Get-AuthMethodConfig -MethodName "X.509 Certificate" -ConfigId "X509Certificate"

    # Build the methods hashtable with available configurations
    if ($AuthenticatorConfig) {
        $NumberMatchState = $AuthenticatorConfig.AdditionalProperties.featureSettings.displayAppInformationRequiredState.state
        $Methods['Authenticator'] = @{
            State                   = $AuthenticatorConfig.State
            ExcludeTargets          = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $AuthenticatorConfig.ExcludeTargets
            RequireNumberMatching   = $NumberMatchState
            AllowWithoutNumberMatch = $NumberMatchState -eq 'enabled'
        }
    }

    if ($FIDO2Config) {
        $Methods['FIDO2'] = @{
            State                 = $FIDO2Config.State
            ExcludeTargets        = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $FIDO2Config.ExcludeTargets
            IsAttestationEnforced = $FIDO2Config.AdditionalProperties.isAttestationEnforced
            KeyRestrictions       = if ($FIDO2Config.AdditionalProperties.keyRestrictions) {
                [PSCustomObject]@{
                    AAGUIDs         = $FIDO2Config.AdditionalProperties.keyRestrictions.aaGuids -join ', '
                    EnforcementType = $FIDO2Config.AdditionalProperties.keyRestrictions.enforcementType
                    IsEnforced      = $FIDO2Config.AdditionalProperties.keyRestrictions.isEnforced
                }
            } else { $null }
        }
    }

    if ($SMSConfig) {
        $Methods['SMS'] = @{
            State          = $SMSConfig.State
            ExcludeTargets = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $SMSConfig.ExcludeTargets
        }
    }

    if ($TempAccessConfig) {
        $Methods['TemporaryAccess'] = @{
            State                    = $TempAccessConfig.State
            ExcludeTargets           = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $TempAccessConfig.ExcludeTargets
            DefaultLength            = $TempAccessConfig.AdditionalProperties.defaultLength
            DefaultLifetimeInMinutes = $TempAccessConfig.AdditionalProperties.defaultLifetimeInMinutes
            MaximumLifetimeInMinutes = $TempAccessConfig.AdditionalProperties.maximumLifetimeInMinutes
        }
    }

    if ($EmailConfig) {
        $Methods['Email'] = @{
            State                        = $EmailConfig.State
            ExcludeTargets               = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $EmailConfig.ExcludeTargets
            AllowExternalIdToUseEmailOtp = $EmailConfig.AdditionalProperties.allowExternalIdToUseEmailOtp
        }
    }

    if ($VoiceConfig) {
        $Methods['Voice'] = @{
            State          = $VoiceConfig.State
            ExcludeTargets = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $VoiceConfig.ExcludeTargets
        }
    }

    if ($SoftwareConfig) {
        $Methods['Software'] = @{
            State          = $SoftwareConfig.State
            ExcludeTargets = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $SoftwareConfig.ExcludeTargets
        }
    }

    if ($PasswordConfig) {
        $Methods['Password'] = @{
            State = $PasswordConfig.State
        }
    }

    if ($WindowsHelloConfig) {
        $Methods['WindowsHello'] = @{
            State          = $WindowsHelloConfig.State
            ExcludeTargets = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $WindowsHelloConfig.ExcludeTargets
            SecurityKeys   = $WindowsHelloConfig.AdditionalProperties.securityKeyForWindows10OrFewer
        }
    }

    if ($X509Config) {
        $Methods['X509'] = @{
            State                   = $X509Config.State
            ExcludeTargets          = ConvertTo-FlattenedExcludeTargets -ExcludeTargets $X509Config.ExcludeTargets
            CertificateUserBindings = @(
                foreach ($binding in $X509Config.AdditionalProperties.certificateUserBindings) {
                    [PSCustomObject]@{
                        X509Field          = $binding.x509CertificateField
                        UserProperty       = $binding.userProperty
                        Priority           = $binding.priority
                        TrustAffinityLevel = $binding.trustAffinityLevel
                    }
                }
            )
        }
    }

    [PSCustomObject]@{
        Id                   = $Policy.Id
        Description          = $Policy.Description
        LastModifiedDateTime = $Policy.LastModifiedDateTime
        Methods              = $Methods
    }
}