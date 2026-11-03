---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# New-MyAppCredentials
## SYNOPSIS
Creates new credentials for an existing Azure AD application.

## SYNTAX
### AppName (Default)
```powershell
New-MyAppCredentials -ApplicationName <string> [-DisplayName <string>] [-MonthsValid <int>] [<CommonParameters>]
```

### AppId
```powershell
New-MyAppCredentials -ObjectID <string> [-DisplayName <string>] [-MonthsValid <int>] [<CommonParameters>]
```

## DESCRIPTION
Adds new client secret credentials to an existing Azure AD/Entra application with specified validity period.
This is useful for rotating credentials or adding additional secrets to applications.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > New-MyAppCredentials -ObjectID "11111111-1111-1111-1111-111111111111" -DisplayName "API Access"
Creates new credentials for the application with the specified object ID, valid for 12 months.
```


### EXAMPLE 2
```powershell
PS > New-MyAppCredentials -ObjectID "11111111-1111-1111-1111-111111111111" -DisplayName "Temporary Access" -MonthsValid 3
Creates new credentials valid for 3 months with the display name "Temporary Access".
```


## PARAMETERS

### -ApplicationName
Specifies a value for application name.

```yaml
Type: String
Parameter Sets: AppName
Aliases: AppName
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisplayName
The display name or description for the credentials being added.

```yaml
Type: String
Parameter Sets: AppName, AppId
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MonthsValid
Number of months the credentials should be valid for. Defaults to 12 months.

```yaml
Type: Int32
Parameter Sets: AppName, AppId
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ObjectID
The object ID of the application to add credentials to.

```yaml
Type: String
Parameter Sets: AppId
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

- `None`

## RELATED LINKS

- None
