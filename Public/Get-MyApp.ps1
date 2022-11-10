function Get-MyApp {
    [cmdletBinding()]
    param(

    )
    $Application = Get-MgApplication -ConsistencyLevel eventual
    $Applications = foreach ($App in $Application) {
        [Array] $DatesSorted = $App.PasswordCredentials.StartDateTime | Sort-Object

        # Lets translate credentials to different format
        $AppCredentials = Get-MyAppCredentials -Application $App

        # Lets find if description has email
        $DescriptionWithEmail = $false
        foreach ($CredentialName in  $AppCredentials.ClientSecretName) {
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

        [PSCustomObject] @{
            ObjectId             = $App.Id
            ClientID             = $App.AppId
            ApplicationName      = $App.DisplayName
            CreatedDate          = $App.CreatedDateTime
            KeysCount            = $App.PasswordCredentials.Count
            KeysExpired          = $Expired
            DaysToExpireOldest   = $DaysToExpireOldest
            DaysToExpireNewest   = $DaysToExpireNewest
            KeysDateOldest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[0] } else { }
            KeysDateNewest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[-1] } else { }
            KeysDescription      = $AppCredentials.ClientSecretName
            DescriptionWithEmail = $DescriptionWithEmail
        }
    }
    $Applications
}