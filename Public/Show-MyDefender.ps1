function Show-MyDefender {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML
    )

    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-MyGraphEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'GraphEssentials'

    $DefenderHealthIssues = Get-MyDefenderHealthIssues -Status 'open'
    if ($DefenderHealthIssues -eq $false) {
        return
    }
    $SecureScore = Get-MyDefenderSecureScore
    #$SecureProfile = Get-MyDefenderSecureScoreProfile
    $DefenderDeploymentKey = Get-MyDefenderDeploymentKey
    $DefenderSensor = Get-MyDefenderSensor

    New-HTML {
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

        New-HTMLTab -Name "Defender Sensor" {
            New-HTMLSection -HeaderText "Defender Sensor" {
                New-HTMLTable -DataTable $DefenderSensor -Filtering {

                } -DataStore JavaScript -DataTableID "DefenderSensor" -PagingLength 5 -ScrollX
            }
        }
        New-HTMLTab -Name "Defender Deployment Key" {
            New-HTMLSection -HeaderText "Defender Deployment Key" {
                New-HTMLList {
                    New-HTMLListItem -Text "DeploymentAccessKey: ", "$($DefenderDeploymentKey.DeploymentAccessKey)" -FontWeight normal, bold -Color None, AlmondFrost
                    New-HTMLListItem -Text "DownloadUrl: ", "$($DefenderDeploymentKey.DownloadUrl)" -FontWeight normal, bold -Color None, AlmondFrost
                }
            }
        }

        New-HTMLTab -Name "Defender Health Issues" {
            New-HTMLSection -HeaderText "Defender Health Issues" {
                New-HTMLTable -DataTable $DefenderHealthIssues -Filtering {

                } -DataStore JavaScript -DataTableID "DefenderHealthIssues" -PagingLength 5 -ScrollX
            }
        }
        New-HTMLTab -Name "Defender Secure Score" {
            New-HTMLSection -HeaderText 'Defender Secure Score' {
                New-HTMLTable -DataTable $SecureScore -Filtering {

                } -DataStore JavaScript -DataTableID "SecureScore" -ScrollX
            }
        }
        # New-HTMLTab -Name "Defender Secure Profile" {
        #     New-HTMLSection -HeaderText 'Defender Secure Profile' {
        #         New-HTMLTable -DataTable $SecureProfile -Filtering {

        #         } -DataStore JavaScript -DataTableID "SecureProfile" -ScrollX
        #     }
        # }
    } -ShowHTML:$ShowHTML.IsPresent -FilePath $FilePath -Online:$Online.IsPresent
}