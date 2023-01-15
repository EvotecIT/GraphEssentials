function Get-MgToken {
    [CmdletBinding()]
    param(
        [alias('ApplicationID')][string] $ClientID,
        [string] $ClientSecret,
        [string] $TenantID
    )
    $Body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientID
        Client_Secret = $ClientSecret
    }
    $connection = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token" -Method POST -Body $Body
    $connection.access_token
}