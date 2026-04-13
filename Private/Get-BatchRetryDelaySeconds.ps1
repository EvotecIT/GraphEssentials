function Get-BatchRetryDelaySeconds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BatchResponse
    )

    $delaySeconds = 0
    if (-not $BatchResponse -or -not $BatchResponse.headers) {
        return 5
    }

    foreach ($headerName in @('Retry-After', 'retry-after')) {
        $headerProperty = $BatchResponse.headers.PSObject.Properties[$headerName]
        if ($headerProperty -and $headerProperty.Value) {
            $parsedDelay = 0
            if ([int]::TryParse($headerProperty.Value.ToString(), [ref] $parsedDelay)) {
                $delaySeconds = [Math]::Max($delaySeconds, $parsedDelay)
            }
        }
    }

    foreach ($headerName in @('x-ms-retry-after-ms', 'X-MS-Retry-After-MS')) {
        $headerProperty = $BatchResponse.headers.PSObject.Properties[$headerName]
        if ($headerProperty -and $headerProperty.Value) {
            $parsedDelayMs = 0
            if ([int]::TryParse($headerProperty.Value.ToString(), [ref] $parsedDelayMs)) {
                $delaySeconds = [Math]::Max($delaySeconds, [Math]::Ceiling($parsedDelayMs / 1000))
            }
        }
    }

    if ($delaySeconds -le 0) {
        $delaySeconds = 5
    }

    return $delaySeconds
}
