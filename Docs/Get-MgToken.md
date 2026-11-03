---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# Get-MgToken
## SYNOPSIS
Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

## SYNTAX
### Domain (Default)
```powershell
Get-MgToken -ClientID <string> -ClientSecret <string> -Domain <string> [-Proxy <string>] [-ProxyCredential <pscredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### DomainEncrypted
```powershell
Get-MgToken -ClientID <string> -ClientSecretEncrypted <string> -Domain <string> [-Proxy <string>] [-ProxyCredential <pscredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### TenantIDEncrypted
```powershell
Get-MgToken -ClientID <string> -ClientSecretEncrypted <string> -TenantID <string> [-Proxy <string>] [-ProxyCredential <pscredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

### TenantID
```powershell
Get-MgToken -ClientID <string> -ClientSecret <string> -TenantID <string> [-Proxy <string>] [-ProxyCredential <pscredential>] [-ProxyUseDefaultCredentials] [<CommonParameters>]
```

## DESCRIPTION
Provides a way to get a token for Microsoft Graph API to be used with Connect-MGGraph

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -TenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```


### EXAMPLE 2
```powershell
PS > Get-MgToken -ClientID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ClientSecret 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -Domain 'contoso.com'
```


### EXAMPLE 3
```powershell
PS > $ClientSecretEncrypted = 'ClientSecretToEncrypt' | ConvertTo-SecureString -AsPlainText | ConvertFrom-SecureString
$AccessToken = Get-MgToken -Domain 'evotec.pl' -ClientID 'ClientID' -ClientSecretEncrypted $ClientSecretEncrypted
Connect-MgGraph -AccessToken $AccessToken
```


## PARAMETERS

### -ClientID
Provide the Application ID of the App Registration

```yaml
Type: String
Parameter Sets: Domain, DomainEncrypted, TenantIDEncrypted, TenantID
Aliases: ApplicationID
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret
Provide the Client Secret of the App Registration

```yaml
Type: String
Parameter Sets: Domain, TenantID
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecretEncrypted
Specifies a value for client secret encrypted.

```yaml
Type: String
Parameter Sets: DomainEncrypted, TenantIDEncrypted
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Domain
Provide the Domain of the tenant where the App is registred

```yaml
Type: String
Parameter Sets: Domain, DomainEncrypted
Aliases: None
Possible values:

Required: True
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Proxy
Specifies a value for proxy.

```yaml
Type: String
Parameter Sets: Domain, DomainEncrypted, TenantIDEncrypted, TenantID
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProxyCredential
Specifies a value for proxy credential.

```yaml
Type: PSCredential
Parameter Sets: Domain, DomainEncrypted, TenantIDEncrypted, TenantID
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProxyUseDefaultCredentials
Specifies the proxy use default credentials switch.

```yaml
Type: SwitchParameter
Parameter Sets: Domain, DomainEncrypted, TenantIDEncrypted, TenantID
Aliases: None
Possible values:

Required: False
Position: named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantID
Provide the Tenant ID of the App Registration

```yaml
Type: String
Parameter Sets: TenantIDEncrypted, TenantID
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
