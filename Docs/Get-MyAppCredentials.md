---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyAppCredentials
## SYNOPSIS
Retrieves Azure AD application credentials information.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyAppCredentials [[-ApplicationName] <string>] [[-LessThanDaysToExpire] <int>] [[-GreaterThanDaysToExpire] <int>] [[-DisplayNameCredentials] <string>] [-Expired] [-IncludeFederated] [<CommonParameters>]
```

## DESCRIPTION
Gets detailed information about Azure AD/Entra application credentials (secrets and certificates),
including expiration dates, types, and associated metadata. Allows filtering based on
various criteria such as expiration date, display name, and application name.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyAppCredentials
Returns credentials for all Azure AD applications.
```


### EXAMPLE 2
```powershell
PS > Get-MyAppCredentials -ApplicationName "MyAPI"
Returns credentials for a specific application named "MyAPI".
```


### EXAMPLE 3
```powershell
PS > Get-MyAppCredentials -LessThanDaysToExpire 30
Returns only credentials that expire within the next 30 days.
```


### EXAMPLE 4
```powershell
PS > Get-MyAppCredentials -Expired
Returns only expired credentials across all applications.
```


## PARAMETERS

### -ApplicationName
Optional. The display name of a specific application to retrieve credentials for.

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
Optional. Filters credentials to those with a display name matching the specified pattern.

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
Switch parameter. When specified, returns only expired credentials.

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
Optional. Filters credentials to return only those that expire in more than the specified number of days.

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

### -IncludeFederated
Specifies the include federated switch.

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

### -LessThanDaysToExpire
Optional. Filters credentials to return only those that expire in less than the specified number of days.

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
