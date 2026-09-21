function Get-GraphEssentialsPagedInventory {
    <#
    .SYNOPSIS
    Reads a Graph collection one page at a time with bounded page retries.

    .DESCRIPTION
    Keeps only the current raw page in memory and retries its URL after a transient
    failure. Callers must buffer their final inventory until this function finishes,
    because an incomplete collection must never be used for cleanup decisions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri,

        [ValidateRange(1, 10)]
        [int] $MaxPageAttempts = 3
    )

    $pageUri = $Uri
    $pageNumber = 0
    $seenPageUris = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    while ($pageUri) {
        if (-not $seenPageUris.Add($pageUri)) {
            throw "Graph inventory returned a repeated page URL after page $pageNumber."
        }
        $pageNumber++
        $attempt = 0
        while ($true) {
            $attempt++
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $pageUri -OutputType PSObject -ErrorAction Stop
                break
            } catch {
                $errorRecord = $_
                $statusCode = $null
                if ($errorRecord.Exception.Response -and $errorRecord.Exception.Response.StatusCode) {
                    $statusCode = [int] $errorRecord.Exception.Response.StatusCode
                }
                $message = [string] $errorRecord.Exception.Message
                $transient = $statusCode -in @(408, 429, 500, 502, 503, 504) -or
                    $message -match '(?i)timed?\s*out|timeout|cancell?ed.*300 seconds|connection.*(closed|reset)|transport stream'

                if (-not $transient -or $attempt -ge $MaxPageAttempts) {
                    throw "Graph inventory page $pageNumber failed after $attempt attempt(s): $message"
                }

                $delaySeconds = [Math]::Min(30, [int] [Math]::Pow(2, $attempt - 1))
                if ($statusCode -eq 429 -and $errorRecord.Exception.Response.Headers) {
                    $headers = $errorRecord.Exception.Response.Headers
                    $retryAfter = $null
                    try { $retryAfter = @($headers['Retry-After'])[0] } catch { }
                    $retryAfterSeconds = 0
                    if ($retryAfter -and [int]::TryParse([string] $retryAfter, [ref] $retryAfterSeconds)) {
                        $delaySeconds = [Math]::Max(1, $retryAfterSeconds)
                    } elseif ($retryAfter) {
                        $retryAt = [DateTimeOffset]::MinValue
                        if ([DateTimeOffset]::TryParse([string] $retryAfter, [ref] $retryAt)) {
                            $delaySeconds = [Math]::Max(1, [int] [Math]::Ceiling(($retryAt - [DateTimeOffset]::UtcNow).TotalSeconds))
                        }
                    }
                    if ($delaySeconds -gt 3600) {
                        throw "Graph inventory page $pageNumber was throttled for $delaySeconds seconds; this run cannot complete within the retry limit."
                    }
                }
                Write-Verbose "Graph inventory page $pageNumber failed ($message). Retrying in $delaySeconds seconds."
                Start-Sleep -Seconds $delaySeconds
            }
        }

        if ($null -eq $response -or $null -eq $response.value) {
            throw "Graph inventory page $pageNumber did not contain a value collection."
        }
        foreach ($item in $response.value) {
            if ($null -ne $item) {
                $item
            }
        }
        $pageUri = $response.'@odata.nextLink'
    }
}
