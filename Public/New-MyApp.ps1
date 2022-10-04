function New-MyApp {
    [cmdletBinding()]
    param(
        [parameter(Mandatory)][string] $ApplicationName,
        [parameter(Mandatory)][string] $DisplayNameCredentials,
        [int] $MonthsValid = 12,
        [switch] $RemoveOldCredentials
    )
    $Application = Get-MgApplication -Filter "displayName eq '$ApplicationName'"
    if (-not $Application) {
        Write-Verbose -Message "New-MyApp - Creating application $ApplicationName"
        $Application = New-MgApplication -DisplayName $ApplicationName
    } else {
        Write-Verbose -Message "New-MyApp - Application $ApplicationName already exists. Reusing..."
    }

    if ($RemoveOldCredentials -and $Application.PasswordCredentials.Count -gt 0) {
        foreach ($Credential in $Application.PasswordCredentials) {
            Write-Verbose -Message "New-MyApp - Removing old credential $($Credential.KeyId) / $($Credential.DisplayName)"
            try {
                Remove-MgApplicationPassword -ApplicationId $Application.Id -KeyId $Credential.KeyId -ErrorAction Stop
            } catch {
                Write-Warning -Message "New-MyApp - Failed to remove old credential $($Credential.KeyId) / $($Credential.DisplayName)"
                return
            }
        }
    }
    $Credentials = New-MyAppCredentials -ObjectID $Application.Id -DisplayName $DisplayNameCredentials -MonthsValid $MonthsValid
    if ($Application -and $Credentials) {
        [PSCustomObject] @{
            ObjectID         = $Application.Id
            ApplicationName  = $Application.DisplayName
            ClientID         = $Application.AppId
            ClientSecretName = $Credentials.DisplayName
            ClientSecret     = $Credentials.SecretText
            ClientSecretID   = $Credentials.KeyID
            DaysToExpire     = ($Credentials.EndDateTime - [DateTime]::Now).Days
            StartDateTime    = $Credentials.StartDateTime
            EndDateTime      = $Credentials.EndDateTime
        }
    } else {
        Write-Warning -Message "New-MyApp - Application or credentials for $ApplicationName was not created."
    }
}