---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# New-MyApp
## SYNOPSIS
Creates or updates an Azure AD application and adds credentials.

## SYNTAX
### __AllParameterSets
```powershell
New-MyApp [-ApplicationName] <string> [-DisplayNameCredentials] <string> [[-Description] <string>] [[-MonthsValid] <int>] [-RemoveOldCredentials] [-ServicePrincipal] [<CommonParameters>]
```

## DESCRIPTION
Creates a new Azure AD/Entra application if it doesn't exist, or updates an existing one.
Adds new credentials (client secrets) to the application with specified validity period.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > New-MyApp -ApplicationName "MyAPI" -DisplayNameCredentials "API Access"
Creates or updates an application named "MyAPI" with credentials described as "API Access" valid for 12 months.
```


### EXAMPLE 2
```powershell
PS > New-MyApp -ApplicationName "MyAPI" -DisplayNameCredentials "API Access" -MonthsValid 6 -RemoveOldCredentials
Creates or updates an application, removes any existing credentials, and adds new credentials valid for 6 months.
```


## PARAMETERS

### -ApplicationName
The display name of the application to create or update.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: AppName, DisplayName
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
Optional description for the application.

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

### -DisplayNameCredentials
The display name or description for the credentials being added.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: DescriptionCredentials
Possible values:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MonthsValid
Number of months the credentials should be valid for. Defaults to 12 months.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveOldCredentials
If specified, removes any existing credentials before adding new ones.

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

### -ServicePrincipal
If specified, creates a service principal for the application.

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
