function Invoke-MyGraphBatchResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BatchResponses, # The raw response object from Invoke-MyGraphBatchRequest

        [Parameter(Mandatory)]
        [hashtable]$IdMap, # Maps Request ID to original context (e.g., UserId or RequestItem)

        [Parameter(Mandatory)]
        [string]$DataType, # Description of data being fetched (for logging)

        [Parameter()]
        [hashtable]$RequestsById = @{},

        [Parameter()]
        [int]$MaxRetryCount = 3,

        [Parameter()]
        [int]$RetryAttempt = 0
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $throttledResponses = [System.Collections.Generic.List[object]]::new()
    $throttledFailures = [System.Collections.Generic.List[object]]::new()

    if (-not $BatchResponses -or -not $BatchResponses.responses) {
        Write-Warning "Invoke-MyGraphBatchResponse: Invalid or empty batch response received for $DataType."
        # Create failure results for all expected items
        foreach ($reqId in $IdMap.Keys) {
            $originalContext = $IdMap[$reqId]
            $results.Add([PSCustomObject]@{ # Indentation fixed
                    RequestId = $reqId
                    Context   = $originalContext
                    Success   = $false
                    Status    = $null # No status available
                    Body      = $null
                    Error     = "Empty or invalid batch response received from API."
                })
        }
        return $results
    }

    Write-Verbose "Invoke-MyGraphBatchResponse: Processing $($BatchResponses.responses.Count) responses for $DataType."
    foreach ($response in $BatchResponses.responses) {
        $originalContext = $IdMap[$response.id]
        if ($null -eq $originalContext) {
            Write-Warning "Invoke-MyGraphBatchResponse: Could not map response ID $($response.id) back for $DataType."
            # Add a failure result for the unmappable ID
            $results.Add([PSCustomObject]@{ # Indentation fixed
                    RequestId = $response.id
                    Context   = $null # Unknown context
                    Success   = $false
                    Status    = $response.status
                    Body      = $response.body
                    Error     = "Could not map response ID back to original request context."
                })
            continue
        }

        if ($response.status -ge 200 -and $response.status -lt 300) {
            # Success
            $results.Add([PSCustomObject]@{ # Indentation fixed
                    RequestId = $response.id
                    Context   = $originalContext
                    Success   = $true
                    Status    = $response.status
                    Body      = $response.body
                    Error     = $null
                })
        } elseif ($response.status -eq 429) {
            if ($RetryAttempt -lt $MaxRetryCount -and $RequestsById.ContainsKey($response.id)) {
                $throttledResponses.Add($response)
            } else {
                $throttledFailures.Add([PSCustomObject]@{
                        RequestId = $response.id
                        Context   = $originalContext
                        Status    = $response.status
                        Body      = $response.body
                    })
                $results.Add([PSCustomObject]@{
                        RequestId = $response.id
                        Context   = $originalContext
                        Success   = $false
                        Status    = $response.status
                        Body      = $response.body
                        Error     = "Request failed with status code $($response.status) after retrying throttled batch items."
                    })
            }
        } else {
            # Failure
            Write-Warning "Invoke-MyGraphBatchResponse: Failed request in batch for $DataType (Context: '$originalContext', Response ID: $($response.id)). Status: $($response.status). Body: $($response.body | ConvertTo-Json -Depth 3 -Compress)"
            $results.Add([PSCustomObject]@{ # Indentation fixed
                    RequestId = $response.id
                    Context   = $originalContext
                    Success   = $false
                    Status    = $response.status
                    Body      = $response.body # Include body for potential error details
                    Error     = "Request failed with status code $($response.status)."
                })
        }
    }

    if ($throttledResponses.Count -gt 0) {
        $retryAttemptNumber = $RetryAttempt + 1
        $retryDelaySeconds = 0
        foreach ($throttledResponse in $throttledResponses) {
            $retryDelaySeconds = [Math]::Max($retryDelaySeconds, (Get-BatchRetryDelaySeconds -BatchResponse $throttledResponse))
        }

        Write-Warning "Invoke-MyGraphBatchResponse: Graph throttled $($throttledResponses.Count) request(s) for $DataType. Waiting $retryDelaySeconds second(s) before retry $retryAttemptNumber/$MaxRetryCount."
        Start-Sleep -Seconds $retryDelaySeconds

        $retryRequests = [System.Collections.Generic.List[object]]::new()
        foreach ($throttledResponse in $throttledResponses) {
            $retryRequest = $RequestsById[$throttledResponse.id]
            if ($null -ne $retryRequest) {
                $retryRequests.Add($retryRequest)
            }
        }

        $retryChunkSize = [Math]::Min(5, [Math]::Max(1, $retryRequests.Count))
        for ($i = 0; $i -lt $retryRequests.Count; $i += $retryChunkSize) {
            $currentRetryBatch = $retryRequests[$i..([Math]::Min($i + $retryChunkSize - 1, $retryRequests.Count - 1))]
            $retryIdMap = @{}
            $retryRequestsById = @{}

            foreach ($request in $currentRetryBatch) {
                $retryIdMap[$request.id] = $IdMap[$request.id]
                $retryRequestsById[$request.id] = $request
            }

            $retryDataType = "$DataType (Retry $retryAttemptNumber)"
            $retryBatchResponse = Invoke-MyGraphBatchRequest -BatchRequests $currentRetryBatch -DataType $retryDataType

            if ($retryBatchResponse) {
                $retryResults = Invoke-MyGraphBatchResponse -BatchResponses $retryBatchResponse -IdMap $retryIdMap -DataType $retryDataType -RequestsById $retryRequestsById -MaxRetryCount $MaxRetryCount -RetryAttempt $retryAttemptNumber
                foreach ($retryResult in $retryResults) {
                    $results.Add($retryResult)
                }
            } else {
                foreach ($request in $currentRetryBatch) {
                    $results.Add([PSCustomObject]@{
                            RequestId = $request.id
                            Context   = $retryIdMap[$request.id]
                            Success   = $false
                            Status    = $null
                            Body      = $null
                            Error     = "Batch retry request failed before a response was received."
                        })
                }
            }
        }
    }

    if ($throttledFailures.Count -gt 0) {
        $exampleContexts = $throttledFailures |
        Select-Object -First 5 |
        ForEach-Object { $_.Context } |
        Where-Object { $null -ne $_ } |
        ForEach-Object { "'$_'" }

        $exampleSuffix = if ($exampleContexts.Count -gt 0) {
            " Example contexts: $($exampleContexts -join ', ')."
        } else {
            ''
        }

        Write-Warning "Invoke-MyGraphBatchResponse: $($throttledFailures.Count) request(s) for $DataType remained throttled after $RetryAttempt retry attempt(s).$exampleSuffix"
    }

    Write-Verbose "Invoke-MyGraphBatchResponse: Finished processing responses for $DataType."
    return $results
}
