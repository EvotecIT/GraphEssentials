function Get-MyAuthenticationMethodsPolicy {
    <#
    .SYNOPSIS
    Retrieves Authentication Methods Policy configuration from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about Authentication Methods Policy configured in Azure AD/Entra ID,
    including which authentication methods are enabled and their specific configurations.

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
        Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Getting method configurations"

        $Methods = @{
            Authenticator = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'MicrosoftAuthenticator' -ErrorAction Stop
            FIDO2 = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'Fido2' -ErrorAction Stop
            SMS = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'Sms' -ErrorAction Stop
            TemporaryAccess = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'TemporaryAccessPass' -ErrorAction Stop
            Email = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'Email' -ErrorAction Stop
            Voice = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'Voice' -ErrorAction Stop
            Software = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'SoftwareOath' -ErrorAction Stop
            Password = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'Password' -ErrorAction Stop
            WindowsHello = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'WindowsHelloForBusiness' -ErrorAction Stop
            X509 = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId 'X509Certificate' -ErrorAction Stop
        }

        [PSCustomObject]@{
            Id = $Policy.Id
            Description = $Policy.Description
            LastModifiedDateTime = $Policy.LastModifiedDateTime
            Methods = @{
                Authenticator = @{
                    State = $Methods.Authenticator.State
                    ExcludeTargets = $Methods.Authenticator.ExcludeTargets
                    RequireNumberMatching = $Methods.Authenticator.AdditionalProperties.featureSettings.displayAppInformationRequiredState
                    AllowWithoutNumberMatch = $Methods.Authenticator.AdditionalProperties.featureSettings.displayAppInformationRequiredState -eq 'enabled'
                }
                FIDO2 = @{
                    State = $Methods.FIDO2.State
                    ExcludeTargets = $Methods.FIDO2.ExcludeTargets
                    IsAttestationEnforced = $Methods.FIDO2.AdditionalProperties.isAttestationEnforced
                    KeyRestrictions = $Methods.FIDO2.AdditionalProperties.keyRestrictions
                }
                SMS = @{
                    State = $Methods.SMS.State
                    ExcludeTargets = $Methods.SMS.ExcludeTargets
                }
                TemporaryAccess = @{
                    State = $Methods.TemporaryAccess.State
                    ExcludeTargets = $Methods.TemporaryAccess.ExcludeTargets
                    DefaultLength = $Methods.TemporaryAccess.AdditionalProperties.defaultLength
                    DefaultLifetimeInMinutes = $Methods.TemporaryAccess.AdditionalProperties.defaultLifetimeInMinutes
                    MaximumLifetimeInMinutes = $Methods.TemporaryAccess.AdditionalProperties.maximumLifetimeInMinutes
                }
                Email = @{
                    State = $Methods.Email.State
                    ExcludeTargets = $Methods.Email.ExcludeTargets
                    AllowExternalIdToUseEmailOtp = $Methods.Email.AdditionalProperties.allowExternalIdToUseEmailOtp
                }
                Voice = @{
                    State = $Methods.Voice.State
                    ExcludeTargets = $Methods.Voice.ExcludeTargets
                }
                Software = @{
                    State = $Methods.Software.State
                    ExcludeTargets = $Methods.Software.ExcludeTargets
                }
                Password = @{
                    State = $Methods.Password.State
                }
                WindowsHello = @{
                    State = $Methods.WindowsHello.State
                    ExcludeTargets = $Methods.WindowsHello.ExcludeTargets
                    SecurityKeys = $Methods.WindowsHello.AdditionalProperties.securityKeyForWindows10OrFewer
                }
                X509 = @{
                    State = $Methods.X509.State
                    ExcludeTargets = $Methods.X509.ExcludeTargets
                    CertificateUserBindings = $Methods.X509.AdditionalProperties.certificateUserBindings
                }
            }
        }

    } catch {
        Write-Warning -Message "Get-MyAuthenticationMethodsPolicy - Failed to get authentication methods policy. Error: $($_.Exception.Message)"
        return
    }
}