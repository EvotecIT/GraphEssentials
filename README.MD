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