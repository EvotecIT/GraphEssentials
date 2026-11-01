function Send-GraphEssentialsInvitationBatch {
    <# Dispatch once through the SDK. The host must serialize SDK use; restore the original retry integer. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Body,
        [Parameter(Mandatory)] $Connection
    )

    $current = Get-MgContext -ErrorAction Stop
    foreach ($name in @('TenantId', 'ClientId', 'Account', 'AuthType', 'Environment')) {
        if ($current.$name -ne $Connection.$name) {
            throw 'The SDK identity changed after invitation preparation. No batch was dispatched.'
        }
    }
    $maxRetry = (Get-MgRequestContext -ErrorAction Stop).MaxRetry
    try {
        Set-MgRequestContext -MaxRetry 0 -Confirm:$false -ErrorAction Stop | Out-Null
        Invoke-MgGraphRequest -Method POST -Uri '/v1.0/$batch' -Body $Body -ContentType 'application/json' -OutputType PSObject -Verbose:$false -Debug:$false -ErrorAction Stop
    } finally {
        Set-MgRequestContext -MaxRetry $maxRetry -Confirm:$false -ErrorAction Stop | Out-Null
    }
}
