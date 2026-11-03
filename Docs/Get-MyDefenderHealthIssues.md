---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyDefenderHealthIssues
## SYNOPSIS
Retrieves health issues from Microsoft Graph Security API.

## SYNTAX
### __AllParameterSets
```powershell
Get-MyDefenderHealthIssues [[-Status] <string>] [[-HealthIssueType] <string>] [[-Severity] <string>] [[-SensorDNSName] <string>] [-All] [-Summary] [<CommonParameters>]
```

## DESCRIPTION
This function queries the Microsoft Graph Security API to retrieve health issues based on various filters such as status, health issue type, severity, and sensor DNS name.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Connect-MgGraph -Scopes 'SecurityIdentitiesHealth.Read.All'
Get-MyDefenderHealthIssues -Status 'open' -HealthIssueType 'global' -Severity 'high'
Retrieves all open global health issues with high severity.
```


### EXAMPLE 2
```powershell
PS > Connect-MgGraph -Scopes 'SecurityIdentitiesHealth.Read.All'
Get-MyDefenderHealthIssues -SensorDNSName 'contoso.com' -All
Retrieves all health issues for sensors whose DNS name ends with 'contoso.com', ignoring other filters.
```


## PARAMETERS

### -All
A switch parameter. If specified, all health issues will be retrieved without applying any filters.

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

### -HealthIssueType
The type of health issues to retrieve. Valid values are 'global' and 'sensor'.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: global, sensor

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SensorDNSName
The DNS name of the sensor for which to retrieve health issues. Health issues will be filtered to only include those that end with the specified sensor DNS name.

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

### -Severity
The severity of the health issues to retrieve. Valid values are 'high', 'medium', and 'low'.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: high, medium, low

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Status
The status of the health issues to retrieve. Valid values are 'open' and 'closed'.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: open, closed

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Summary
Specifies the summary switch.

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
