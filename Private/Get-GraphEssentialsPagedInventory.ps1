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
        [int] $MaxPageAttempts = 3,

        [switch] $ReportProgress
    )

    $pageUri = $Uri
    $pageNumber = 0
    $itemCount = 0
    $startedAt = Get-Date
    $seenPageUris = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    while ($pageUri) {
        if (-not $seenPageUris.Add($pageUri)) {
            throw "Graph inventory returned a repeated page URL after page $pageNumber."
        }
        $pageNumber++
        if ($ReportProgress -and $pageNumber -eq 1) {
            Write-Information -MessageData 'Graph inventory: requesting page 1.' -InformationAction Continue
        }
        $attempt = 0
        while ($true) {
            $attempt++
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $pageUri -OutputType PSObject -ErrorAction Stop
                break
            } catch {
                $errorRecord = $_
                $statusCode = $null
                $httpResponse = $null
                $transportFailure = $false
                $exceptionMessages = [System.Collections.Generic.List[string]]::new()
                $exception = $errorRecord.Exception
                while ($exception) {
                    if ($exception.Message) {
                        $exceptionMessages.Add($exception.Message)
                    }
                    if (-not $httpResponse -and $exception.Response) {
                        $httpResponse = $exception.Response
                    }
                    if ($exception.GetType().FullName -in @(
                        'System.Net.Http.HttpRequestException', 'System.IO.IOException',
                        'System.Net.Sockets.SocketException', 'System.Threading.Tasks.TaskCanceledException'
                    )) {
                        $transportFailure = $true
                    }
                    $exception = $exception.InnerException
                }
                if ($httpResponse -and $httpResponse.StatusCode) {
                    $statusCode = [int] $httpResponse.StatusCode
                }
                $message = $exceptionMessages -join ' --> '
                $transient = if ($null -ne $statusCode) {
                    $statusCode -in @(408, 429, 500, 502, 503, 504)
                } else {
                    $transportFailure -or $message -match '(?i)timed?\s*out|timeout|cancell?ed.*300 seconds|connection.*(closed|reset)|transport stream|premature EOF'
                }

                if (-not $transient -or $attempt -ge $MaxPageAttempts) {
                    throw "Graph inventory page $pageNumber failed after $attempt attempt(s): $message"
                }

                $delaySeconds = [Math]::Min(30, [int] [Math]::Pow(2, $attempt - 1))
                if ($null -ne $statusCode -and $httpResponse.Headers) {
                    $headers = $httpResponse.Headers
                    $retryAfter = $null
                    if ($headers.GetType().FullName -eq 'System.Net.Http.Headers.HttpResponseHeaders') {
                        if ($headers.RetryAfter) {
                            $retryAfter = [string] $headers.RetryAfter
                        }
                    } elseif ($headers -is [System.Collections.IDictionary]) {
                        $retryAfter = @($headers['Retry-After'])[0]
                    } else {
                        $retryAfter = $headers.'Retry-After'
                    }
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
                        throw "Graph inventory page $pageNumber requested a retry after $delaySeconds seconds; this run cannot complete within the retry limit."
                    }
                }
                Write-Verbose "Graph inventory page $pageNumber failed ($message). Retrying in $delaySeconds seconds."
                if ($ReportProgress) {
                    Write-Information -MessageData "Graph inventory: retrying page $pageNumber in $delaySeconds second(s) after a transient failure." -InformationAction Continue
                }
                Start-Sleep -Seconds $delaySeconds
            }
        }

        if ($null -eq $response -or $null -eq $response.value) {
            throw "Graph inventory page $pageNumber did not contain a value collection."
        }
        foreach ($item in $response.value) {
            if ($null -ne $item) {
                $itemCount++
                $item
            }
        }
        $pageUri = $response.'@odata.nextLink'
        if ($ReportProgress -and ($pageNumber % 10 -eq 0 -or -not $pageUri)) {
            $elapsed = [math]::Round(((Get-Date) - $startedAt).TotalMinutes, 1)
            $state = if ($pageUri) { 'continuing' } else { 'complete' }
            Write-Information -MessageData "Graph inventory: $itemCount records across $pageNumber page(s), $elapsed minute(s) elapsed; $state." -InformationAction Continue
        }
    }
}
