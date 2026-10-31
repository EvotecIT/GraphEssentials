---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDirectoryUser
## SYNOPSIS
Retrieves selected directory user data, extensions and optional manager details through the Graph SDK.

## SYNTAX
### List (Default)
```powershell
Get-MyDirectoryUser [-Property <string[]>] [-Filter <string>] [-Sort <string[]>] [-IncludeManager] [-CountVariable <string>] [-ConsistencyLevel <string>] [<CommonParameters>]
```

### User
```powershell
Get-MyDirectoryUser -UserId <string> [-Property <string[]>] [-IncludeManager] [<CommonParameters>]
```

## DESCRIPTION
Returns plain records for automation without license, role or report enrichment. Reads every list page
before emitting records, so a failed page cannot yield an apparently complete inventory. Id is always
selected. Custom directory extension properties are lifted from the SDK's AdditionalProperties.
extensionAttribute1 through extensionAttribute15 select and flatten the corresponding on-premises
extension attribute; explicitly requesting OnPremisesExtensionAttributes preserves that nested value.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > $users = Get-MyDirectoryUser -Filter "userType eq 'Guest'" -Property Id, Mail, EmployeeId, extensionAttribute1 -IncludeManager
Reads guest identifiers, selected attributes and manager data without report dependencies being queried.
```


### EXAMPLE 2
```powershell
PS > Get-MyDirectoryUser -UserId $userId -Property DisplayName, AccountEnabled, extension_appid_CostCenter
Reads one user and a custom directory extension field.
```


### EXAMPLE 3
```powershell
PS > $users = Get-MyDirectoryUser -Filter "startsWith(displayName,'A')" -CountVariable matchingUsers -ConsistencyLevel eventual
Reads all matching users; the SDK sets the global matchingUsers count.
```


## PARAMETERS

### -ConsistencyLevel
Eventual consistency for an advanced list query. Graph may also require CountVariable for the filter.

```yaml
Type: String
Parameter Sets: List
Aliases: None
Possible values: eventual

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CountVariable
SDK variable name receiving the matching collection count in global scope. Enables eventual
consistency. The count describes all matching users, not just a projection or a partial page.

```yaml
Type: String
Parameter Sets: List
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Filter
OData filter forwarded to the SDK list query. Construct literal values with OData quote escaping.

```yaml
Type: String
Parameter Sets: List
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeManager
Includes a nested Manager record with identity, name, UPN, mail and synchronization state, or null.
Manager expansion cannot be combined with advanced count/eventual-consistency queries.

```yaml
Type: SwitchParameter
Parameter Sets: List, User
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Property
Fields to return. Defaults to Id, DisplayName, UserPrincipalName, Mail, AccountEnabled and UserType.
Id is included even when omitted. Selecting Manager also enables manager expansion.

```yaml
Type: String[]
Parameter Sets: List, User
Aliases: None
Possible values:

Required: False
Position: named
Default value: @('Id', 'DisplayName', 'UserPrincipalName', 'Mail', 'AccountEnabled', 'UserType')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Sort
OData ordering forwarded to Get-MgUser.

```yaml
Type: String[]
Parameter Sets: List
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserId
A user object ID or user principal name for a single-user lookup.

```yaml
Type: String
Parameter Sets: User
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Management.Automation.PSCustomObject. Selected directory fields and optional nested Manager.`

## RELATED LINKS

- None
