---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyRoleUsers
## SYNOPSIS
Retrieves detailed information about users assigned to Azure AD roles.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyRoleUsers [-OnlyWithRoles] [-RolePerColumn] [<CommonParameters>]
```

## DESCRIPTION
Gets comprehensive information about Azure AD/Entra ID role assignments and eligible assignments,
including direct assignments and assignments through groups. The data can be presented in different formats
to facilitate analysis of role assignments across your tenant.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyRoleUsers
Returns all users with their role assignments in the default format.
```


### EXAMPLE 2
```powershell
PS > Get-MyRoleUsers -OnlyWithRoles
Returns only users who have at least one role assignment.
```


### EXAMPLE 3
```powershell
PS > Get-MyRoleUsers -RolePerColumn
Returns users with their role assignments in a matrix format with roles as columns.
```


## PARAMETERS

### -OnlyWithRoles
When specified, returns only users who have at least one role assignment.

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

### -RolePerColumn
When specified, changes the output format to have each role as a column instead of as rows.
This creates a matrix view with users on rows and roles on columns.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
