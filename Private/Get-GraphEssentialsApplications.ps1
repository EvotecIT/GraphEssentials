function Get-GraphEssentialsApplications {
    param(
        [string]$ApplicationName # Optional name to filter by
    )

    Write-Verbose "Get-GraphEssentialsApplications: Fetching Applications..."
    $appFilter = ""
    $ApplicationsRaw = [System.Collections.Generic.List[object]]::new()
    # Define properties needed for Application object + Credentials processing
    $appProperties = @('Id', 'AppId', 'DisplayName', 'CreatedDateTime', 'Notes', 'PasswordCredentials', 'KeyCredentials')
    $selectClause = "`$select=$(($appProperties -join ',' ))"

    try {
        if ($ApplicationName) {
            $escapedAppName = $ApplicationName.Replace("'", "''")
            $appFilter = "displayName eq '$escapedAppName'"
            Write-Verbose "Get-GraphEssentialsApplications: Filtering for ApplicationName: $ApplicationName"
            $uri = "/v1.0/applications?`$filter=$appFilter&$selectClause"
        } else {
            Write-Verbose "Get-GraphEssentialsApplications: Fetching all applications."
            $uri = "/v1.0/applications?$selectClause"
        }

        # Manual Paging for Applications
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        if ($response -and $response.value) { $ApplicationsRaw.AddRange($response.value) }
        $NextLink = $response.'@odata.nextLink'

        while ($NextLink -ne $null) {
            Write-Verbose "Get-GraphEssentialsApplications: Fetching next page for applications..."
            $response = Invoke-MgGraphRequest -Uri $NextLink -Method GET -ErrorAction Stop
            if ($response -and $response.value) { $ApplicationsRaw.AddRange($response.value) }
            $NextLink = $response.'@odata.nextLink'
        }
        Write-Verbose "Get-GraphEssentialsApplications: Finished fetching $($ApplicationsRaw.Count) applications."

    } catch {
        Write-Warning "Get-GraphEssentialsApplications: Failed to retrieve applications. Error: $($_.Exception.Message)"
        # Return whatever was fetched, could be empty list
    }

    return $ApplicationsRaw
}