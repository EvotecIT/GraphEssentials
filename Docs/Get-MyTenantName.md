---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MyTenantName
## SYNOPSIS
Get Tenant Name from Tenant ID or Domain Name

## SYNTAX
### TenantID (Default)
```powershell
Get-MyTenantName -TenantID <string> [<CommonParameters>]
```

### DomainName
```powershell
Get-MyTenantName -DomainName <string> [<CommonParameters>]
```

## DESCRIPTION
Get Tenant Name from Tenant ID or Domain Name

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MyTenantName -TenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```


### EXAMPLE 2
```powershell
PS > Get-MyTenantName -DomainName 'contoso.com'
```


## PARAMETERS

### -DomainName
Provide the Domain Name of the Tenant

```yaml
Type: String
Parameter Sets: DomainName
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantID
Provide the Tenant ID of the Tenant

```yaml
Type: String
Parameter Sets: TenantID
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
