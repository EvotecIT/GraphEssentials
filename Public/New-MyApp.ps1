function New-MyApp {
    [cmdletBinding()]
    param(
        [parameter(Mandatory)][string] $ApplicationName,
        [parameter(Mandatory)][string] $DisplayNameCredentials,
        [int] $MonthsValid = 12
    )
    $Application = Get-MgApplication -Filter "displayName eq '$ApplicationName'"
    if (-not $Application) {
        Write-Verbose -Message "New-MyApp - Creating application $ApplicationName"
        $Application = New-MgApplication -DisplayName $ApplicationName
    } else {
        Write-Verbose -Message "New-MyApp - Application $ApplicationName already exists. Reusing..."
    }
    $Credentials = New-MyAppCredentials -ObjectID $Application.Id -DisplayName $DisplayNameCredentials -MonthsValid $MonthsValid
    if ($Application -and $Credentials) {
        [PSCustomObject] @{
            ApplicationID          = $Application.Id
            ApplicationName        = $Application.DisplayName
            DisplayNameCredentials = $Credentials.DisplayName
            DaysToExpire           = ($Credentials.EndDateTime - [DateTime]::Now).Days
            StartDateTime          = $Credentials.StartDateTime
            EndDateTime            = $Credentials.EndDateTime
            KeyID                  = $Credentials.KeyID
            SecretKey              = $Credentials.SecretText
        }
    } else {
        Write-Warning -Message "New-MyApp - Application or credentials for $ApplicationName was not created."
    }
}