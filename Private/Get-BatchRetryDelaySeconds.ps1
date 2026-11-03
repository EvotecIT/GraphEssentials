function Get-BatchRetryDelaySeconds {
    <# Honor JSON batch retry headers from SDK dictionaries or objects, including HTTP dates and millisecond hints. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BatchResponse
    )

    $delaySeconds = 0
    $headers = $BatchResponse.headers
    if (-not $BatchResponse -or -not $headers) {
        return 5
    }

    $entries = if ($headers -is [System.Collections.IDictionary]) {
        $headers.GetEnumerator()
    } else {
        foreach ($property in $headers.PSObject.Properties) {
            [pscustomobject] @{ Key = $property.Name; Value = $property.Value }
        }
    }
    foreach ($entry in $entries) {
        $value = [string] @($entry.Value)[0]
        $parsed = 0L
        if ([string] $entry.Key -ieq 'Retry-After') {
            if ([long]::TryParse($value, [ref] $parsed)) {
                $delaySeconds = [math]::Max($delaySeconds, $parsed)
            } else {
                $retryAt = [datetimeoffset]::MinValue
                if ([datetimeoffset]::TryParse($value, [Globalization.CultureInfo]::InvariantCulture,
                        [Globalization.DateTimeStyles]::AssumeUniversal, [ref] $retryAt)) {
                    $delaySeconds = [math]::Max($delaySeconds, [math]::Ceiling(($retryAt - [datetimeoffset]::UtcNow).TotalSeconds))
                }
            }
        } elseif ([string] $entry.Key -ieq 'x-ms-retry-after-ms' -and [long]::TryParse($value, [ref] $parsed)) {
            $delaySeconds = [math]::Max($delaySeconds, [math]::Ceiling($parsed / 1000))
        }
    }

    if ($delaySeconds -le 0) {
        $delaySeconds = 5
    }

    return [long] $delaySeconds
}
