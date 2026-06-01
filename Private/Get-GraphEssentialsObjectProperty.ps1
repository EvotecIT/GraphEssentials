function Get-GraphEssentialsObjectProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($propertyName in $Name) {
        if ($InputObject.PSObject.Properties[$propertyName]) {
            return $InputObject.$propertyName
        }
    }

    if ($InputObject.PSObject.Properties['AdditionalProperties'] -and $InputObject.AdditionalProperties) {
        foreach ($propertyName in $Name) {
            if ($InputObject.AdditionalProperties -is [System.Collections.IDictionary] -and $InputObject.AdditionalProperties.Contains($propertyName)) {
                return $InputObject.AdditionalProperties[$propertyName]
            }

            if ($InputObject.AdditionalProperties.PSObject.Properties[$propertyName]) {
                return $InputObject.AdditionalProperties.$propertyName
            }
        }
    }

    $null
}
