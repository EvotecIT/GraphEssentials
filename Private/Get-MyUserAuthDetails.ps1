function Get-MyUserAuthDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[object]]$DetailRequestsList, # List of request items needing detail fetch

        [Parameter(Mandatory)]
        [int]$BatchSize
    )

    $fetchedDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new() # Store fetched details keyed by RequestId
    Write-Verbose "Get-MyUserAuthDetails: Starting batch fetch for $($DetailRequestsList.Count) method details..."

    for ($i = 0; $i -lt $DetailRequestsList.Count; $i += $BatchSize) {
        $batchDetailItems = $DetailRequestsList.GetRange($i, [math]::Min($BatchSize, $DetailRequestsList.Count - $i))
        $batchDetailRequests = @()
        $detailIdMap = @{} # Map request ID to the original request item

        foreach ($item in $batchDetailItems) {
            if (-not $item -or -not $item.BatchUrl) { continue }
            $batchDetailRequests += @{
                id     = $item.RequestId
                method = "GET"
                url    = $item.BatchUrl
            }
            $detailIdMap[$item.RequestId] = $item # Map to the whole item
        }

        if ($batchDetailRequests.Count -eq 0) { continue }

        $dataType = "Method Details (Batch $i)"
        $batchDetailResponses = Invoke-MyGraphBatchRequest -BatchRequests $batchDetailRequests -DataType $dataType

        if ($batchDetailResponses) {
            $processedResults = Invoke-MyGraphBatchResponse -BatchResponses $batchDetailResponses -IdMap $detailIdMap -DataType $dataType
            foreach ($result in $processedResults) {
                $originalRequestItem = $result.Context
                if ($null -eq $originalRequestItem) { continue } # Already warned

                if ($result.Success) {
                    # Store the fetched detail body and mark as processed
                    $fetchedDetails[$originalRequestItem.RequestId] = $result.Body
                    $originalRequestItem.Processed = $true
                    # Also store directly on the request item for easier access later?
                    # $originalRequestItem.DetailData = $result.Body
                } else {
                    # Mark as processed but indicate failure (no data)
                    $fetchedDetails[$originalRequestItem.RequestId] = $null # Indicate failure explicitly
                    $originalRequestItem.Processed = $true # Still mark processed to avoid re-trying logic
                    # $originalRequestItem.DetailData = $null
                }
            }
        } else {
            # Handle complete batch failure - mark all items in this batch as processed but failed
            foreach ($reqId in $detailIdMap.Keys) {
                $failedRequestItem = $detailIdMap[$reqId]
                if ($null -ne $failedRequestItem) {
                    $fetchedDetails[$failedRequestItem.RequestId] = $null
                    $failedRequestItem.Processed = $true
                    # $failedRequestItem.DetailData = $null
                }
            }
        }
    } # End batch loop ($i)

    Write-Verbose "Get-MyUserAuthDetails: Finished fetching method details."
    # The details are stored in $fetchedDetails, and request items in $DetailRequestsList are marked .Processed
    # We could return $fetchedDetails, but the information is also implicitly stored via $DetailRequestsList modifications
    # Let's return $fetchedDetails for clarity, although the main function might primarily use $DetailRequestsList
    return $fetchedDetails
}