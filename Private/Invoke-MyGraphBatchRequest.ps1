function Invoke-MyGraphBatchRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$BatchRequests,

        [Parameter(Mandatory)]
        [string]$DataType, # For logging purposes (e.g., "Auth Methods Summary", "Method Details")

        [Parameter()]
        [int]$MaxRetryCount = 3,

        [Parameter()]
        [int]$RetryAttempt = 0
    )

    if ($BatchRequests.Count -eq 0) {
        Write-Verbose "Invoke-MyGraphBatchRequest: No requests provided for $DataType. Skipping."
        return $null
    }

    try {
        Write-Verbose "Invoke-MyGraphBatchRequest: Sending batch request for $DataType ($($BatchRequests.Count) items)..."
        $body = [PSCustomObject]@{requests = $BatchRequests } | ConvertTo-Json -Depth 5
        $response = Invoke-MgGraphRequest -Uri '/beta/$batch' -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
        Write-Verbose "Invoke-MyGraphBatchRequest: Received response for $DataType."
        return $response
    } catch {
        $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Invoke-MyGraphBatchRequest'
        if (($errorInfo.IsTransient -or $errorInfo.StatusCode -eq 429) -and $RetryAttempt -lt $MaxRetryCount) {
            $nextRetryAttempt = $RetryAttempt + 1
            $retryDelaySeconds = [Math]::Max(5, [Math]::Min(30, 5 * $nextRetryAttempt))
            Write-Warning "Invoke-MyGraphBatchRequest: Transient batch failure for $DataType. Waiting $retryDelaySeconds second(s) before retry $nextRetryAttempt/$MaxRetryCount. Error: $($errorInfo.Message)"
            Start-Sleep -Seconds $retryDelaySeconds
            return Invoke-MyGraphBatchRequest -BatchRequests $BatchRequests -DataType $DataType -MaxRetryCount $MaxRetryCount -RetryAttempt $nextRetryAttempt
        }

        Write-Warning "Invoke-MyGraphBatchRequest: Batch request failed for $DataType. Error: $($errorInfo.Message)"
        # Optionally add more details like the first few request IDs if needed for debugging
        # Write-Warning "Failed Batch Body (first part): $($body.Substring(0, [math]::Min($body.Length, 500)))..."
        return $null # Indicate failure
    }
}
