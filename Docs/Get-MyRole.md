---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyRole
## SYNOPSIS
Retrieves Azure AD directory roles and their assignments.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyRole [-OnlyWithMembers] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about Azure AD/Entra ID directory roles, including role assignments
for users, groups, and service principals. Categorizes assignments as direct or eligible
and provides statistics about the number of members in each role.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyRole
Returns all Azure AD directory roles along with member information.
```


### EXAMPLE 2
```powershell
PS > Get-MyRole -OnlyWithMembers
Returns only Azure AD directory roles that have at least one member assigned.
```


## PARAMETERS

### -OnlyWithMembers
When specified, returns only roles that have at least one member (direct or eligible).

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
