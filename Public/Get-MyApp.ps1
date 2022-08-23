function Get-MyApp {
    [cmdletBinding()]
    param(

    )
    $Application = Get-MgApplication

    $Applications = foreach ($App in $Application) {
        [PSCustomObject] @{
            Id             = $App.Id
            AppId          = $App.AppId
            AppName        = $App.DisplayName
            CreatedDate    = $App.CreatedDateTime
            Web            = $App.Web.RedirectUris
            KeysCount      = $App.PasswordCredentials.Count
            SignInAudience = $App.SignInAudience
        }
    }
    $Applications
}