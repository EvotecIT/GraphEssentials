$Script:AppsCredentials = [ordered] @{
    Name       = 'Azure Active Directory Apps Credentials'
    Enabled    = $true
    Execute    = {
        Get-MyAppCredentials
    }
    Processing = {

    }
    Summary    = {
        $credentialData = @($Script:Reporting['AppsCredentials']['Data'])
        $totalCredentials = $credentialData.Count
        $expiredCredentials = 0
        $expiring30Days = 0
        $expiring90Days = 0
        $longLivedCredentials = 0
        $credentialsWithoutExpiry = 0
        $passwordCredentials = 0
        $certificateCredentials = 0
        $federatedCredentials = 0
        $typeCounts = @{}
        $expiryCounts = @{
            'Expired'     = 0
            '0-30 days'   = 0
            '31-90 days'  = 0
            '91-365 days' = 0
            '365+ days'   = 0
            'No expiry'   = 0
        }
        $distinctApplications = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $appSummaryMap = @{}
        $expiredList = [System.Collections.Generic.List[object]]::new()
        $expiringSoonList = [System.Collections.Generic.List[object]]::new()
        $longLivedList = [System.Collections.Generic.List[object]]::new()
        $federatedList = [System.Collections.Generic.List[object]]::new()
        $reviewCandidates = [System.Collections.Generic.List[object]]::new()

        foreach ($credential in $credentialData) {
            if ($credential.ApplicationName) {
                [void] $distinctApplications.Add($credential.ApplicationName)
                if (-not $appSummaryMap.ContainsKey($credential.ApplicationName)) {
                    $appSummaryMap[$credential.ApplicationName] = [ordered]@{
                        ApplicationName = $credential.ApplicationName
                        CredentialCount = 0
                        ExpiredCount    = 0
                        Expiring30Days  = 0
                        FederatedCount  = 0
                    }
                }
                $appSummaryMap[$credential.ApplicationName].CredentialCount++
            }

            $type = if ($credential.Type) { $credential.Type } else { 'Unknown' }
            if (-not $typeCounts.ContainsKey($type)) {
                $typeCounts[$type] = 0
            }
            $typeCounts[$type]++

            if ($type -eq 'Password') {
                $passwordCredentials++
            } elseif ($type -eq 'Certificate') {
                $certificateCredentials++
            } elseif ($type -eq 'Federated') {
                $federatedCredentials++
                $federatedList.Add($credential)
            }

            $reviewFlags = [System.Collections.Generic.List[string]]::new()
            if ($credential.Expired) {
                $expiredCredentials++
                $expiryCounts['Expired']++
                $expiredList.Add($credential)
                if ($credential.ApplicationName) {
                    $appSummaryMap[$credential.ApplicationName].ExpiredCount++
                }
                $reviewFlags.Add('Expired')
            } elseif ($null -eq $credential.DaysToExpire) {
                $credentialsWithoutExpiry++
                $expiryCounts['No expiry']++
                if ($type -eq 'Federated') {
                    $reviewFlags.Add('Federated trust')
                } else {
                    $reviewFlags.Add('No expiry information')
                }
            } elseif ($credential.DaysToExpire -le 30) {
                $expiring30Days++
                $expiring90Days++
                $expiryCounts['0-30 days']++
                $expiringSoonList.Add($credential)
                if ($credential.ApplicationName) {
                    $appSummaryMap[$credential.ApplicationName].Expiring30Days++
                }
                $reviewFlags.Add('Expires in 30 days')
            } elseif ($credential.DaysToExpire -le 90) {
                $expiring90Days++
                $expiryCounts['31-90 days']++
            } elseif ($credential.DaysToExpire -le 365) {
                $expiryCounts['91-365 days']++
            } else {
                $longLivedCredentials++
                $expiryCounts['365+ days']++
                $longLivedList.Add($credential)
                $reviewFlags.Add('Long-lived credential')
            }

            if ($type -eq 'Federated') {
                if ($credential.ApplicationName) {
                    $appSummaryMap[$credential.ApplicationName].FederatedCount++
                }
                if ($reviewFlags -notcontains 'Federated trust') {
                    $reviewFlags.Add('Federated trust')
                }
            }

            if ($reviewFlags.Count -gt 0) {
                $reviewFlagsText = $reviewFlags.ToArray() -join ', '
                $reviewCandidates.Add(($credential | Select-Object -Property *, @{ Name = 'ReviewFlags'; Expression = { $reviewFlagsText } }))
            }
        }

        $overview = @(
            [PSCustomObject]@{
                TotalCredentials         = $totalCredentials
                DistinctApplications     = $distinctApplications.Count
                ExpiredCredentials       = $expiredCredentials
                ExpiringIn30Days         = $expiring30Days
                ExpiringIn90Days         = $expiring90Days
                LongLivedCredentials     = $longLivedCredentials
                CredentialsWithoutExpiry = $credentialsWithoutExpiry
                PasswordCredentials      = $passwordCredentials
                CertificateCredentials   = $certificateCredentials
                FederatedCredentials     = $federatedCredentials
            }
        )

        $typeDistribution = @(
            foreach ($key in $typeCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $typeCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $expiryDistribution = @(
            foreach ($key in $expiryCounts.Keys) {
                [PSCustomObject]@{
                    Name  = $key
                    Count = $expiryCounts[$key]
                }
            }
        ) | Sort-Object Count -Descending

        $applicationSummary = @(
            foreach ($key in $appSummaryMap.Keys) {
                [PSCustomObject]$appSummaryMap[$key]
            }
        ) | Sort-Object -Property @{ Expression = 'CredentialCount'; Descending = $true }, @{ Expression = 'ApplicationName'; Descending = $false }

        [PSCustomObject]@{
            Overview           = $overview
            TypeDistribution   = $typeDistribution
            ExpiryDistribution = $expiryDistribution
            ApplicationSummary = $applicationSummary
            Expired            = @($expiredList)
            ExpiringSoon       = @($expiringSoonList | Sort-Object DaysToExpire)
            LongLived          = @($longLivedList | Sort-Object DaysToExpire -Descending)
            Federated          = @($federatedList)
            ReviewCandidates   = @($reviewCandidates)
        }
    }
    Variables  = @{

    }
    Solution   = {
        $credentialSummary = $Script:Reporting['AppsCredentials']['Summary']
        $credentialData = @($Script:Reporting['AppsCredentials']['Data'])
        $credentialCount = $credentialData.Count

        if ($credentialData) {
            $credentialTableConditions = {
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Password' -ComparisonType string -BackgroundColor LightSkyBlue
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Certificate' -ComparisonType string -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'Type' -Operator eq -Value 'Federated' -ComparisonType string -BackgroundColor PeachOrange -HighlightHeaders 'Type', 'ApplicationName', 'KeyDisplayName'
                New-HTMLTableCondition -Name 'Expired' -Operator eq -Value $true -ComparisonType string -BackgroundColor Salmon -HighlightHeaders 'Expired', 'DaysToExpire', 'EndDateTime'
                New-HTMLTableCondition -Name 'DaysToExpire' -Operator betweenInclusive -Value 0, 30 -ComparisonType number -BackgroundColor Orange -HighlightHeaders 'DaysToExpire', 'EndDateTime'
                New-HTMLTableCondition -Name 'DaysToExpire' -Operator betweenInclusive -Value 31, 90 -ComparisonType number -BackgroundColor LaserLemon -HighlightHeaders 'DaysToExpire', 'EndDateTime'
                New-HTMLTableCondition -Name 'DaysToExpire' -Operator gt -Value 365 -ComparisonType number -BackgroundColor LightBlue -HighlightHeaders 'DaysToExpire', 'EndDateTime'
            }

            New-HTMLTabPanel {
                New-HTMLTab -Name "Overview ($credentialCount)" {
                    if ($credentialSummary -and $credentialSummary.Overview) {
                        $overview = $credentialSummary.Overview[0]
                        New-HTMLSection -HeaderText 'Application Credential Overview' -Density Compact {
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Total Credentials' -Number $overview.TotalCredentials -Subtitle 'Secrets, certificates, and federated trusts' -Icon '🔑' -IconColor '#0078d4' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Distinct Applications' -Number $overview.DistinctApplications -Subtitle 'Applications with credential entries' -Icon '📱' -IconColor '#198754' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Expired / 30 Days' -Number "$($overview.ExpiredCredentials) / $($overview.ExpiringIn30Days)" -Subtitle 'Urgent credential review items' -Icon '🚨' -IconColor '#dc3545' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'Long-Lived' -Number $overview.LongLivedCredentials -Subtitle 'Credentials with >365 days remaining' -Icon '📆' -IconColor '#fd7e14' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLInfoCard -Title 'Password / Certificate / Federated' -Number "$($overview.PasswordCredentials) / $($overview.CertificateCredentials) / $($overview.FederatedCredentials)" -Subtitle 'Credential type split' -Icon '🧾' -IconColor '#20c997' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title 'No Expiry' -Number $overview.CredentialsWithoutExpiry -Subtitle 'Entries without an expiry date' -Icon '♾️' -IconColor '#6f42c1' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                                New-HTMLInfoCard -Title '90-Day Exposure' -Number $overview.ExpiringIn90Days -Subtitle 'Expired or expiring in 90 days' -Icon '⏳' -IconColor '#ffc107' -Style 'Standard' -ShadowIntensity 'Normal' -BorderRadius 2px
                            }
                            New-HTMLSection -Invisible {
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Credential Type Distribution' {
                                        foreach ($item in $credentialSummary.TypeDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                                New-HTMLPanel {
                                    New-HTMLChart -Title 'Credential Expiry Distribution' {
                                        foreach ($item in $credentialSummary.ExpiryDistribution) {
                                            New-ChartPie -Name $item.Name -Value $item.Count
                                        }
                                    }
                                }
                            }
                            if (@($credentialSummary.ApplicationSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Applications With The Most Credentials' -Invisible {
                                    New-HTMLPanel {
                                        New-HTMLChart -Title 'Credential Count Per Application' {
                                            foreach ($item in ($credentialSummary.ApplicationSummary | Select-Object -First 10)) {
                                                New-ChartBar -Name $item.ApplicationName -Value $item.CredentialCount
                                            }
                                        }
                                    }
                                }
                            }
                            New-HTMLSection -HeaderText 'Overview Summary Table' {
                                New-HTMLTable -DataTable $credentialSummary.Overview -Filtering -ScrollX
                            }
                        } -Wrap wrap
                    }
                }
                New-HTMLTab -Name "Credential Inventory ($credentialCount)" {
                    New-HTMLTabPanel {
                        New-HTMLTab -Name "All Credentials ($credentialCount)" {
                            New-HTMLSection -HeaderText 'All Application Credentials' {
                                New-HTMLTable -DataTable $credentialData -Filtering $credentialTableConditions -ScrollX
                            }
                        }
                        New-HTMLTab -Name "Expired ($(@($credentialSummary.Expired).Count))" {
                            if (@($credentialSummary.Expired).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Expired Application Credentials' {
                                    New-HTMLTable -DataTable $credentialSummary.Expired -Filtering $credentialTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Expired Application Credentials' {
                                    New-HTMLText -Text 'No expired application credentials were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Expiring 30 Days ($(@($credentialSummary.ExpiringSoon).Count))" {
                            if (@($credentialSummary.ExpiringSoon).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Credentials Expiring In 30 Days' {
                                    New-HTMLTable -DataTable $credentialSummary.ExpiringSoon -Filtering $credentialTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Credentials Expiring In 30 Days' {
                                    New-HTMLText -Text 'No credentials expiring in 30 days were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Long-Lived ($(@($credentialSummary.LongLived).Count))" {
                            if (@($credentialSummary.LongLived).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Long-Lived Credentials' {
                                    New-HTMLTable -DataTable $credentialSummary.LongLived -Filtering $credentialTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Long-Lived Credentials' {
                                    New-HTMLText -Text 'No long-lived credentials were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Federated ($(@($credentialSummary.Federated).Count))" {
                            if (@($credentialSummary.Federated).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Federated Identity Credentials' {
                                    New-HTMLTable -DataTable $credentialSummary.Federated -Filtering $credentialTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Federated Identity Credentials' {
                                    New-HTMLText -Text 'No federated identity credentials were found.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Applications ($(@($credentialSummary.ApplicationSummary).Count))" {
                            if (@($credentialSummary.ApplicationSummary).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Application Credential Summary' {
                                    New-HTMLTable -DataTable $credentialSummary.ApplicationSummary -Filtering -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Application Credential Summary' {
                                    New-HTMLText -Text 'No application credential summary data was generated.' -Color Orange
                                }
                            }
                        }
                        New-HTMLTab -Name "Review Queue ($(@($credentialSummary.ReviewCandidates).Count))" {
                            if (@($credentialSummary.ReviewCandidates).Count -gt 0) {
                                New-HTMLSection -HeaderText 'Credentials Requiring Review' {
                                    New-HTMLTable -DataTable $credentialSummary.ReviewCandidates -Filtering $credentialTableConditions -ScrollX
                                }
                            } else {
                                New-HTMLSection -HeaderText 'Credentials Requiring Review' {
                                    New-HTMLText -Text 'No credentials matched the current review criteria.' -Color Orange
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
