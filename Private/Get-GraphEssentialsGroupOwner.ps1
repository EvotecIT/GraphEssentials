function Get-GraphEssentialsGroupOwner {
    <#
    .SYNOPSIS
    Retrieves every owner of a Microsoft 365 group.

    .DESCRIPTION
    Uses the Microsoft Graph beta owner relationship because the v1.0 relationship can omit
    service-principal owners during Microsoft's staged rollout. Follows every @odata.nextLink
    and returns a small, consistent owner projection for users, service principals, and other
    directory object types.

    .PARAMETER GroupId
    The Microsoft 365 group identifier. A Team uses the same identifier as its backing group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $GroupId
    )

    $EncodedGroupId = [uri]::EscapeDataString($GroupId)
    $Uri = "/beta/groups/$EncodedGroupId/owners"

    while ($Uri) {
        $Response = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject -ErrorAction Stop
        foreach ($Owner in @($Response.value)) {
            if ($null -eq $Owner) {
                continue
            }

            [PSCustomObject] @{
                DisplayName       = $Owner.displayName
                Mail              = $Owner.mail
                UserPrincipalName = $Owner.userPrincipalName
                Id                = $Owner.id
                ObjectType        = $Owner.'@odata.type'
            }
        }

        $Uri = $Response.'@odata.nextLink'
    }
}
