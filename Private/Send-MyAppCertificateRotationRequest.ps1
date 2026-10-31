function Send-MyAppCertificateRotationRequest {
    <# Use the official SDK transport once, restoring its process request settings even after a failure. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)][ValidateSet('addKey', 'removeKey')][string] $Action,
        [Parameter(Mandatory)][hashtable] $Body
    )

    # The SDK returns its live mutable context; snapshot the value before changing it.
    $maxRetry = (Get-MgRequestContext -ErrorAction Stop).MaxRetry
    try {
        Set-MgRequestContext -MaxRetry 0 -Confirm:$false -ErrorAction Stop | Out-Null
        # A relative Graph URI preserves the SDK environment across HTTP-client resets.
        $uri = "/v1.0/applications(appId='$($State.ClientId)')/$Action"
        Invoke-MgGraphRequest -Method POST -Uri $uri -Body (ConvertTo-Json -InputObject $Body -Depth 5 -Compress) -ContentType 'application/json' -Headers @{
            'client-request-id'        = $State.OperationId
            'return-client-request-id' = 'true'
        } -Verbose:$false -Debug:$false -ErrorAction Stop
    } catch {
        # Include only a numeric status and Graph's identifier, never request bodies or signed proofs.
        $diagnostic = 'transport or client failure'
        if ($_.Exception.Response.StatusCode) {
            $diagnostic = 'HTTP ' + [int] $_.Exception.Response.StatusCode
        }
        if ($_.ErrorDetails.Message -match '"code"\s*:\s*"([A-Za-z0-9_.-]+)"') {
            $diagnostic += ', ' + $Matches[1]
        }
        throw "Graph $Action did not complete with a durable receipt ($diagnostic). Use -Reconcile before another mutation; the saved intent is retained."
    } finally {
        Set-MgRequestContext -MaxRetry $maxRetry -Confirm:$false -ErrorAction Stop | Out-Null
    }
}
