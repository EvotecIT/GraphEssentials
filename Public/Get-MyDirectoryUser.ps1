function Get-MyDirectoryUser {
    <#
    .SYNOPSIS
    Retrieves selected directory user data, extensions and optional manager details through the Graph SDK.
    .DESCRIPTION
    Returns plain records for automation without license, role or report enrichment. Reads every list page
    before emitting records, so a failed page cannot yield an apparently complete inventory. Id is always
    selected. Custom directory extension properties are lifted from the SDK's AdditionalProperties.
    extensionAttribute1 through extensionAttribute15 select and flatten the corresponding on-premises
    extension attribute; explicitly requesting OnPremisesExtensionAttributes preserves that nested value.
    .PARAMETER UserId
    A user object ID or user principal name for a single-user lookup.
    .PARAMETER Property
    Fields to return. Defaults to Id, DisplayName, UserPrincipalName, Mail, AccountEnabled and UserType.
    Id is included even when omitted. Selecting Manager also enables manager expansion.
    .PARAMETER Filter
    OData filter forwarded to the SDK list query. Construct literal values with OData quote escaping.
    .PARAMETER Sort
    OData ordering forwarded to Get-MgUser.
    .PARAMETER IncludeManager
    Includes a nested Manager record with identity, name, UPN, mail and synchronization state, or null.
    Manager expansion cannot be combined with advanced count/eventual-consistency queries.
    .PARAMETER CountVariable
    SDK variable name receiving the matching collection count in global scope. Enables eventual
    consistency. The count describes all matching users, not just a projection or a partial page.
    .PARAMETER ConsistencyLevel
    Eventual consistency for an advanced list query. Graph may also require CountVariable for the filter.
    .PARAMETER MinimumCount
    Minimum number of users required in a complete list response. Defaults to 0. An undersized response
    terminates before any records are emitted. The caller chooses the threshold for its selected filter.
    This counts returned users, before caller-specific indexing or validation of mail and employee IDs.
    .EXAMPLE
    $users = Get-MyDirectoryUser -Filter "userType eq 'Guest'" -Property Id, Mail, EmployeeId, extensionAttribute1 -IncludeManager
    Reads guest identifiers, selected attributes and manager data without report dependencies being queried.
    .EXAMPLE
    Get-MyDirectoryUser -UserId $userId -Property DisplayName, AccountEnabled, extension_appid_CostCenter
    Reads one user and a custom directory extension field.
    .EXAMPLE
    $users = Get-MyDirectoryUser -Filter "startsWith(displayName,'A')" -CountVariable matchingUsers -ConsistencyLevel eventual
    Reads all matching users; the SDK sets the global matchingUsers count.
    .EXAMPLE
    $users = Get-MyDirectoryUser -Filter "userType eq 'Guest'" -Property Id, Mail -MinimumCount 100
    Stops without returning an inventory if fewer than 100 guests are returned.
    .OUTPUTS
    System.Management.Automation.PSCustomObject. Selected directory fields and optional nested Manager.
    .NOTES
    Connect-MgGraph first with permission to read the requested user data. Uses Microsoft Graph v1.0
    through the existing Microsoft.Graph.Users dependency. Errors terminate rather than dropping fields
    or silently returning incomplete data. Get-MyUser remains the enriched reporting command.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'User')]
        [ValidateNotNullOrEmpty()][string] $UserId,
        [ValidateNotNullOrEmpty()][string[]] $Property = @('Id', 'DisplayName', 'UserPrincipalName', 'Mail', 'AccountEnabled', 'UserType'),
        [Parameter(ParameterSetName = 'List')][string] $Filter,
        [Parameter(ParameterSetName = 'List')][string[]] $Sort,
        [switch] $IncludeManager,
        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')][string] $CountVariable,
        [Parameter(ParameterSetName = 'List')][ValidateSet('eventual')][string] $ConsistencyLevel,
        [Parameter(ParameterSetName = 'List')][ValidateRange(0, 2147483647)][int] $MinimumCount = 0
    )

    $fields = [System.Collections.Generic.List[string]]::new()
    $selection = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $withManager = $IncludeManager -or $Property -contains 'Manager'
    foreach ($name in @('Id') + $Property) {
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Unsupported directory property name: $name"
        }
        if (-not $fields.Contains($name)) {
            $fields.Add($name)
        }
        if ($name -ieq 'Manager') {
            continue
        }
        if ($name -match '^extensionAttribute(?:[1-9]|1[0-5])$') {
            $null = $selection.Add('OnPremisesExtensionAttributes')
        } else {
            $null = $selection.Add($name)
        }
    }
    if ($withManager -and ($CountVariable -or $ConsistencyLevel)) {
        throw 'Graph does not support manager expansion with advanced count/eventual-consistency queries. Read manager data separately.'
    }
    $query = @{
        Property = [string[]] $selection
    }
    if ($PSCmdlet.ParameterSetName -eq 'User') {
        $query.UserId = $UserId
    } else {
        $query.All = $true
        if ($Filter) {
            $query.Filter = $Filter
        }
        if ($Sort) {
            $query.Sort = $Sort
        }
        if ($CountVariable) {
            $query.CountVariable = $CountVariable
            $query.ConsistencyLevel = 'eventual'
        } elseif ($ConsistencyLevel) {
            $query.ConsistencyLevel = $ConsistencyLevel
        }
    }
    if ($withManager) {
        $query.ExpandProperty = 'manager($select=id,displayName,userPrincipalName,mail,onPremisesSyncEnabled)'
    }
    $users = @(Get-MgUser @query -ErrorAction Stop)
    if ($users.Count -lt $MinimumCount) {
        throw "Graph returned $($users.Count) users, fewer than MinimumCount $MinimumCount. No inventory was returned."
    }
    foreach ($user in $users) {
        ConvertTo-GraphEssentialsDirectoryUser -User $user -Property $fields.ToArray() -IncludeManager:$withManager
    }
}
