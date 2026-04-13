function Write-RoleHistoryWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Operation,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord,

        [System.Collections.Generic.List[string]] $PermissionIssues,

        [string[]] $RequiredApplicationPermissions
    )

    $errorInfo = $ErrorRecord | Get-GraphEssentialsErrorDetails -FunctionName 'Get-MyRoleHistory'

    if ($RequiredApplicationPermissions -and $errorInfo.IsPermissionDenied) {
        $permissions = $RequiredApplicationPermissions -join ' or '
        $PermissionIssues.Add("$Operation requires application permission $permissions with admin consent.") | Out-Null
        Write-Warning -Message "Get-MyRoleHistory - Missing Microsoft Graph application permission for $Operation. Add $permissions and grant admin consent."
        return
    }

    Write-Warning -Message "Get-MyRoleHistory - Failed to get $Operation. Error: $($errorInfo.Message)"
}
