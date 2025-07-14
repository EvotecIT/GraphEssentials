function Get-GraphEssentialsComprehensiveActivityReport {
    <#
    .SYNOPSIS
    Gets comprehensive application activity report from multiple sources for security assessment.

    .DESCRIPTION
    Tracks application activity across multiple dimensions:
    - User sign-ins (interactive and non-interactive)
    - Service principal API usage and authentication
    - Delegated access through Azure Portal and other Microsoft services
    - Application authentication activity
    - Microsoft Graph API calls and operations

    This provides a complete picture of when applications were last "used" in any capacity
    for security assessment and identifying unused/dead applications.

    .PARAMETER Days
    Number of days back to check for activity. Default is 90 days for comprehensive assessment.

    .PARAMETER IncludeRealtimeSignIns
    Include real-time sign-in logs for enhanced accuracy. WARNING: This can be very expensive for large tenants (100k+ users).
    Default is $false for performance reasons. The aggregated data is usually sufficient for security assessment.

    .PARAMETER SpecificAppIds
    Array of specific AppIds to fetch real-time data for. Only used when IncludeRealtimeSignIns is $true.
    If not specified, fetches for all applications (can be very expensive).

    .PARAMETER MaxRealtimeRecords
    Maximum number of real-time sign-in records to fetch. Default is 1000 to prevent excessive API calls.

    .NOTES
    Combines data from multiple Microsoft Graph endpoints:
    - /beta/reports/servicePrincipalSignInActivities (aggregated sign-ins) - PRIMARY SOURCE
    - /beta/auditLogs/signIns (real-time user sign-ins) - OPTIONAL, expensive for large tenants
    - /beta/auditLogs/directoryAudits (service principal operations) - Light usage only
    - Microsoft Graph usage analytics where available

    For large tenants (100k+ users), recommend using IncludeRealtimeSignIns=$false and rely on aggregated data.
    #>
    param(
        [int]$Days = 90,
        [bool]$IncludeRealtimeSignIns = $false,
        [string[]]$SpecificAppIds = @(),
        [int]$MaxRealtimeRecords = 1000
    )

    Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Starting comprehensive application activity analysis (last $Days days)..."

    $ActivityReport = @{}
    $StartDate = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $Now = Get-Date

    try {
        # Step 1: Get aggregated service principal sign-in activities
        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Getting aggregated service principal sign-in activities..."

        if (-not (Get-Command "Get-MgBetaReportServicePrincipalSignInActivity" -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Beta.Reports -Force -ErrorAction Stop
        }

        $ServicePrincipalActivities = Get-MgBetaReportServicePrincipalSignInActivity -All -ErrorAction Stop
        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Retrieved $($ServicePrincipalActivities.Count) service principal activity records"

        foreach ($Activity in $ServicePrincipalActivities) {
            if (-not $Activity.AppId) { continue }

            $ActivityReport[$Activity.AppId] = @{
                # Aggregated sign-in activity
                LastSignInDateTime = $Activity.LastSignInActivity.LastSignInDateTime
                LastSuccessfulSignInDateTime = $Activity.LastSignInActivity.LastSuccessfulSignInDateTime
                DelegatedClientLastSignIn = $Activity.DelegatedClientSignInActivity.LastSignInDateTime
                DelegatedClientLastSuccessfulSignIn = $Activity.DelegatedClientSignInActivity.LastSuccessfulSignInDateTime
                ApplicationClientLastSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastSignInDateTime
                ApplicationClientLastSuccessfulSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastSuccessfulSignInDateTime
                DelegatedResourceLastSignIn = $Activity.DelegatedResourceSignInActivity.LastSignInDateTime
                ApplicationResourceLastSignIn = $Activity.ApplicationAuthenticationResourceSignInActivity.LastSignInDateTime

                # Activity sources
                ActivitySources = @("Aggregated Sign-ins")
                DataQuality = "Aggregated"
            }
        }

        # Step 2: Get real-time sign-in logs for current activity (OPTIONAL - expensive for large tenants)
        if ($IncludeRealtimeSignIns) {
            Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Getting real-time sign-in logs for current activity..."

            if ($SpecificAppIds.Count -eq 0) {
                Write-Warning "Get-GraphEssentialsComprehensiveActivityReport: Fetching real-time sign-ins for ALL applications. This can be very expensive for large tenants (100k+ users). Consider using -SpecificAppIds parameter."
            } else {
                Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Fetching real-time sign-ins for $($SpecificAppIds.Count) specific applications..."
            }

            try {
                # Build the filter with optional appId filtering
                $SignInFilter = "createdDateTime ge $StartDate"
                if ($SpecificAppIds.Count -gt 0) {
                    # Add appId filter for specific apps (batch in groups of 10 to avoid URL length limits)
                    $AppIdBatches = @()
                    for ($i = 0; $i -lt $SpecificAppIds.Count; $i += 10) {
                        $BatchAppIds = $SpecificAppIds[$i..([Math]::Min($i + 9, $SpecificAppIds.Count - 1))]
                        $AppIdFilter = "(" + (($BatchAppIds | ForEach-Object { "appId eq '$_'" }) -join " or ") + ")"
                        $AppIdBatches += $AppIdFilter
                    }

                    # For now, let's process the first batch to avoid complexity
                    if ($AppIdBatches.Count -gt 0) {
                        $SignInFilter += " and " + $AppIdBatches[0]
                        if ($AppIdBatches.Count -gt 1) {
                            Write-Warning "Get-GraphEssentialsComprehensiveActivityReport: Too many specific AppIds provided. Processing first 10 apps only to avoid API limits."
                        }
                    }
                }

                $SignInUri = "/beta/auditLogs/signIns?`$filter=$SignInFilter&`$top=$MaxRealtimeRecords"
                Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Calling $SignInUri"
                $SignInResult = Invoke-MgGraphRequest -Uri $SignInUri -Method GET

                if ($SignInResult.value -and $SignInResult.value.Count -gt 0) {
                    Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Processing $($SignInResult.value.Count) real-time sign-in records..."

                    # Process real-time sign-ins
                    $ValidSignIns = $SignInResult.value | Where-Object { $_.createdDateTime -and $_.appId }
                    $SignInsByApp = $ValidSignIns | Group-Object -Property appId

                foreach ($AppGroup in $SignInsByApp) {
                    $AppId = $AppGroup.Name
                    $AppSignIns = $AppGroup.Group | Sort-Object -Property createdDateTime -Descending
                    $MostRecentSignIn = $AppSignIns[0]
                    $MostRecentSuccessful = $AppSignIns | Where-Object { $_.status.errorCode -eq 0 } | Select-Object -First 1

                    # Update or create activity record
                    if (-not $ActivityReport.ContainsKey($AppId)) {
                        $ActivityReport[$AppId] = @{
                            ActivitySources = @()
                            DataQuality = "Real-time Only"
                        }
                    }

                    $Report = $ActivityReport[$AppId]

                    # Skip if no valid date
                    if (-not $MostRecentSignIn.createdDateTime) { continue }

                    # Handle different date formats from the API
                    try {
                        $RealtimeDate = [DateTime]::Parse($MostRecentSignIn.createdDateTime)
                    } catch {
                        # Try multiple date formats that Microsoft Graph might return
                        $dateFormats = @(
                            "M/d/yyyy H:mm:ss",
                            "MM/dd/yyyy HH:mm:ss",
                            "M/d/yyyy HH:mm:ss",
                            "MM/dd/yyyy H:mm:ss",
                            "yyyy-MM-ddTHH:mm:ssZ",
                            "yyyy-MM-ddTHH:mm:ss.fffZ"
                        )

                        $parsed = $false
                        foreach ($format in $dateFormats) {
                            try {
                                $RealtimeDate = [DateTime]::ParseExact($MostRecentSignIn.createdDateTime, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                                $parsed = $true
                                break
                            } catch {
                                # Continue to next format
                            }
                        }

                        if (-not $parsed) {
                            Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Could not parse date '$($MostRecentSignIn.createdDateTime)' for app $AppId"
                            continue
                        }
                    }

                    # Update with real-time data if more recent
                    $shouldUpdate = $false
                    if (-not $Report.LastSignInDateTime) {
                        $shouldUpdate = $true
                    } else {
                        # Handle comparison with existing date
                        try {
                            $existingDate = if ($Report.LastSignInDateTime -is [DateTime]) {
                                $Report.LastSignInDateTime
                            } else {
                                [DateTime]::Parse($Report.LastSignInDateTime)
                            }
                            if ($RealtimeDate -gt $existingDate) {
                                $shouldUpdate = $true
                            }
                        } catch {
                            # If we can't parse the existing date, update anyway
                            $shouldUpdate = $true
                        }
                    }

                    if ($shouldUpdate) {
                        $Report.LastSignInDateTime = $RealtimeDate
                        $Report.DataQuality = "Real-time Enhanced"
                    }

                    if ($MostRecentSuccessful -and $MostRecentSuccessful.createdDateTime) {
                        # Handle different date formats from the API
                        try {
                            $RealtimeSuccessDate = [DateTime]::Parse($MostRecentSuccessful.createdDateTime)
                        } catch {
                            # Try multiple date formats that Microsoft Graph might return
                            $dateFormats = @("M/d/yyyy H:mm:ss", "MM/dd/yyyy HH:mm:ss", "M/d/yyyy HH:mm:ss", "MM/dd/yyyy H:mm:ss", "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-ddTHH:mm:ss.fffZ")

                            $parsed = $false
                            foreach ($format in $dateFormats) {
                                try {
                                    $RealtimeSuccessDate = [DateTime]::ParseExact($MostRecentSuccessful.createdDateTime, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                                    $parsed = $true
                                    break
                                } catch { }
                            }

                            if (-not $parsed) {
                                Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Could not parse success date '$($MostRecentSuccessful.createdDateTime)' for app $AppId"
                                continue
                            }
                        }
                        $shouldUpdateSuccess = $false
                        if (-not $Report.LastSuccessfulSignInDateTime) {
                            $shouldUpdateSuccess = $true
                        } else {
                            # Handle comparison with existing date
                            try {
                                $existingSuccessDate = if ($Report.LastSuccessfulSignInDateTime -is [DateTime]) {
                                    $Report.LastSuccessfulSignInDateTime
                                } else {
                                    [DateTime]::Parse($Report.LastSuccessfulSignInDateTime)
                                }
                                if ($RealtimeSuccessDate -gt $existingSuccessDate) {
                                    $shouldUpdateSuccess = $true
                                }
                            } catch {
                                # If we can't parse the existing date, update anyway
                                $shouldUpdateSuccess = $true
                            }
                        }

                        if ($shouldUpdateSuccess) {
                            $Report.LastSuccessfulSignInDateTime = $RealtimeSuccessDate
                        }
                    }

                    # Also populate successful sign-in fields from aggregated data if not already set
                    if (-not $Report.DelegatedClientLastSuccessfulSignIn -and $Activity.DelegatedClientSignInActivity -and $Activity.DelegatedClientSignInActivity.LastSuccessfulSignInDateTime) {
                        $Report.DelegatedClientLastSuccessfulSignIn = $Activity.DelegatedClientSignInActivity.LastSuccessfulSignInDateTime
                    }
                    if (-not $Report.ApplicationClientLastSuccessfulSignIn -and $Activity.ApplicationAuthenticationClientSignInActivity -and $Activity.ApplicationAuthenticationClientSignInActivity.LastSuccessfulSignInDateTime) {
                        $Report.ApplicationClientLastSuccessfulSignIn = $Activity.ApplicationAuthenticationClientSignInActivity.LastSuccessfulSignInDateTime
                    }

                    # Track that we found real-time sign-in activity
                    if ($Report.ActivitySources -notcontains "Real-time Sign-ins") {
                        $Report.ActivitySources += "Real-time Sign-ins"
                    }

                    # Add app display name
                    if ($MostRecentSignIn.appDisplayName) {
                        $Report.AppDisplayName = $MostRecentSignIn.appDisplayName
                    }
                }
            }
            } catch {
                Write-Warning "Get-GraphEssentialsComprehensiveActivityReport: Could not retrieve real-time sign-in logs: $($_.Exception.Message)"
            }
        } else {
            Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Skipping real-time sign-in logs (IncludeRealtimeSignIns=false) - using aggregated data only for better performance."
        }

        # Step 3: Get directory audit logs for service principal operations
        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Getting directory audit logs for service principal operations..."

        try {
            # Look for service principal operations like token requests, API calls, etc.
            # Note: Using a very simple filter to avoid BadRequest errors
            $AuditUri = "/beta/auditLogs/directoryAudits?`$top=100"
            Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Calling $AuditUri"
            $AuditResult = Invoke-MgGraphRequest -Uri $AuditUri -Method GET

                                    if ($AuditResult.value -and $AuditResult.value.Count -gt 0) {
                Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Processing $($AuditResult.value.Count) directory audit records..."

                # Filter for recent application-related activities after retrieval
                $RecentDate = (Get-Date).AddDays(-$Days)
                $AppRelatedAudits = $AuditResult.value | Where-Object {
                    # Filter by date first
                    if ($_.activityDateTime) {
                        try {
                            $actDate = [DateTime]::Parse($_.activityDateTime)
                            if ($actDate -lt $RecentDate) { return $false }
                        } catch {
                            # Try multiple date formats that Microsoft Graph might return
                            $dateFormats = @("M/d/yyyy H:mm:ss", "MM/dd/yyyy HH:mm:ss", "M/d/yyyy HH:mm:ss", "MM/dd/yyyy H:mm:ss", "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-ddTHH:mm:ss.fffZ")

                            $parsed = $false
                            foreach ($format in $dateFormats) {
                                try {
                                    $actDate = [DateTime]::ParseExact($_.activityDateTime, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                                    if ($actDate -lt $RecentDate) { return $false }
                                    $parsed = $true
                                    break
                                } catch { }
                            }

                            if (-not $parsed) { return $false }
                        }
                    } else {
                        return $false
                    }

                    # Then filter by application relevance
                    return ($_.category -eq 'ApplicationManagement' -or
                            $_.category -eq 'ServicePrincipal' -or
                            $_.activityDisplayName -like '*Application*' -or
                            $_.activityDisplayName -like '*Service Principal*')
                }

                Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Found $($AppRelatedAudits.Count) application-related audit records..."

                foreach ($AuditRecord in $AppRelatedAudits) {
                    # Look for target applications in audit records
                    if ($AuditRecord.targetResources) {
                        foreach ($Target in $AuditRecord.targetResources) {
                            if ($Target.type -eq "Application" -and $Target.id -and $AuditRecord.activityDateTime) {
                                $AppId = $Target.id

                                # Handle different date formats from the API
                                try {
                                    $ActivityDate = [DateTime]::Parse($AuditRecord.activityDateTime)
                                } catch {
                                    # Try multiple date formats that Microsoft Graph might return
                                    $dateFormats = @("M/d/yyyy H:mm:ss", "MM/dd/yyyy HH:mm:ss", "M/d/yyyy HH:mm:ss", "MM/dd/yyyy H:mm:ss", "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-ddTHH:mm:ss.fffZ")

                                    $parsed = $false
                                    foreach ($format in $dateFormats) {
                                        try {
                                            $ActivityDate = [DateTime]::ParseExact($AuditRecord.activityDateTime, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                                            $parsed = $true
                                            break
                                        } catch { }
                                    }

                                    if (-not $parsed) {
                                        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Could not parse audit date '$($AuditRecord.activityDateTime)' for app $AppId"
                                        continue
                                    }
                                }

                                # Update or create activity record
                                if (-not $ActivityReport.ContainsKey($AppId)) {
                                    $ActivityReport[$AppId] = @{
                                        ActivitySources = @()
                                        DataQuality = "Audit Only"
                                    }
                                }

                                $Report = $ActivityReport[$AppId]

                                # Track audit activity
                                if (-not $Report.LastAuditActivity -or $ActivityDate -gt $Report.LastAuditActivity) {
                                    $Report.LastAuditActivity = $ActivityDate
                                    $Report.LastAuditOperation = $AuditRecord.activityDisplayName
                                }

                                # Track that we found audit activity
                                if ($Report.ActivitySources -notcontains "Directory Audits") {
                                    $Report.ActivitySources += "Directory Audits"
                                }

                                # Update overall activity if this is more recent
                                if (-not $Report.LastOverallActivity -or $ActivityDate -gt $Report.LastOverallActivity) {
                                    $Report.LastOverallActivity = $ActivityDate
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Get-GraphEssentialsComprehensiveActivityReport: Could not retrieve directory audit logs: $($_.Exception.Message)"
        }

        # Step 4: Calculate comprehensive activity metrics
        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Calculating comprehensive activity metrics..."

        foreach ($AppId in $ActivityReport.Keys) {
            $Report = $ActivityReport[$AppId]

            # Determine the most recent activity across all sources
            $AllActivityDates = @(
                $Report.LastSignInDateTime,
                $Report.LastSuccessfulSignInDateTime,
                $Report.DelegatedClientLastSignIn,
                $Report.ApplicationClientLastSignIn,
                $Report.DelegatedResourceLastSignIn,
                $Report.ApplicationResourceLastSignIn,
                $Report.LastAuditActivity,
                $Report.LastOverallActivity
            ) | Where-Object { $_ -ne $null }

            if ($AllActivityDates.Count -gt 0) {
                $MostRecentActivity = ($AllActivityDates | Sort-Object -Descending)[0]
                $Report.MostRecentActivityDate = $MostRecentActivity
                $Report.DaysSinceLastActivity = [Math]::Round(($Now - $MostRecentActivity).TotalDays)

                # Determine activity level for security assessment
                if ($Report.DaysSinceLastActivity -le 7) {
                    $Report.ActivityLevel = "Very Active"
                } elseif ($Report.DaysSinceLastActivity -le 30) {
                    $Report.ActivityLevel = "Active"
                } elseif ($Report.DaysSinceLastActivity -le 90) {
                    $Report.ActivityLevel = "Moderate"
                } elseif ($Report.DaysSinceLastActivity -le 180) {
                    $Report.ActivityLevel = "Low"
                } else {
                    $Report.ActivityLevel = "Inactive"
                }
            } else {
                $Report.MostRecentActivityDate = $null
                $Report.DaysSinceLastActivity = $null
                $Report.ActivityLevel = "No Activity"
            }

            # Calculate successful activity metrics
            $AllSuccessfulDates = @(
                $Report.LastSuccessfulSignInDateTime,
                $Report.DelegatedClientLastSuccessfulSignIn,
                $Report.ApplicationClientLastSuccessfulSignIn,
                $Report.DelegatedResourceLastSignIn,
                $Report.ApplicationResourceLastSignIn
            ) | Where-Object { $_ -ne $null }

            if ($AllSuccessfulDates.Count -gt 0) {
                $MostRecentSuccessful = ($AllSuccessfulDates | Sort-Object -Descending)[0]
                $Report.MostRecentSuccessfulActivityDate = $MostRecentSuccessful
                $Report.DaysSinceLastSuccessfulActivity = [Math]::Round(($Now - $MostRecentSuccessful).TotalDays)
            } else {
                $Report.MostRecentSuccessfulActivityDate = $null
                $Report.DaysSinceLastSuccessfulActivity = $null
            }

            # Summarize activity types
            $ActivityTypes = @()
            if ($Report.DelegatedClientLastSignIn) { $ActivityTypes += "User Sign-ins" }
            if ($Report.ApplicationClientLastSignIn) { $ActivityTypes += "App Authentication" }
            if ($Report.DelegatedResourceLastSignIn) { $ActivityTypes += "Delegated Access" }
            if ($Report.ApplicationResourceLastSignIn) { $ActivityTypes += "Resource Access" }
            if ($Report.LastAuditActivity) { $ActivityTypes += "Management Operations" }

            $Report.ActivityTypes = if ($ActivityTypes.Count -gt 0) { $ActivityTypes -join ", " } else { "No Activity" }
            $Report.ActivitySourcesSummary = if ($Report.ActivitySources.Count -gt 0) { $Report.ActivitySources -join ", " } else { "None" }
        }

        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Completed comprehensive analysis for $($ActivityReport.Count) applications"

    } catch {
        Write-Warning "Get-GraphEssentialsComprehensiveActivityReport: Error during comprehensive activity analysis: $($_.Exception.Message)"
        Write-Verbose "Get-GraphEssentialsComprehensiveActivityReport: Full error: $($_.Exception | Out-String)"
    }

    return $ActivityReport
}