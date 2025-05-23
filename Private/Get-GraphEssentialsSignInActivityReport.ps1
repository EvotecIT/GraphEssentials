function Get-GraphEssentialsSignInActivityReport {
    param()
    Write-Verbose "Get-GraphEssentialsSignInActivityReport: Fetching Service Principal Sign-in Activity (Beta)..."
    # Note: Requires AuditLog.Read.All
    $SignInActivityReport = @{}
    try {
        # Consider adding paging logic if needed for very large tenants using Invoke-MgGraphRequestAll
        $activity = Invoke-MgGraphRequest -Uri "/beta/reports/servicePrincipalSignInActivities?`$top=999" -ErrorAction Stop
        if ($activity -and $activity.value) {
             $activity.value | ForEach-Object { $SignInActivityReport[$_.appId] = $_ }
             Write-Verbose "Get-GraphEssentialsSignInActivityReport: Fetched sign-in activity for $($SignInActivityReport.Count) apps."
        } else {
            Write-Verbose "Get-GraphEssentialsSignInActivityReport: No sign-in activity data returned."
        }
    } catch {
        Write-Warning "Get-GraphEssentialsSignInActivityReport: Failed to retrieve Service Principal Sign-in Activity. Last sign-in dates will be unavailable. Error: $($_.Exception.Message)"
    }
    return $SignInActivityReport
}