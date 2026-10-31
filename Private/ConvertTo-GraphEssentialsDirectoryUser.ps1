function ConvertTo-GraphEssentialsDirectoryUser {
    <# Project only requested directory data; custom extensions and manager fields can live in SDK AdditionalProperties. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $User,
        [Parameter(Mandatory)][string[]] $Property,
        [switch] $IncludeManager
    )

    $result = [ordered] @{}
    foreach ($name in $Property) {
        if ($name -ieq 'manager') {
            continue
        }
        if ($name -match '^extensionAttribute(?:[1-9]|1[0-5])$') {
            $extensions = Get-GraphEssentialsObjectValue -InputObject $User -Name 'OnPremisesExtensionAttributes'
            $result[$name] = Get-GraphEssentialsObjectValue -InputObject $extensions -Name $name
        } else {
            $result[$name] = Get-GraphEssentialsObjectValue -InputObject $User -Name $name
        }
    }
    if ($IncludeManager) {
        $manager = Get-GraphEssentialsObjectValue -InputObject $User -Name 'Manager'
        $managerId = Get-GraphEssentialsObjectValue -InputObject $manager -Name 'Id'
        $result['Manager'] = if ($managerId) {
            [pscustomobject] @{
                Id                      = $managerId
                DisplayName             = Get-GraphEssentialsObjectValue -InputObject $manager -Name 'DisplayName'
                UserPrincipalName       = Get-GraphEssentialsObjectValue -InputObject $manager -Name 'UserPrincipalName'
                Mail                    = Get-GraphEssentialsObjectValue -InputObject $manager -Name 'Mail'
                OnPremisesSyncEnabled   = Get-GraphEssentialsObjectValue -InputObject $manager -Name 'OnPremisesSyncEnabled'
            }
        } else {
            $null
        }
    }
    [pscustomobject] $result
}
