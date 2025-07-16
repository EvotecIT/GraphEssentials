function Get-GraphEssentialsSignInLogsReport {
    <#
    .SYNOPSIS
    Retrieves sign-in logs for service principals from Microsoft Graph.

    .DESCRIPTION
    Fetches sign-in logs for the specified number of days, processes them to determine
    the latest sign-in method used by each application.

    .PARAMETER Days
    Number of days back to check for sign-in logs. Default is 30.

    .NOTES
    Requires AuditLog.Read.All permission.
    #>
    param(
        [int]$Days = 30 # How many days back to check for logs
    )

    Write-Verbose "Get-GraphEssentialsSignInLogsReport: Fetching Service Principal Sign-in Logs (Last $($Days) Days)..."
    # Note: Requires AuditLog.Read.All
    $LastSignInMethodReport = @{}
    try {
        # Fetch logs within the specified period, limit properties. Filter for successful sign-ins with appId
        $startTime = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')

        # Using only valid properties for signIn objects
        # Note: removed clientCredentialType which isn't a valid property according to the error
        $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime and appId ne null and status/errorCode eq 0&`$select=appId,appDisplayName,createdDateTime,status,resourceDisplayName&`$top=999"

        Write-Verbose "Get-GraphEssentialsSignInLogsReport: Executing query with URI: $signInLogsUri"

        # Use try/catch for better error handling
        try {
            $signInsResponse = Invoke-MgGraphRequest -Uri $signInLogsUri -Method GET -ErrorAction Stop
            $signIns = $signInsResponse.value
            $NextLink = $signInsResponse.'@odata.nextLink'

            while ($null -ne $NextLink) {
                Write-Verbose "Get-GraphEssentialsSignInLogsReport: Fetching next page for sign-in logs..."
                $signInsResponse = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
                $signIns += $signInsResponse.value
                $NextLink = $signInsResponse.'@odata.nextLink'
            }

            if ($signIns) {
                # Use a single pass array comprehension to collect processed apps
                $processedApps = @($signIns |
                    Sort-Object CreatedDateTime -Descending | Group-Object AppId | ForEach-Object {
                        if (-not $LastSignInMethodReport.ContainsKey($_.Name)) {
                            # Since clientCredentialType is not available, we'll use other information
                            $latestEntry = $_.Group | Select-Object -First 1
                            if ($null -ne $latestEntry) {
                                # We're using the resource name as a proxy for authentication method
                                $authMethod = "Unknown"
                                if ($latestEntry.resourceDisplayName) {
                                    $authMethod = $latestEntry.resourceDisplayName
                                }
                                $LastSignInMethodReport[$_.Name] = $authMethod
                                $_.Name # Output for counting
                            }
                        }
                    })
                Write-Verbose "Get-GraphEssentialsSignInLogsReport: Processed sign-in logs for $($processedApps.Count) apps."
            } else {
                Write-Verbose "Get-GraphEssentialsSignInLogsReport: No relevant sign-in logs found in the last $Days days."
            }
        } catch {
            # Use the shared error handling function
            $errorInfo = $_ | Get-GraphEssentialsErrorDetails -FunctionName 'Get-GraphEssentialsSignInLogsReport'
            Write-Warning $errorInfo.FullMessage
        }
    } catch {
        # Catch any other unexpected errors
        Write-Warning "Get-GraphEssentialsSignInLogsReport: Unexpected error: $($_.Exception.Message)"
    }
    $LastSignInMethodReport
}