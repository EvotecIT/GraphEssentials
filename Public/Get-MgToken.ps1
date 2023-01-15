function Get-MgToken {
    [CmdletBinding(DefaultParameterSetName = 'Domain')]
    param(
        [Parameter(ParameterSetName = 'TenantID', Mandatory)]
        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [alias('ApplicationID')][string] $ClientID,
        [Parameter(ParameterSetName = 'TenantID', Mandatory)]
        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [string] $ClientSecret,
        [Parameter(ParameterSetName = 'TenantID', Mandatory)][string] $TenantID,
        [Parameter(ParameterSetName = 'Domain', Mandatory)][string] $Domain
    )
    $Body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientID
        Client_Secret = $ClientSecret
    }

    if ($TenantID) {
        $Tenant = $TenantID
    } elseif ($Domain) {
        $Tenant = Get-O365TenantID -Domain $Domain
    }
    if (-not $Tenant) {
        throw "Get-MgToken - Unable to get Tenant ID"
    }
    $connection = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Method POST -Body $Body
    $connection.access_token
}