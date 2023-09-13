function Get-MyApp {
    [cmdletBinding()]
    param(
        [string] $ApplicationName,
        [switch] $IncludeCredentials
    )
    if ($ApplicationName) {
        $Application = Get-MgApplication -Filter "displayName eq '$ApplicationName'" -All -ConsistencyLevel eventual -Property Owners
    } else {
        $Application = Get-MgApplication -ConsistencyLevel eventual -All
    }
    $Applications = foreach ($App in $Application) {
        # Lets translate credentials to different format
        [Array] $AppCredentials = Get-MyAppCredentials -ApplicationList $App

        $Owners = Get-MgApplicationOwner -ApplicationId $App.Id -ConsistencyLevel eventual

        [Array] $DatesSorted = $AppCredentials.StartDateTime | Sort-Object

        # Lets find if description has email
        $DescriptionWithEmail = $false
        foreach ($CredentialName in $AppCredentials.KeyDisplayName) {
            if ($CredentialName -like '*@*') {
                $DescriptionWithEmail = $true
                break
            }
        }
        $DaysToExpireOldest = $AppCredentials.DaysToExpire | Sort-Object -Descending | Select-Object -Last 1
        $DaysToExpireNewest = $AppCredentials.DaysToExpire | Sort-Object -Descending | Select-Object -First 1

        if ($AppCredentials.Expired -contains $false) {
            $Expired = 'No'
        } elseif ($AppCredentials.Expired -contains $true) {
            $Expired = 'Yes'
        } else {
            $Expired = 'Not available'
        }

        $AppInformation = [ordered] @{
            ObjectId             = $App.Id
            ClientID             = $App.AppId
            ApplicationName      = $App.DisplayName
            OwnerDisplayName     = $Owners.AdditionalProperties.displayName
            OwnerUserPrincipal   = $Owners.AdditionalProperties.userPrincipalName
            OwnerMail            = $Owners.AdditionalProperties.mail
            CreatedDate          = $App.CreatedDateTime
            KeysCount            = $AppCredentials.Count
            KeysTypes            = $AppCredentials.Type
            KeysExpired          = $Expired
            DaysToExpireOldest   = $DaysToExpireOldest
            DaysToExpireNewest   = $DaysToExpireNewest
            KeysDateOldest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[0] } else { }
            KeysDateNewest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[-1] } else { }
            KeysDescription      = $AppCredentials.KeyDisplayName
            DescriptionWithEmail = $DescriptionWithEmail
            Notes                = $App.Notes
        }
        if ($IncludeCredentials) {
            $AppInformation['Keys'] = $AppCredentials
        }
        [PSCustomObject] $AppInformation
    }
    $Applications
}