function New-MyAppCredentials {
    <#
    .SYNOPSIS
    Creates new credentials for an existing Azure AD application.

    .DESCRIPTION
    Adds new client secret credentials to an existing Azure AD/Entra application with specified validity period.
    This is useful for rotating credentials or adding additional secrets to applications.

    .PARAMETER ObjectID
    The object ID of the application to add credentials to.

    .PARAMETER DisplayName
    The display name or description for the credentials being added.

    .PARAMETER MonthsValid
    Number of months the credentials should be valid for. Defaults to 12 months.

    .EXAMPLE
    New-MyAppCredentials -ObjectID "11111111-1111-1111-1111-111111111111" -DisplayName "API Access"
    Creates new credentials for the application with the specified object ID, valid for 12 months.

    .EXAMPLE
    New-MyAppCredentials -ObjectID "11111111-1111-1111-1111-111111111111" -DisplayName "Temporary Access" -MonthsValid 3
    Creates new credentials valid for 3 months with the display name "Temporary Access".

    .NOTES
    This function requires the Microsoft.Graph.Applications module and appropriate permissions.
    Requires Application.ReadWrite.All permissions to manage application credentials.
    #>
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