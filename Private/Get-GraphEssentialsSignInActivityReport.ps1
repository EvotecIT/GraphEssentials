function Get-GraphEssentialsSignInActivityReport {
    <#
    .SYNOPSIS
    Gets comprehensive sign-in activity report for service principals from Microsoft Graph.

    .DESCRIPTION
    Retrieves detailed sign-in activity for service principals including delegated and application
    authentication activities with days since last activity calculations for security assessment.
    Combines aggregated historical data with real-time sign-in logs for complete coverage.

    .PARAMETER IncludeRealtimeData
    Include real-time sign-in logs to supplement aggregated data. This provides current activity
    that may not yet be reflected in the aggregated servicePrincipalSignInActivity endpoint.

    .NOTES
    Uses both /beta/reports/servicePrincipalSignInActivities (aggregated) and
    /beta/auditLogs/signIns (real-time) endpoints for comprehensive coverage.
    #>
    param(
        [switch]$IncludeRealtimeData
    )

    Write-Verbose "Get-GraphEssentialsSignInActivityReport: Fetching comprehensive service principal sign-in activities..."

    $SignInActivityReport = @{}

    try {
        # Get aggregated service principal sign-in activities using the beta endpoint
        Write-Verbose "Get-GraphEssentialsSignInActivityReport: Calling Microsoft Graph /beta/reports/servicePrincipalSignInActivities"

        # Import required module if not already available
        if (-not (Get-Command "Get-MgBetaReportServicePrincipalSignInActivity" -ErrorAction SilentlyContinue)) {
            try {
                Import-Module Microsoft.Graph.Beta.Reports -Force -ErrorAction Stop
                Write-Verbose "Get-GraphEssentialsSignInActivityReport: Imported Microsoft.Graph.Beta.Reports module"
            } catch {
                Write-Warning "Get-GraphEssentialsSignInActivityReport: Failed to import Microsoft.Graph.Beta.Reports module. Install with: Install-Module Microsoft.Graph.Beta.Reports"
                return $SignInActivityReport
            }
        }

        # Get all service principal sign-in activities (aggregated data)
        $Activities = Get-MgBetaReportServicePrincipalSignInActivity -All -ErrorAction Stop
        Write-Verbose "Get-GraphEssentialsSignInActivityReport: Retrieved $($Activities.Count) service principal sign-in activities from aggregated endpoint"

        $Now = Get-Date

        foreach ($Activity in $Activities) {
            if (-not $Activity.AppId) { continue }

            # Create comprehensive sign-in report for this app
            $Report = @{
                # Overall activity
                LastSignInDateTime = $Activity.LastSignInActivity.LastSignInDateTime
                LastSuccessfulSignInDateTime = $Activity.LastSignInActivity.LastSuccessfulSignInDateTime
                LastNonInteractiveSignInDateTime = $Activity.LastSignInActivity.LastNonInteractiveSignInDateTime

                # Delegated client activity (users signing in through this app)
                DelegatedClientLastSignIn = $Activity.DelegatedClientSignInActivity.LastSignInDateTime
                DelegatedClientLastSuccessfulSignIn = $Activity.DelegatedClientSignInActivity.LastSuccessfulSignInDateTime
                DelegatedClientLastNonInteractiveSignIn = $Activity.DelegatedClientSignInActivity.LastNonInteractiveSignInDateTime

                # Application authentication as client (app signing in with its own identity)
                ApplicationClientLastSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastSignInDateTime
                ApplicationClientLastSuccessfulSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastSuccessfulSignInDateTime
                ApplicationClientLastNonInteractiveSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastNonInteractiveSignInDateTime

                # Delegated resource activity (this app being accessed by other apps on behalf of users)
                DelegatedResourceLastSignIn = $Activity.DelegatedResourceSignInActivity.LastSignInDateTime
                DelegatedResourceLastSuccessfulSignIn = $Activity.DelegatedResourceSignInActivity.LastSuccessfulSignInDateTime
                DelegatedResourceLastNonInteractiveSignIn = $Activity.DelegatedResourceSignInActivity.LastNonInteractiveSignInDateTime

                # Application authentication as resource (this app being accessed directly by other apps)
                ApplicationResourceLastSignIn = $Activity.ApplicationAuthenticationResourceSignInActivity.LastSignInDateTime
                ApplicationResourceLastSuccessfulSignIn = $Activity.ApplicationAuthenticationResourceSignInActivity.LastSuccessfulSignInDateTime
                ApplicationResourceLastNonInteractiveSignIn = $Activity.ApplicationAuthenticationResourceSignInActivity.LastNonInteractiveSignInDateTime

                # Track data source
                DataSource = "Aggregated"
            }

            $SignInActivityReport[$Activity.AppId] = $Report
        }

        # Supplement with real-time data if requested
        if ($IncludeRealtimeData) {
            Write-Verbose "Get-GraphEssentialsSignInActivityReport: Fetching real-time sign-in logs for current activity..."

            try {
                # Get recent sign-ins (last 7 days) for more current data
                $LastWeek = (Get-Date).AddDays(-7).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                $Uri = "/beta/auditLogs/signIns?`$filter=createdDateTime ge $LastWeek&`$top=1000"

                Write-Verbose "Get-GraphEssentialsSignInActivityReport: Calling $Uri"
                $RealtimeSignIns = Invoke-MgGraphRequest -Uri $Uri -Method GET

                                if ($RealtimeSignIns.value -and $RealtimeSignIns.value.Count -gt 0) {
                    Write-Verbose "Get-GraphEssentialsSignInActivityReport: Retrieved $($RealtimeSignIns.value.Count) real-time sign-in records"

                    # Filter out records without valid dates and group by appId
                    $ValidSignIns = $RealtimeSignIns.value | Where-Object { $_.createdDateTime -and $_.appId }
                    $RealtimeByApp = $ValidSignIns | Group-Object -Property appId

                    foreach ($AppGroup in $RealtimeByApp) {
                        $AppId = $AppGroup.Name
                        if (-not $AppId) { continue }

                        # Get most recent sign-ins for this app
                        $AppSignIns = $AppGroup.Group | Sort-Object -Property createdDateTime -Descending
                        $MostRecentSignIn = $AppSignIns[0]
                        $MostRecentSuccessful = $AppSignIns | Where-Object { $_.status.errorCode -eq 0 } | Select-Object -First 1

                        # Update or create report entry
                        if (-not $SignInActivityReport.ContainsKey($AppId)) {
                            $SignInActivityReport[$AppId] = @{
                                DataSource = "Real-time Only"
                            }
                        }

                        $Report = $SignInActivityReport[$AppId]

                        # Update with real-time data if it's more recent
                        if (-not $MostRecentSignIn.createdDateTime) { continue }
                        $RealtimeDate = [DateTime]::Parse($MostRecentSignIn.createdDateTime)

                        if ($Report.LastSignInDateTime) {
                            $AggregatedDate = if ($Report.LastSignInDateTime -is [DateTime]) {
                                $Report.LastSignInDateTime
                            } else {
                                [DateTime]::Parse($Report.LastSignInDateTime)
                            }

                            if ($RealtimeDate -gt $AggregatedDate) {
                                $Report.LastSignInDateTime = $RealtimeDate
                                $Report.DataSource = "Real-time Enhanced"
                                Write-Verbose "Get-GraphEssentialsSignInActivityReport: Updated $AppId with more recent real-time data: $RealtimeDate"
                            }
                        } else {
                            $Report.LastSignInDateTime = $RealtimeDate
                            $Report.DataSource = "Real-time Only"
                        }

                        # Update successful sign-in if more recent
                        if ($MostRecentSuccessful -and $MostRecentSuccessful.createdDateTime) {
                            $RealtimeSuccessDate = [DateTime]::Parse($MostRecentSuccessful.createdDateTime)

                            if ($Report.LastSuccessfulSignInDateTime) {
                                $AggregatedSuccessDate = if ($Report.LastSuccessfulSignInDateTime -is [DateTime]) {
                                    $Report.LastSuccessfulSignInDateTime
                                } else {
                                    [DateTime]::Parse($Report.LastSuccessfulSignInDateTime)
                                }

                                if ($RealtimeSuccessDate -gt $AggregatedSuccessDate) {
                                    $Report.LastSuccessfulSignInDateTime = $RealtimeSuccessDate
                                }
                            } else {
                                $Report.LastSuccessfulSignInDateTime = $RealtimeSuccessDate
                            }
                        }

                        # Add app display name from real-time data
                        if ($MostRecentSignIn.appDisplayName) {
                            $Report.AppDisplayName = $MostRecentSignIn.appDisplayName
                        }
                    }
                } else {
                    Write-Verbose "Get-GraphEssentialsSignInActivityReport: No real-time sign-in data found"
                }

            } catch {
                Write-Warning "Get-GraphEssentialsSignInActivityReport: Failed to retrieve real-time sign-in data: $($_.Exception.Message)"
                Write-Verbose "Get-GraphEssentialsSignInActivityReport: Real-time error details: $($_.Exception | Out-String)"
            }
        }

        # Calculate "Days Since Last Activity" for all reports
        foreach ($AppId in $SignInActivityReport.Keys) {
            $Report = $SignInActivityReport[$AppId]

            # Calculate "Days Since Last Activity" for security assessment
            $AllSignInDates = @(
                $Report.LastSignInDateTime,
                $Report.DelegatedClientLastSignIn,
                $Report.ApplicationClientLastSignIn,
                $Report.DelegatedResourceLastSignIn,
                $Report.ApplicationResourceLastSignIn
            ) | Where-Object { $_ -ne $null }

            if ($AllSignInDates.Count -gt 0) {
                $MostRecentActivity = ($AllSignInDates | Sort-Object -Descending)[0]
                $Report.DaysSinceLastActivity = [Math]::Round(($Now - $MostRecentActivity).TotalDays)
                $Report.MostRecentActivityDate = $MostRecentActivity
            } else {
                $Report.DaysSinceLastActivity = $null
                $Report.MostRecentActivityDate = $null
            }

            # Calculate "Days Since Last Successful Activity" for security assessment
            $AllSuccessfulSignInDates = @(
                $Report.LastSuccessfulSignInDateTime,
                $Report.DelegatedClientLastSuccessfulSignIn,
                $Report.ApplicationClientLastSuccessfulSignIn,
                $Report.DelegatedResourceLastSuccessfulSignIn,
                $Report.ApplicationResourceLastSuccessfulSignIn
            ) | Where-Object { $_ -ne $null }

            if ($AllSuccessfulSignInDates.Count -gt 0) {
                $MostRecentSuccessfulActivity = ($AllSuccessfulSignInDates | Sort-Object -Descending)[0]
                $Report.DaysSinceLastSuccessfulActivity = [Math]::Round(($Now - $MostRecentSuccessfulActivity).TotalDays)
                $Report.MostRecentSuccessfulActivityDate = $MostRecentSuccessfulActivity
            } else {
                $Report.DaysSinceLastSuccessfulActivity = $null
                $Report.MostRecentSuccessfulActivityDate = $null
            }

            # Determine activity type for security assessment
            $ActivityTypes = @()
            if ($Report.DelegatedClientLastSignIn) { $ActivityTypes += "Delegated Client" }
            if ($Report.ApplicationClientLastSignIn) { $ActivityTypes += "Application Client" }
            if ($Report.DelegatedResourceLastSignIn) { $ActivityTypes += "Delegated Resource" }
            if ($Report.ApplicationResourceLastSignIn) { $ActivityTypes += "Application Resource" }

            $Report.ActivityTypes = $ActivityTypes -join ", "
            if (-not $Report.ActivityTypes) { $Report.ActivityTypes = "No Activity" }
        }

        Write-Verbose "Get-GraphEssentialsSignInActivityReport: Processed $($SignInActivityReport.Count) apps with comprehensive sign-in data"

    } catch {
        Write-Warning "Get-GraphEssentialsSignInActivityReport: Error retrieving service principal sign-in activities. $($_.Exception.Message)"
        Write-Verbose "Get-GraphEssentialsSignInActivityReport: Full error: $($_.Exception | Out-String)"
    }

    return $SignInActivityReport
}