function New-HTMLReportGraphEssentials {
    [cmdletBinding()]
    param(
        [Array] $Type,
        [switch] $Online,
        [switch] $HideHTML,
        [string] $FilePath
    )

    New-HTML -Author 'Przemysław Kłys @ Evotec' -TitleText 'GraphEssentials Report' {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            foreach ($reportType in $Script:GraphEssentialsConfiguration.Keys) {
                if ($Script:GraphEssentialsConfiguration[$reportType].Enabled) {
                    Add-GraphEssentialsCollectionNotice -Issues $Script:Reporting[$reportType]['WarningsAndErrors']
                }
            }
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
                    & $Script:GraphEssentialsConfiguration[$T]['Solution']
                }
            }
        } else {
            foreach ($T in $Script:GraphEssentialsConfiguration.Keys) {
                if ($Script:GraphEssentialsConfiguration[$T].Enabled -eq $true) {
                    New-HTMLTab -Name $Script:GraphEssentialsConfiguration[$T]['Name'] {
                        & $Script:GraphEssentialsConfiguration[$T]['Solution']
                    }
                }
            }
        }
    } -Online:$Online.IsPresent -ShowHTML:(-not $HideHTML) -FilePath $FilePath
}