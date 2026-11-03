---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Send-MyApp
## SYNOPSIS
Creates application credentials and emails them to specified recipients.

## SYNTAX
### __AllParameterSets
```powershell
Send-MyApp [-ApplicationName] <array> [-EmailFrom] <string> [-EmailTo] <string[]> [[-EmailSubject] <string>] [-Domain] <string> [-RemoveOldCredentials] [<CommonParameters>]
```

## DESCRIPTION
Creates new Azure AD/Entra applications or adds credentials to existing applications,
then sends the credentials securely via email to specified recipients. Optionally can
remove old credentials during the process.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Send-MyApp -ApplicationName "MyAPI" -EmailFrom "admin@contoso.com" -EmailTo "developer@contoso.com" -Domain "contoso.com"
Creates or updates an application named "MyAPI" and emails the credentials to developer@contoso.com.
```


### EXAMPLE 2
```powershell
PS > Send-MyApp -ApplicationName @("API1", "API2") -EmailFrom "admin@contoso.com" -EmailTo "team@contoso.com" -Domain "contoso.com" -RemoveOldCredentials
Creates or updates two applications, removes any existing credentials, and emails the new credentials to team@contoso.com.
```


## PARAMETERS

### -ApplicationName
An array of application names to create or update. Can be strings or hashtables with configuration details.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Domain
The domain name of the tenant where applications are registered.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmailFrom
The email address to send notifications from.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmailSubject
The subject line for the email. Defaults to 'Service Principal for Applications'.

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

### -EmailTo
One or more email addresses to send the credentials to.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 2
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
