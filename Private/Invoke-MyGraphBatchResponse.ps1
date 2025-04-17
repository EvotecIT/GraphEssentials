function Invoke-MyGraphBatchResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $BatchResponses, # The raw response object from Invoke-MyGraphBatchRequest

        [Parameter(Mandatory)]
        [hashtable]$IdMap, # Maps Request ID to original context (e.g., UserId or RequestItem)

        [Parameter(Mandatory)]
        [string]$DataType # Description of data being fetched (for logging)
    )

    $results = [System.Collections.Generic.List[object]]::new()

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
    Write-Verbose "Invoke-MyGraphBatchResponse: Finished processing responses for $DataType."
    return $results
}