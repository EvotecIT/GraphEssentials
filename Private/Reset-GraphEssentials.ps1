function Reset-GraphEssentials {
    [cmdletBinding()]
    param(

    )
    if (-not $Script:DefaultTypes) {
        $Script:DefaultTypes = foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
            if ($Script:GraphEssentialsConfiguration[$T].Enabled) {
                $T
            }
        }
    } else {
        foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
            if ($Script:GraphEssentialsConfiguration[$T]) {
                $Script:GraphEssentialsConfiguration[$T]['Enabled'] = $false
            }
        }
        foreach ($T in $Script:DefaultTypes) {
            if ($Script:GraphEssentialsConfiguration[$T]) {
                $Script:GraphEssentialsConfiguration[$T]['Enabled'] = $true
            }
        }
    }
}