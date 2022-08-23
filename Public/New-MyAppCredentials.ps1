function New-MyAppCredentials {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)][string] $ObjectID,
        [string] $DisplayName,
        [int] $MonthsValid = 6
    )

    $PasswordCredential = [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphPasswordCredential] @{
        StartDateTime = [datetime]::Now
    }
    if ($DisplayName) {
        $PasswordCredential.DisplayName = $DisplayName
    }
    $PasswordCredential.EndDateTime = [datetime]::Now.AddMonths($MonthsValid)

    Add-MgApplicationPassword -ApplicationId $ObjectID -PasswordCredential $PasswordCredential
}