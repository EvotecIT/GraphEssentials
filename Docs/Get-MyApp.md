---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyApp
## SYNOPSIS
Retrieves Azure AD application (Service Principal) information from Microsoft Graph API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyApp [[-ApplicationName] <string>] [[-ApplicationType] <string>] [[-DetailLevel] <string>] [-IncludeCredentials] [-IncludeDetailedSignInLogs] [-IncludeRealtimeSignIns] [-SkipDelegatedPermissions] [-SkipActivity] [-SkipOwners] [<CommonParameters>]
```

## DESCRIPTION
Gets comprehensive information about Azure AD/Entra Service Principals (Enterprise Apps) with multi-source activity analysis for security assessment.
Includes display names, owners, client IDs, credential details (for owned apps), source, and comprehensive activity tracking across:
- User sign-ins (interactive and non-interactive)
- Service principal operations and API usage
- Delegated access through Azure Portal and other Microsoft services
- Application authentication activity and management operations
This provides complete "Days Since Last Activity" calculations for identifying unused/dead applications.
Uses helper functions in the Private folder for data retrieval steps.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyApp
Returns all Azure AD Service Principals (Enterprise Apps) with enhanced information.
```


### EXAMPLE 2
```powershell
PS > Get-MyApp -ApplicationName "MyAPI"
Returns enhanced information for a specific Service Principal named "MyAPI".
```


### EXAMPLE 3
```powershell
PS > Get-MyApp -IncludeCredentials
Returns all Service Principals with detailed credential information included under the 'Keys' property.
```


### EXAMPLE 4
```powershell
PS > Get-MyApp -ApplicationType EnterpriseApps
Returns all Enterprise Apps with enhanced information.
```


### EXAMPLE 5
```powershell
PS > Get-MyApp -IncludeDetailedSignInLogs
Returns all Service Principals with authentication method details. WARNING: This can be slow for large tenants.
```


### EXAMPLE 6
```powershell
PS > Get-MyApp -IncludeRealtimeSignIns
Returns all Service Principals with real-time sign-in data for enhanced accuracy. WARNING: This can be very slow for large tenants (100k+ users).
```


## PARAMETERS

### -ApplicationName
Optional. The display name of a specific Service Principal (Enterprise App) to retrieve. If not specified, all are returned.
Note: Filtering is applied *after* retrieving all SPs due to the need for expanded properties.

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

### -ApplicationType
Optional. Filters the Service Principals based on their type. Valid values are 'All', 'AppRegistrations', 'EnterpriseApps', 'MicrosoftApps', and 'ManagedIdentities'.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: All, AppRegistrations, EnterpriseApps, MicrosoftApps, ManagedIdentities

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DetailLevel
Controls how much supporting data is collected:
- Full    : current behaviour (delegated perms, owners, comprehensive activity) – requires broad Graph permissions
- Light   : skips delegated permission grants and comprehensive activity; still collects owners
- Minimal : skips delegated permission grants, owners and comprehensive activity (suitable for expiry-only monitoring)

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Full, Light, Minimal

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeCredentials
Switch parameter. When specified, includes detailed credential information (from Get-MyAppCredentials, requires corresponding Application object) in the output objects under the 'Keys' property.

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

### -IncludeDetailedSignInLogs
Switch parameter. When specified, includes detailed authentication method information for the LastSignInMethod field.
NOTE: This parameter now has limited impact since comprehensive activity tracking is enabled by default.
The primary difference is that it fetches authentication method details (e.g., "Password", "MFA", "Certificate").
For most security assessments, this parameter is optional as the comprehensive activity data provides sufficient information.
WARNING: This can be slower for large tenants as it downloads recent sign-in logs to extract authentication methods.

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

### -IncludeRealtimeSignIns
Switch parameter. When specified, includes real-time sign-in logs for enhanced activity accuracy.
WARNING: This can be very expensive for large tenants (100k+ users) as it downloads recent sign-in logs for all applications.
The aggregated data (default) is usually sufficient for security assessment and is much faster.
Only use this for small tenants or when you need the most current sign-in data.

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

### -SkipActivity
Forces comprehensive activity analysis to be skipped regardless of DetailLevel.

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

### -SkipDelegatedPermissions
Forces delegated permission grants to be skipped regardless of DetailLevel.

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

### -SkipOwners
Forces owner lookups to be skipped regardless of DetailLevel.

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
