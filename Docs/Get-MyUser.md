---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyUser
## SYNOPSIS
Retrieves detailed information about users from Microsoft Graph API.

## SYNTAX
### Default (Default)
```powershell
Get-MyUser [-IncludeSignInActivity] [<CommonParameters>]
```

### PerLicense
```powershell
Get-MyUser [-PerLicense] [-IncludeSignInActivity] [<CommonParameters>]
```

### PerServicePlan
```powershell
Get-MyUser [-PerServicePlan] [-IncludeSignInActivity] [<CommonParameters>]
```

## DESCRIPTION
Gets comprehensive user information from Microsoft Graph API with options to organize
by license or service plan. Provides detailed user properties including account status,
sign-in activity, licenses, user type, managers, and on-premises synchronization details.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyUser
Returns detailed information about all users in the tenant.
```


### EXAMPLE 2
```powershell
PS > Get-MyUser -PerLicense
Returns user information organized by license assignments.
```


### EXAMPLE 3
```powershell
PS > Get-MyUser -PerServicePlan
Returns user information organized by service plan assignments.
```


## PARAMETERS

### -IncludeSignInActivity
Requests sign-in activity from Microsoft Graph. This is opt-in because it requires
AuditLog.Read.All. If that permission is unavailable, the command retries without
sign-in activity while retaining user and license data.

```yaml
Type: SwitchParameter
Parameter Sets: Default, PerLicense, PerServicePlan
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PerLicense
When specified, organizes user information by license instead of by user.

```yaml
Type: SwitchParameter
Parameter Sets: PerLicense
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PerServicePlan
When specified, organizes user information by service plan instead of by user.

```yaml
Type: SwitchParameter
Parameter Sets: PerServicePlan
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
