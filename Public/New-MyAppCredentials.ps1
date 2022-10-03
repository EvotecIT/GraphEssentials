function New-MyAppCredentials {
    [cmdletbinding(DefaultParameterSetName = 'AppName')]
    param(
        [parameter(Mandatory, ParameterSetName = 'AppId')][string] $ObjectID,
        [parameter(Mandatory, ParameterSetName = 'AppName')][string] $AppName,
        [string] $DisplayName,
        [int] $MonthsValid = 12
    )

    if ($AppName) {
        $Application = Get-MgApplication -Filter "DisplayName eq '$AppName'" -ConsistencyLevel eventual
        if ($Application) {
            $ID = $Application.Id
        } else {
            Write-Warning -Message "Application with name '$AppName' not found"
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

    Add-MgApplicationPassword -ApplicationId $ID -PasswordCredential $PasswordCredential
}