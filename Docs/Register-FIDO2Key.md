---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Register-FIDO2Key
## SYNOPSIS
Register-FIDO2Key [-UPN] <string> [[-DisplayName] <string>] [-PassThru] [<CommonParameters>]

## SYNTAX
### __AllParameterSets
```powershell
Register-FIDO2Key [-UPN] <string> [[-DisplayName] <string>] [-PassThru] [<CommonParameters>]
```

## DESCRIPTION
Register-FIDO2Key [-UPN] <string> [[-DisplayName] <string>] [-PassThru] [<CommonParameters>]

## EXAMPLES

### EXAMPLE 1
```powershell
Register-FIDO2Key -UPN 'Value'
```


## PARAMETERS

### -DisplayName
Specifies a value for display name.

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

### -PassThru
Specifies the pass thru switch.

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

### -UPN
Specifies a value for upn.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Object`

## RELATED LINKS

- None
