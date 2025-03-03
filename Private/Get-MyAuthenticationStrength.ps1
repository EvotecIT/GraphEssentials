function Get-MyAuthenticationStrength {
    <#
    .SYNOPSIS
    Retrieves authentication strength policies from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about authentication strength policies configured in Azure AD/Entra ID,
    including built-in and custom policies. The function provides information about allowed authentication
    method combinations and their human-readable descriptions.

    .EXAMPLE
    Get-MyAuthenticationStrength
    Returns all authentication strength policies from Microsoft Graph.

    .NOTES
    This function requires the Microsoft.Graph.Identity.Governance module and appropriate permissions.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Get-MyAuthenticationStrength - Getting authentication strength policies"
        $AuthStrengthPolicies = Get-MgPolicyAuthenticationStrengthPolicy -ErrorAction Stop
        Write-Verbose -Message "Get-MyAuthenticationStrength - Retrieved $($AuthStrengthPolicies.Count) authentication strength policies"
    } catch {
        Write-Warning -Message "Get-MyAuthenticationStrength - Failed to get authentication strength policies. Error: $($_.Exception.Message)"
        return
    }

    # Map raw authentication methods to friendly names
    $MethodFriendlyNames = @{
        'windowsHelloForBusiness'                          = 'Windows Hello for Business'
        'fido2'                                            = 'FIDO2 Security Key'
        'x509CertificateMultiFactor'                       = 'Certificate-based MFA'
        'deviceBasedPush'                                  = 'Microsoft Authenticator (device-bound)'
        'temporaryAccessPassOneTime'                       = 'One-time Temporary Access Pass'
        'temporaryAccessPassMultiUse'                      = 'Multi-use Temporary Access Pass'
        'password,microsoftAuthenticatorPush'              = 'Password + Microsoft Authenticator push notification'
        'password,softwareOath'                            = 'Password + Software OATH token'
        'password,hardwareOath'                            = 'Password + Hardware OATH token'
        'password,sms'                                     = 'Password + SMS'
        'password,voice'                                   = 'Password + Voice call'
        'federatedMultiFactor'                             = 'Federated MFA'
        'microsoftAuthenticatorPush,federatedSingleFactor' = 'Microsoft Authenticator + Federated SSO'
        'softwareOath,federatedSingleFactor'               = 'Software OATH token + Federated SSO'
        'hardwareOath,federatedSingleFactor'               = 'Hardware OATH token + Federated SSO'
        'sms,federatedSingleFactor'                        = 'SMS + Federated SSO'
        'voice,federatedSingleFactor'                      = 'Voice call + Federated SSO'
    }

    $Results = foreach ($Policy in $AuthStrengthPolicies) {
        # Create friendly names for all allowed combinations
        [Array] $FriendlyCombinations = foreach ($Combination in $Policy.AllowedCombinations) {
            if ($MethodFriendlyNames.ContainsKey($Combination)) {
                $MethodFriendlyNames[$Combination]
            } else {
                $Combination
            }
        }

        [PSCustomObject]@{
            DisplayName            = $Policy.DisplayName
            Id                     = $Policy.Id
            Description            = $Policy.Description
            PolicyType             = $Policy.PolicyType
            CreatedDateTime        = $Policy.CreatedDateTime
            ModifiedDateTime       = $Policy.ModifiedDateTime
            RequirementsSatisfied  = $Policy.RequirementsSatisfied
            AllowedCombinations    = $FriendlyCombinations
            RawAllowedCombinations = $Policy.AllowedCombinations
            CombinationsCount      = $Policy.AllowedCombinations.Count
        }
    }
    $Results
}