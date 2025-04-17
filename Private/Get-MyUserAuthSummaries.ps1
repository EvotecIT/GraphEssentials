function Get-MyUserAuthSummaries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$UserIds,

        [Parameter(Mandatory)]
        [int]$BatchSize
    )

    $allAuthMethods = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new() # Store summary methods per UserId
    Write-Verbose "Get-MyUserAuthSummaries: Starting batch fetch for authentication method summaries for $($UserIds.Count) users..."

    for ($i = 0; $i -lt $UserIds.Count; $i += $BatchSize) {
        $batchUserIds = $UserIds[$i..([math]::Min($i + $BatchSize - 1, $UserIds.Count - 1))]
        $batchRequests = @()
        $idMap = @{} # Map request ID to UserId for this batch
        $userCounterInBatch = 0

        foreach ($userId in $batchUserIds) {
            if (-not $userId) { continue }
            $userCounterInBatch++
            $requestId = "summary_$($i)_$($userCounterInBatch)" # Unique ID for summary requests
            $batchRequests += @{
                id     = $requestId
                method = "GET"
                url    = "/users/$userId/authentication/methods"
            }
            $idMap[$requestId] = $userId
        }

        if ($batchRequests.Count -eq 0) { continue }

        $dataType = "Auth Methods Summary (Batch $i)"
        $batchResponses = Invoke-MyGraphBatchRequest -BatchRequests $batchRequests -DataType $dataType

        if ($batchResponses) {
            $processedResults = Invoke-MyGraphBatchResponse -BatchResponses $batchResponses -IdMap $idMap -DataType $dataType
            foreach ($result in $processedResults) {
                $currentUserId = $result.Context
                if ($null -eq $currentUserId) { continue } # Already warned by Invoke-MyGraphBatchResponse

                if ($result.Success) {
                    $methods = $result.Body.value # Assuming the structure is { value: [...] }
                    $allAuthMethods[$currentUserId] = if ($methods) { $methods } else { @() }
                } else {
                    # Handle failure - mark as null
                    $allAuthMethods[$currentUserId] = $null
                }
            }
        } else {
            # Handle complete batch failure - mark all users in this batch as failed
            foreach ($reqId in $idMap.Keys) {
                $failedUserId = $idMap[$reqId]
                if ($null -ne $failedUserId) {
                    $allAuthMethods[$failedUserId] = $null
                }
            }
        }
    } # End batch loop ($i)

    Write-Verbose "Get-MyUserAuthSummaries: Finished fetching authentication method summaries."
    return $allAuthMethods
}