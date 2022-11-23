function New-MyAppCredentials {
    [cmdletbinding(DefaultParameterSetName = 'AppName')]
    param(
        [parameter(Mandatory, ParameterSetName = 'AppId')][string] $ObjectID,
        [alias('AppName')] [parameter(Mandatory, ParameterSetName = 'AppName')][string] $ApplicationName,
        [string] $DisplayName,
        [int] $MonthsValid = 12
    )

    if ($AppName) {
        $Application = Get-MgApplication -Filter "DisplayName eq '$ApplicationName'" -ConsistencyLevel eventual -All
        if ($Application) {
            $ID = $Application.Id
        } else {
            Write-Warning -Message "Application with name '$ApplicationName' not found"
            return
        }
    } else {
        $ID = $ObjectID
    }

    $PasswordCredential = [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphPasswordCredential] @{
        StartDateTime = [datetime]::Now
    }
    if ($DisplayName) {
        $PasswordCredential.DisplayName = $DisplayName
    }
    $PasswordCredential.EndDateTime = [datetime]::Now.AddMonths($MonthsValid)
    try {
        Add-MgApplicationPassword -ApplicationId $ID -PasswordCredential $PasswordCredential -ErrorAction Stop
    } catch {
        Write-Warning -Message "Failed to add password credential to application $ID / $ApplicationName. Error: $($_.Exception.Message)"
    }
}