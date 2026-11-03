---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Remove-MyAppCredentials
## SYNOPSIS
Removes credentials from an Azure AD application.

## SYNTAX
### __AllParameterSets
```powershell
Remove-MyAppCredentials [[-ApplicationName] <string>] [[-LessThanDaysToExpire] <int>] [[-GreaterThanDaysToExpire] <int>] [[-DisplayNameCredentials] <string>] [-Expired] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes client secret credentials from Azure AD/Entra applications based on various filtering criteria.
This function can remove credentials from one or multiple applications at once.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Remove-MyAppCredentials -ApplicationName "MyAPI" -Expired
Removes all expired credentials from the application named "MyAPI".
```


### EXAMPLE 2
```powershell
PS > Remove-MyAppCredentials -LessThanDaysToExpire 30
Removes credentials from all applications that expire in less than 30 days.
```


### EXAMPLE 3
```powershell
PS > Remove-MyAppCredentials -DisplayNameCredentials "Old API Access"
Removes all credentials with the display name "Old API Access" from all applications.
```


## PARAMETERS

### -ApplicationName
The name of the application to remove credentials from. If not provided, checks all applications.

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

### -DisplayNameCredentials
When specified, removes only credentials with the specified display name or description.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: DescriptionCredentials, ClientSecretName
Possible values:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Expired
When specified, removes only already expired credentials.

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

### -GreaterThanDaysToExpire
When specified, removes only credentials that expire in more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LessThanDaysToExpire
When specified, removes only credentials that expire in less than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
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
