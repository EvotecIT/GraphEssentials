<p align="center">
  <a href="https://www.powershellgallery.com/packages/GraphEssentials"><img src="https://img.shields.io/powershellgallery/v/GraphEssentials.svg"></a>
  <a href="https://www.powershellgallery.com/packages/GraphEssentials"><img src="https://img.shields.io/powershellgallery/vpre/GraphEssentials.svg?label=powershell%20gallery%20preview&colorB=yellow"></a>
  <a href="https://github.com/EvotecIT/GraphEssentials"><img src="https://img.shields.io/github/license/EvotecIT/GraphEssentials.svg"></a>
</p>

<p align="center">
  <a href="https://www.powershellgallery.com/packages/GraphEssentials"><img src="https://img.shields.io/powershellgallery/p/GraphEssentials.svg"></a>
  <a href="https://github.com/EvotecIT/GraphEssentials"><img src="https://img.shields.io/github/languages/top/evotecit/GraphEssentials.svg"></a>
  <a href="https://github.com/EvotecIT/GraphEssentials"><img src="https://img.shields.io/github/languages/code-size/evotecit/GraphEssentials.svg"></a>
  <a href="https://www.powershellgallery.com/packages/GraphEssentials"><img src="https://img.shields.io/powershellgallery/dt/GraphEssentials.svg"></a>
</p>

<p align="center">
  <a href="https://twitter.com/PrzemyslawKlys"><img src="https://img.shields.io/twitter/follow/PrzemyslawKlys.svg?label=Twitter%20%40PrzemyslawKlys&style=social"></a>
  <a href="https://evotec.xyz/hub"><img src="https://img.shields.io/badge/Blog-evotec.xyz-2A6496.svg"></a>
  <a href="https://www.linkedin.com/in/pklys"><img src="https://img.shields.io/badge/LinkedIn-pklys-0077B5.svg?logo=LinkedIn"></a>
  <a href="https://evo.yt/discord"><img src="https://img.shields.io/discord/508328927853281280?style=flat-square&label=discord%20chat"></a>
</p>

# GraphEssentials PowerShell Module


## To install

```powershell
Install-Module -Name GraphEssentials -AllowClobber -Force
```

Force and AllowClobber aren't necessary, but they do skip errors in case some appear.

## And to update

```powershell
Update-Module -Name GraphEssentials
```

That's it. Whenever there's a new version, you run the command, and you can enjoy it. Remember that you may need to close, reopen PowerShell session if you have already used module before updating it.

**The essential thing** is if something works for you on production, keep using it till you test the new version on a test computer. I do changes that may not be big, but big enough that auto-update may break your code. For example, small rename to a parameter and your code stops working! Be responsible!

### Using Graph

#### Connecting with ApplicationID, ApplicationSecret as an application


```powershell
# Client secret Encrypted can be saved to file and then loaded from file
$ClientSecretEncrypted = 'ClientSecretToEncrypt' | ConvertTo-SecureString -AsPlainText | ConvertFrom-SecureString
$AccessToken = Get-MgToken -Domain 'evotec.pl' -ClientID 'ClientID' -ClientSecretEncrypted $ClientSecretEncrypted
Connect-MgGraph -AccessToken $AccessToken
```

### Connecting with delegated rights

```powershell
Connect-MgGraph -Scopes Application.ReadWrite.All, AccessReview.Read.All, AdministrativeUnit.Read.All, 'User.Read.All', RoleManagement.Read.Directory, Directory.Read.All, EntitlementManagement.Read.All
```

### Available Commands

Complete list of commands available in GraphEssentials module.

| CommandType | Name                             |
| ----------- | -------------------------------- |
| Function    | Get-MgToken                      |
| Function    | Get-MyApp                        |
| Function    | Get-MyAppCredentials             |
| Function    | Get-MyConditionalAccess          |
| Function    | Get-MyDefenderDeploymentKey      |
| Function    | Get-MyDefenderHealthIssues       |
| Function    | Get-MyDefenderSecureScore        |
| Function    | Get-MyDefenderSecureScoreProfile |
| Function    | Get-MyDefenderSensor             |
| Function    | Get-MyDefenderSummary            |
| Function    | Get-MyDevice                     |
| Function    | Get-MyDeviceIntune               |
| Function    | Get-MyLicense                    |
| Function    | Get-MyRole                       |
| Function    | Get-MyRoleHistory                |
| Function    | Get-MyRoleUsers                  |
| Function    | Get-MyTeam                       |
| Function    | Get-MyTenantName                 |
| Function    | Get-MyUsageReports               |
| Function    | Get-MyUser                       |
| Function    | Get-MyUserAuthentication         |
| Function    | Invoke-MyGraphEssentials         |
| Function    | Invoke-MyGraphUsageReports       |
| Function    | New-MyApp                        |
| Function    | New-MyAppCredentials             |
| Function    | Register-FIDO2Key                |
| Function    | Remove-MyAppCredentials          |
| Function    | Send-MyApp                       |
| Function    | Show-MyApp                       |
| Function    | Show-MyConditionalAccess         |
| Function    | Show-MyDefender                  |
| Function    | Show-MyRole                      |
| Function    | Show-MyUserAuthentication        |