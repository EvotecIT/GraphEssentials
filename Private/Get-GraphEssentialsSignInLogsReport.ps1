function Get-GraphEssentialsSignInLogsReport {
    <#
    .SYNOPSIS
    Retrieves sign-in logs for service principals from Microsoft Graph.

    .DESCRIPTION
    Fetches sign-in logs for the specified number of days, processes them to determine
    the latest sign-in method used by each application. Note: This function can be
    performance-intensive for large tenants as it downloads detailed sign-in logs.

    .PARAMETER Days
    Number of days back to check for sign-in logs. Default is 30.

    .PARAMETER IncludeAuthenticationMethods
    Whether to fetch detailed sign-in logs to determine authentication methods.
    WARNING: This can be very slow for large tenants as it downloads all sign-in logs.
    Default is $false for performance reasons.

    .NOTES
    Requires AuditLog.Read.All permission.
    For better performance, consider using Get-GraphEssentialsSignInActivityReport instead.
    #>
    param(
        [int]$Days = 30, # How many days back to check for logs
        [bool]$IncludeAuthenticationMethods = $false # Whether to fetch detailed logs
    )

    Write-Verbose "Get-GraphEssentialsSignInLogsReport: Starting (IncludeAuthenticationMethods: $IncludeAuthenticationMethods)"
    $LastSignInMethodReport = @{}

    if (-not $IncludeAuthenticationMethods) {
        Write-Verbose "Get-GraphEssentialsSignInLogsReport: Skipping detailed sign-in logs for performance (use -IncludeAuthenticationMethods to enable)"
        return $LastSignInMethodReport
    }

    # Only proceed with detailed logs if explicitly requested
    Write-Verbose "Get-GraphEssentialsSignInLogsReport: Fetching detailed Service Principal Sign-in Logs (Last $($Days) Days)..."
    Write-Warning "Get-GraphEssentialsSignInLogsReport: Fetching detailed sign-in logs can be slow for large tenants"

    try {
        # Calculate start time for the date filter
        $startTime = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

        # Use simpler query that works with v1.0 signIns endpoint
        # Note: This can still be slow as it downloads all sign-ins, but at least it works
        $signInLogsUri = "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $startTime&`$select=appId,appDisplayName,createdDateTime,status,resourceDisplayName&`$top=999"

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
                # Filter for service principal sign-ins (those with appId) and successful sign-ins on the client side
                $servicePrincipalSignIns = $signIns | Where-Object {
                    $_.appId -and $_.status -and $_.status.errorCode -eq 0
                }

                if ($servicePrincipalSignIns) {
                    # Process sign-ins to build the last sign-in method report
                    $servicePrincipalSignIns |
                    Sort-Object CreatedDateTime -Descending |
                    Group-Object AppId | ForEach-Object {
                        if (-not $LastSignInMethodReport.ContainsKey($_.Name)) {
                            $latestEntry = $_.Group | Select-Object -First 1
                            if ($null -ne $latestEntry) {
                                # Use the resource name as a proxy for authentication method
                                $authMethod = "Unknown"
                                if ($latestEntry.resourceDisplayName) {
                                    $authMethod = $latestEntry.resourceDisplayName
                                }
                                $LastSignInMethodReport[$_.Name] = $authMethod
                            }
                        }
                    }
                    Write-Verbose "Get-GraphEssentialsSignInLogsReport: Processed sign-in logs for $($LastSignInMethodReport.Count) apps with successful sign-ins."
                } else {
                    Write-Verbose "Get-GraphEssentialsSignInLogsReport: No successful service principal sign-in logs found in the last $Days days."
                }
            } else {
                Write-Verbose "Get-GraphEssentialsSignInLogsReport: No sign-in logs found in the last $Days days."
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