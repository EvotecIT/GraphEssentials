---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Show-MyUserAuthentication
## SYNOPSIS
Generates an HTML report for user authentication methods and related tenant policies.

## SYNTAX
### __AllParameterSets
```powershell
Show-MyUserAuthentication [-FilePath] <string> [[-UserPrincipalName] <string>] [-Online] [-ShowHTML] [-IncludeDeviceDetails] [-IncludeSecurityQuestionStatus] [-IncludeRoles] [-IncludeLicenses] [-IncludeLicenseServices] [<CommonParameters>]
```

## DESCRIPTION
Creates a comprehensive HTML report displaying information about user authentication methods
(MFA status, FIDO2 keys, etc.), Authentication Methods Policy configurations, and
Authentication Strength policies.

## EXAMPLES

### EXAMPLE 1
```powershell
Show-MyUserAuthentication -FilePath 'C:\Path'
```


## PARAMETERS

### -FilePath
The path where the HTML report will be saved.

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

### -IncludeDeviceDetails
When specified, includes detailed information about FIDO2 security keys and
other authentication device details in the user data section.

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

### -IncludeLicenses
Optional. When specified, augments the user details with a Licenses column
showing assigned license names per user. Reuses existing Get-MyUser or
Get-MyRoleUsers (when IncludeRoles is also used) data.

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

### -IncludeLicenseServices
Optional. When specified, augments the user details with LicenseServices (aka
sublicenses/service plans) per user. Reuses existing data from Get-MyRoleUsers
(LicenseServices) or Get-MyUser (Plans) depending on other switches.

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

### -IncludeRoles
Optional. When specified, augments the user details with a Roles column
showing aggregated directory roles per user (direct, eligible, and via groups).
Reuses existing Get-MyRoleUsers data.

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
Optional. If specified, checks if each user has registered security questions.
WARNING: This can significantly increase execution time and memory usage.

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

### -Online
If specified, opens the HTML report in the default browser after generation.

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

### -ShowHTML
If specified, displays the HTML content in the PowerShell console after generation.

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
Optional. The UserPrincipalName of a specific user to generate the report for.
If not specified, generates report for all users.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
