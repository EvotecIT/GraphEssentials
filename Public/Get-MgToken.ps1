function Get-MgToken {
    <#
    .SYNOPSIS
    Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

    .DESCRIPTION
    Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

    .PARAMETER ClientID
    Provide the Application ID of the App Registration

    .PARAMETER ClientSecret
    Provide the Client Secret of the App Registration

    .PARAMETER Credential
    Provide the Client Secret of the App Registration as a PSCredential

    .PARAMETER TenantID
    Provide the Tenant ID of the App Registration

    .PARAMETER Domain
    Provide the Domain of the tenant where the App is registred

    .EXAMPLE
    Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -TenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    .EXAMPLE
    Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -Domain 'contoso.com'

    .EXAMPLE
    $ClientSecretEncrypted = 'ClientSecretToEncrypt' | ConvertTo-SecureString -AsPlainText | ConvertFrom-SecureString
    $AccessToken = Get-MgToken -Domain 'evotec.pl' -ClientID 'ClientID' -ClientSecretEncrypted $ClientSecretEncrypted
    Connect-MgGraph -AccessToken $AccessToken

    .NOTES
    General notes
    #>
    [CmdletBinding(DefaultParameterSetName = 'Domain')]
    param(
        [Parameter(ParameterSetName = 'TenantID', Mandatory)]
        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [Parameter(ParameterSetName = 'TenantIDEncrypted', Mandatory)]
        [Parameter(ParameterSetName = 'DomainEncrypted', Mandatory)]
        [alias('ApplicationID')][string] $ClientID,

        [Parameter(ParameterSetName = 'TenantID', Mandatory)]
        [Parameter(ParameterSetName = 'Domain', Mandatory)]
        [string] $ClientSecret,

        [Parameter(ParameterSetName = 'TenantIDEncrypted', Mandatory)]
        [Parameter(ParameterSetName = 'DomainEncrypted', Mandatory)]
        [string] $ClientSecretEncrypted,

        [Parameter(ParameterSetName = 'TenantIDEncrypted', Mandatory)]
        [Parameter(ParameterSetName = 'TenantID', Mandatory)][string] $TenantID,

        [Parameter(ParameterSetName = 'DomainEncrypted', Mandatory)]
        [Parameter(ParameterSetName = 'Domain', Mandatory)][string] $Domain

    )
    if ($PSBoundParameters.ContainsKey('ClientSecretEncrypted')) {
        $TemporaryKey = ConvertTo-SecureString -String $ClientSecretEncrypted -Force
        $ApplicationKey = [System.Net.NetworkCredential]::new([string]::Empty, $TemporaryKey).Password
    } else {
        $ApplicationKey = $ClientSecret
    }
    $Body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientID
        Client_Secret = $ApplicationKey
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