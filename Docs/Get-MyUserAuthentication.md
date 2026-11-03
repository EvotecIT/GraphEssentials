---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyUserAuthentication
## SYNOPSIS
Retrieves detailed authentication method information for users from Microsoft Graph API using efficient batching.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyUserAuthentication [[-UserPrincipalName] <string>] [[-BatchSize] <int>] [-IncludeDeviceDetails] [-IncludeSecurityQuestionStatus] [<CommonParameters>]
```

## DESCRIPTION
Gets comprehensive authentication method information for users including MFA status,
registered authentication methods (FIDO2, Phone, SMS, Email, etc.), and detailed
configuration of each method. The function uses batched Graph API requests for significantly
improved performance in large environments.

Returns an array of objects with authentication details and status for each method type.

## EXAMPLES

### EXAMPLE 1
```powershell
Get-MyUserAuthentication -BatchSize 1
```


## PARAMETERS

### -BatchSize
Optional. Specifies the number of requests to include in each batch call. Defaults to 20 (the maximum allowed by Graph API).

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

### -IncludeDeviceDetails
When specified, includes detailed information about FIDO2 security keys, Windows Hello for Business,
and other authentication device details via additional batched calls.

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

### -IncludeSecurityQuestionStatus
Optional. If specified, performs additional API calls to check if each user has registered security questions.
WARNING: This can significantly increase execution time for large numbers of users.

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

### -UserPrincipalName
Optional. The UserPrincipalName of a specific user to retrieve authentication information for.
If not specified, returns information for all users.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
