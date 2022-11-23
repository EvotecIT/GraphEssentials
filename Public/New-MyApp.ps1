function New-MyApp {
    [cmdletBinding()]
    param(
        [parameter(Mandatory)][alias('AppName', 'DisplayName')][string] $ApplicationName,
        [parameter(Mandatory)][alias('DescriptionCredentials')][string] $DisplayNameCredentials,
        [string] $Description,
        [int] $MonthsValid = 12,
        [switch] $RemoveOldCredentials,
        [switch] $ServicePrincipal
    )
    $Application = Get-MgApplication -Filter "displayName eq '$ApplicationName'" -All -ErrorAction Stop
    if (-not $Application) {
        Write-Verbose -Message "New-MyApp - Creating application $ApplicationName"
        $newMgApplicationSplat = @{
            DisplayName = $ApplicationName
            Description = $Description
        }
        Remove-EmptyValue -Hashtable $newMgApplicationSplat
        $Application = New-MgApplication @newMgApplicationSplat -ErrorAction Stop
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
    if ($ServicePrincipal) {
        $ServicePrincipalApp = Get-MgServicePrincipal -Filter "appId eq '$($Application.AppId)'" -All -ConsistencyLevel eventual -ErrorAction Stop
        if (-not $ServicePrincipalApp) {
            Write-Verbose -Message "New-MyApp - Creating service principal for $ApplicationName"
            try {
                $null = New-MgServicePrincipal -AppId $Application.AppId -AccountEnabled:$true -ErrorAction Stop
            } catch {
                Write-Warning -Message "New-MyApp - Failed to create service principal for $ApplicationName. Error: $($_.Exception.Message)"
            }
        } else {
            Write-Verbose -Message "New-MyApp - Service principal for $ApplicationName already exists. Skipping..."
        }
    }
}