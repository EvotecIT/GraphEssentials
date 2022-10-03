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
        foreach ($CredentialName in  $AppCredentials.CredentialName) {
            if ($CredentialName -like '*@*') {
                $DescriptionWithEmail = $true
                break
            }
        }

        [PSCustomObject] @{
            Id                   = $App.Id
            ApplicationID        = $App.AppId
            ApplicationName      = $App.DisplayName
            CreatedDate          = $App.CreatedDateTime
            KeysCount            = $App.PasswordCredentials.Count
            KeysDateOldest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[0] } else { }
            KeysDateNewest       = if ($DatesSorted.Count -gt 0) { $DatesSorted[-1] } else { }
            KeysDescription      = $AppCredentials.CredentialName
            DescriptionWithEmail = $DescriptionWithEmail
            #SignInAudience       = $App.SignInAudience
            #Web                  = $App.Web.RedirectUris
        }
    }
    $Applications
}