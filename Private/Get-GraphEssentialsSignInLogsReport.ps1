function Get-GraphEssentialsSignInLogsReport {
    param(
        [int]$Days = 30 # How many days back to check for logs
    )
    Write-Verbose "Get-GraphEssentialsSignInLogsReport: Fetching Service Principal Sign-in Logs (Last $($Days) Days)..."
    # Note: Requires AuditLog.Read.All
    $LastSignInMethodReport = @{}
    try {
        # Fetch logs within the specified period, limit properties. Filter for successful interactive/non-interactive SP sign-ins.
        $startTime = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
        # Filter for successful SP signins (interactive or non-interactive), excluding errors
        # $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime and appId ne null and status/errorCode eq 0 and (signInEventTypes/any(t: t eq 'servicePrincipal'))&`$select=appId,clientCredentialType,createdDateTime&`$top=999"
        # Simpler filter focusing on errorCode and presence of appId - might be sufficient and more reliable
        # $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime and appId ne null and status/errorCode eq 0&`$select=appId,clientCredentialType,createdDateTime&`$top=999"
        # Simplest filter for testing BadRequest
        # $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime and appId ne null&`$select=appId,clientCredentialType,createdDateTime&`$top=999"
        # Filter using signInEventTypes
        $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime and signInEventTypes/any(t: t eq 'servicePrincipal' or t eq 'managedIdentity')&`$select=appId,clientCredentialType,createdDateTime,status&`$top=999"

        # Use Invoke-MgGraphRequest with manual paging
        $signInsResponse = Invoke-MgGraphRequest -Uri $signInLogsUri -Method GET -ErrorAction Stop
        $signIns = $signInsResponse.value
        $NextLink = $signInsResponse.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-GraphEssentialsSignInLogsReport: Fetching next page for sign-in logs..."
            $signInsResponse = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            $signIns += $signInsResponse.value
            $NextLink = $signInsResponse.'@odata.nextLink'
        }

        if ($signIns) {
            # Process logs to find the latest per app
            # Grouping after sorting ensures we get the latest clientCredentialType used by each app
            $signIns | Sort-Object CreatedDateTime -Descending | Group-Object AppId | ForEach-Object {
                if (-not $LastSignInMethodReport.ContainsKey($_.Name)) {
                    # Find the first log entry in the sorted group that has a ClientCredentialType
                    $latestEntryWithMethod = $_.Group | Where-Object { -ne $_.ClientCredentialType } | Select-Object -First 1
                    if ($latestEntryWithMethod) {
                        $LastSignInMethodReport[$_.Name] = $latestEntryWithMethod.ClientCredentialType
                    }
                }
            }
            Write-Verbose "Get-GraphEssentialsSignInLogsReport: Processed sign-in logs for last sign-in method for $($LastSignInMethodReport.Count) apps."
        } else {
             Write-Verbose "Get-GraphEssentialsSignInLogsReport: No relevant sign-in logs found in the last $Days days."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsSignInLogsReport: Failed to retrieve Service Principal Sign-in Logs. Last sign-in method will be unavailable. Error: $($_.Exception.Message)"
        # Check specifically for permission errors if possible
        if ($_.Exception.ToString() -like '*Authorization_RequestDenied*' -or $_.Exception.ToString() -like '*Permission*') {
            Write-Warning "Get-GraphEssentialsSignInLogsReport: This often indicates missing AuditLog.Read.All permissions."
        }
    }
    return $LastSignInMethodReport
}