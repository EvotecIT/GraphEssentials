function New-HTMLReportGraphUsage {
    [cmdletBinding()]
    param(
        [System.Collections.IDictionary] $Reports,
        [switch] $Online,
        [switch] $HideHTML,
        [string] $FilePath
    )

    New-HTML -Author 'Przemysław Kłys' -TitleText 'GraphEssentials Usage Report' {
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

        if ($Reports.Count -eq 1) {
            foreach ($T in $Reports.Keys) {
                New-HTMLTable -DataTable $Reports[$T] -Filtering {

                } -ScrollX
            }
        } else {
            foreach ($T in $Reports.Keys) {
                $Name = Format-AddSpaceToSentence -Text $T
                if ($Reports[$T].Count -gt 0) {
                    $Name = "$Name 💚"
                } else {
                    $Name = "$Name 💔"
                }

                New-HTMLTab -Name $Name {
                    New-HTMLTable -DataTable $Reports[$T] -Filtering {

                    } -ScrollX
                }
            }
        }
    } -Online:$Online.IsPresent -ShowHTML:(-not $HideHTML) -FilePath $FilePath
}