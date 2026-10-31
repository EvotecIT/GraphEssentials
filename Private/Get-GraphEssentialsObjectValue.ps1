function Get-GraphEssentialsObjectValue {
    <# Read SDK models, JSON dictionaries and input records without losing null, false or array values. #>
    [CmdletBinding()]
    param(
        [AllowNull()] $InputObject,
        [Parameter(Mandatory)][string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([string] $key -ieq $Name) {
                return , $InputObject[$key]
            }
        }
    } else {
        $property = $InputObject.PSObject.Properties[$Name]
        if ($property) {
            return , $property.Value
        }
        $additional = $InputObject.PSObject.Properties['AdditionalProperties']
        if ($additional -and $additional.Value -is [System.Collections.IDictionary]) {
            foreach ($key in $additional.Value.Keys) {
                if ([string] $key -ieq $Name) {
                    return , $additional.Value[$key]
                }
            }
        }
    }
}
