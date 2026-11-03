---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyRoleHistory
## SYNOPSIS
Retrieves Azure AD/Entra ID Privileged Identity Management (PIM) role assignment history.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyRoleHistory [[-RoleId] <string>] [[-RoleName] <string>] [[-PrincipalId] <string>] [[-UserPrincipalName] <string>] [[-DaysBack] <int>] [-IncludeAllStatuses] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about PIM role assignment requests and their history, including activations,
deactivations, assignments, and removals. Translates all IDs to readable names and provides
comprehensive information about each PIM event.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyRoleHistory
Returns PIM role assignment history for the last 30 days.
```


### EXAMPLE 2
```powershell
PS > Get-MyRoleHistory -RoleId "b0f54661-2d74-4c50-afa3-1ec803f12efe"
Returns PIM history for a specific role ID.
```


### EXAMPLE 3
```powershell
PS > Get-MyRoleHistory -RoleName "Global Administrator"
Returns PIM history for the Global Administrator role.
```


### EXAMPLE 4
```powershell
PS > Get-MyRoleHistory -UserPrincipalName "john.doe@company.com"
Returns PIM history for a specific user.
```


### EXAMPLE 5
```powershell
PS > Get-MyRoleHistory -RoleName "*Admin*" -DaysBack 90
Returns PIM history for all admin roles in the last 90 days.
```


### EXAMPLE 6
```powershell
PS > Get-MyRoleHistory -IncludeAllStatuses
Returns all PIM requests including pending and failed ones.
```


## PARAMETERS

### -DaysBack
Optional. Number of days to look back for history. Defaults to 30 days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAllStatuses
When specified, includes all statuses including pending and failed requests.
By default, only shows completed requests.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PrincipalId
Optional. Filter results to show history for a specific user, group, or service principal ID.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RoleId
Optional. Filter results to show history for a specific role definition ID.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RoleName
Optional. Filter results to show history for a specific role name (supports wildcards).

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserPrincipalName
Optional. Filter results to show history for a specific user principal name (supports wildcards).

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
