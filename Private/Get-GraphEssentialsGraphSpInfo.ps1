function Get-GraphEssentialsGraphSpInfo {
    param()
    Write-Verbose "Get-GraphEssentialsGraphSpInfo: Fetching Graph Service Principal Info..."
    $graphSpInfo = $null
    try {
        $graphSp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -Property Id, AppRoles -ErrorAction Stop
        if ($graphSp) {
            $graphAppRoles = $graphSp.AppRoles | Group-Object -Property Id -AsHashTable -AsString
            $graphSpInfo = [PSCustomObject]@{
                Id = $graphSp.Id
                AppRoles = $graphAppRoles
            }
            Write-Verbose "Get-GraphEssentialsGraphSpInfo: Found Graph SP Id $($graphSpInfo.Id) and $($graphSpInfo.AppRoles.Count) App Roles."
        } else {
            Write-Warning "Get-GraphEssentialsGraphSpInfo: Microsoft Graph Service Principal (AppId 00000003-...) not found."
        }
    } catch {
         Write-Warning "Get-GraphEssentialsGraphSpInfo: Failed to get Graph Service Principal. Error: $($_.Exception.Message)"
    }
    return $graphSpInfo
}