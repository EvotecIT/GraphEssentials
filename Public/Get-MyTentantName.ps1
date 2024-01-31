function Get-MyTenantName {
    <#
    .SYNOPSIS
    Get Tenant Name from Tenant ID or Domain Name

    .DESCRIPTION
    Get Tenant Name from Tenant ID or Domain Name

    .PARAMETER TenantID
    Provide the Tenant ID of the Tenant

    .PARAMETER DomainName
    Provide the Domain Name of the Tenant

    .EXAMPLE
    Get-MyTenantName -TenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    .EXAMPLE
    Get-MyTenantName -DomainName 'contoso.com'

    .NOTES
    General notes
    #>
    [CmdletBinding(DefaultParameterSetName = 'TenantID')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'TenantID')][string] $TenantID,
        [Parameter(Mandatory, ParameterSetName = 'DomainName')][string] $DomainName
    )

    if ($TenantID) {
        $Data = Invoke-MgRestMethod -Method GET -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByTenantId(tenantId='$TenantID')"
        $Data
    } elseif ($DomainName) {
        $Data = Invoke-MgRestMethod -Method GET -Uri "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='$DomainName')"
        $Data
    }
}