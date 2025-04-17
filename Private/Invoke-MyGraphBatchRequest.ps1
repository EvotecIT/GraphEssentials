function Invoke-MyGraphBatchRequest {
    param(
        [Parameter(Mandatory)]
        [array]$BatchRequests,

        [Parameter(Mandatory)]
        [string]$DataType # For logging purposes (e.g., "Auth Methods Summary", "Method Details")
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
        Write-Warning "Invoke-MyGraphBatchRequest: Batch request failed for $DataType. Error: $($_.Exception.Message)"
        # Optionally add more details like the first few request IDs if needed for debugging
        # Write-Warning "Failed Batch Body (first part): $($body.Substring(0, [math]::Min($body.Length, 500)))..."
        return $null # Indicate failure
    }
}