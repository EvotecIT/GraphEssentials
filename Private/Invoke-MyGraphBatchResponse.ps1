function Invoke-MyGraphBatchResponse {
    param(
        [Parameter(Mandatory)]
        $BatchResponses, # The raw response object from Invoke-MyGraphBatchRequest

        [Parameter(Mandatory)]
        [hashtable]$IdMap, # Maps Request ID to original context (e.g., UserId or RequestItem)

        [Parameter(Mandatory)]
        [string]$DataType, # Description of data being fetched

        [Parameter(Mandatory)]
        [scriptblock]$SuccessAction, # Action to take on successful response: param($responseBody, $originalContext)

        [Parameter(Mandatory)]
        [scriptblock]$FailureAction  # Action to take on failed response: param($response, $originalContext)
    )

    if (-not $BatchResponses -or -not $BatchResponses.responses) {
        Write-Warning "Invoke-MyGraphBatchResponse: Invalid or empty batch response received for $DataType."
        # Mark all items in this batch as failed based on IdMap keys
        foreach ($reqId in $IdMap.Keys) {
            $originalContext = $IdMap[$reqId]
            try {
                 Invoke-Command -ScriptBlock $FailureAction -ArgumentList $null, $originalContext # Pass null response
            } catch {
                 Write-Warning "Invoke-MyGraphBatchResponse: Error executing FailureAction for $DataType context '$originalContext' (Request ID $reqId) after empty batch response. Error: $($_.Exception.Message)"
            }
        }
        return
    }

    Write-Verbose "Invoke-MyGraphBatchResponse: Processing $($BatchResponses.responses.Count) responses for $DataType."
    foreach ($response in $BatchResponses.responses) {
        $originalContext = $IdMap[$response.id]
        if ($null -eq $originalContext) {
            Write-Warning "Invoke-MyGraphBatchResponse: Could not map response ID $($response.id) back for $DataType."
            continue
        }

        if ($response.status -ge 200 -and $response.status -lt 300) {
            try {
                # Pass the body directly to the success action
                Invoke-Command -ScriptBlock $SuccessAction -ArgumentList $response.body, $originalContext
            } catch {
                Write-Warning "Invoke-MyGraphBatchResponse: Error executing SuccessAction for $DataType context '$originalContext'. Response ID: $($response.id). Error: $($_.Exception.Message)"
                # Invoke failure action as processing failed
                 try {
                    Invoke-Command -ScriptBlock $FailureAction -ArgumentList $response, $originalContext
                 } catch {
                    Write-Warning "Invoke-MyGraphBatchResponse: Error executing FailureAction for $DataType context '$originalContext' (Request ID $response.id) after SuccessAction error. Error: $($_.Exception.Message)"
                 }
            }
        } else {
            Write-Warning "Invoke-MyGraphBatchResponse: Failed request in batch for $DataType (Context: '$originalContext', Response ID: $($response.id)). Status: $($response.status). Body: $($response.body | ConvertTo-Json -Depth 3 -Compress)"
             try {
                Invoke-Command -ScriptBlock $FailureAction -ArgumentList $response, $originalContext
             } catch {
                 Write-Warning "Invoke-MyGraphBatchResponse: Error executing FailureAction for failed $DataType request (Context '$originalContext', Request ID $response.id). Error: $($_.Exception.Message)"
             }
        }
    }
     Write-Verbose "Invoke-MyGraphBatchResponse: Finished processing responses for $DataType."
}