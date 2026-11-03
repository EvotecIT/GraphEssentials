---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyGuest
## SYNOPSIS
Retrieves guest and external user accounts from Microsoft Graph API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyGuest [-IncludeSignInActivity] [<CommonParameters>]
```

## DESCRIPTION
Gets guest and external user accounts from Microsoft Graph API with properties that are
useful when reviewing B2B accounts. The output focuses on invitation state, account
lifecycle, licensing, and tenant-specific metadata to make external identities easier
to audit separately from member users.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyGuest
Returns guest and external users in the tenant.
```


## PARAMETERS

### -IncludeSignInActivity
Requests sign-in activity from Microsoft Graph. This is opt-in because it requires
AuditLog.Read.All. If that permission is unavailable, the command retries without
sign-in activity while retaining guest and license data.

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
