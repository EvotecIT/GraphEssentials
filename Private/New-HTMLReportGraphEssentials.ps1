function New-HTMLReportGraphEssentials {
    [cmdletBinding()]
    param(
        [Array] $Type,
        [switch] $Online,
        [switch] $HideHTML,
        [string] $FilePath
    )

    New-HTML -Author 'Przemysław Kłys' -TitleText 'GraphEssentials Report' {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "GraphEssentials - $($Script:Reporting['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        if ($Type.Count -eq 1) {
            foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
                if ($Script:GraphEssentialsConfiguration[$T].Enabled -eq $true) {
                    if ($Script:GraphEssentialsConfiguration[$T]['Summary']) {
                        $Script:Reporting[$T]['Summary'] = Invoke-Command -ScriptBlock $Script:GraphEssentialsConfiguration[$T]['Summary']
                    }
                    & $Script:GraphEssentialsConfiguration[$T]['Solution']
                }
            }
        } else {
            foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
                if ($Script:GraphEssentialsConfiguration[$T].Enabled -eq $true) {
                    if ($Script:GraphEssentialsConfiguration[$T]['Summary']) {
                        $Script:Reporting[$T]['Summary'] = Invoke-Command -ScriptBlock $Script:GraphEssentialsConfiguration[$T]['Summary']
                    }
                    New-HTMLTab -Name $Script:GraphEssentialsConfiguration[$T]['Name'] {
                        & $Script:GraphEssentialsConfiguration[$T]['Solution']
                    }
                }
            }
        }
    } -Online:$Online.IsPresent -ShowHTML:(-not $HideHTML) -FilePath $FilePath
}