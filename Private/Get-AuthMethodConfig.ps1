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
        Write-Warning -Message "Get-MyAuthenticationMethodsPolicy - Failed to get configuration for $MethodName. Error: $($_.Exception.Message)"
        return $null
    }
}