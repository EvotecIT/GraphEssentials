function Get-AuthMethodConfig {
    [CmdletBinding()]
    param (
        [string] $MethodName,
        [string] $ConfigId
    )
    try {
        Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Getting configuration for $MethodName"
        $Config = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $ConfigId -ErrorAction Stop
        return $Config
    } catch {
        $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Get-MyAuthenticationMethodsPolicy'
        if ($errorInfo.IsNotFound) {
            Write-Verbose -Message "Get-MyAuthenticationMethodsPolicy - Configuration for $MethodName is not available in this tenant."
        } else {
            Write-Warning -Message $errorInfo.FullMessage
        }
        return $null
    }
}
