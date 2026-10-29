BeforeAll {
    Import-Module PSWriteHTML -RequiredVersion 1.41.0 -ErrorAction Stop
    $repository = Split-Path -Parent $PSScriptRoot
    foreach ($file in Get-ChildItem (Join-Path $repository 'Private') -Filter '*.ps1') {
        . $file.FullName
    }
    foreach ($file in Get-ChildItem (Join-Path $repository 'Public') -Filter '*.ps1') {
        . $file.FullName
    }

    function Get-GitHubVersion { param($Cmdlet, $RepositoryOwner, $RepositoryName) 'test' }
    function Write-Color { }
    function Start-TimeLog { Get-Date }
    function Stop-TimeLog { param($Time, $Option) 'test duration' }
    function Copy-Dictionary { param($Dictionary) @{} }
    function Remove-EmptyValue {
        param($Hashtable)
        foreach ($key in @($Hashtable.Keys)) {
            if (-not $Hashtable[$key]) { $Hashtable.Remove($key) }
        }
    }
}

Describe 'Safe report collection' {
    BeforeEach {
        $issues = [System.Collections.Generic.List[object]]::new()
    }

    It 'keeps partial data and records a nonterminating collection error without its response body' {
        $result = @(Invoke-GraphEssentialsReportCollection -Name 'Users' -Issues $issues -Collect {
            [pscustomobject]@{ Id = 'user-1' }
            Write-Error '403 Forbidden response contains synthetic-secret-value'
        })
        $result.Count | Should -Be 1
        $result[0].Id | Should -Be 'user-1'
        $issues.Count | Should -Be 1
        $issues[0].Type | Should -Be 'Error'
        $issues | ConvertTo-Json | Should -Not -Match 'synthetic-secret-value'
    }

    It 'captures a warning even when the caller suppresses console warnings' {
        $null = Invoke-GraphEssentialsReportCollection -Name 'Licences' -Issues $issues -WarningAction SilentlyContinue -Collect {
            Write-Warning 'Licence missing; synthetic-secret-value'
        }
        $issues.Count | Should -Be 1
        $issues[0].Type | Should -Be 'Warning'
        $issues | ConvertTo-Json | Should -Not -Match 'synthetic-secret-value'
    }

    It 'records a thrown 403 without emitting the error or credential text' {
        $output = @(Invoke-GraphEssentialsReportCollection -Name 'Sensors' -Issues $issues -Collect {
            throw '403 Forbidden synthetic-secret-value'
        } *>&1)
        $output.Count | Should -Be 0
        $issues.Count | Should -Be 1
        $issues[0].Comment | Should -Match 'permissions.*licences.*throttling'
        $issues | ConvertTo-Json | Should -Not -Match 'synthetic-secret-value'
    }

    It 'records the legacy false failure sentinel without treating empty success as failure' {
        $null = Invoke-GraphEssentialsReportCollection -Name 'Health' -Issues $issues -Collect { $false }
        $issues.Count | Should -Be 1
        $issues.Clear()
        $null = Invoke-GraphEssentialsReportCollection -Name 'Health' -Issues $issues -Collect { @() }
        $issues.Count | Should -Be 0
    }
}

Describe 'Report entry point security' {
    BeforeEach {
        Mock Get-GitHubVersion { 'test' }
        Mock Get-MyDefenderHealthIssues { @() }
        Mock Get-MyDefenderSecureScore { @() }
        Mock Get-MyDefenderSensor { [pscustomobject]@{ DisplayName = 'sensor-1' } }
    }

    It 'never collects or emits the Defender deployment key from a mocked key response' {
        Mock Get-MyDefenderDeploymentKey { [pscustomobject]@{ DeploymentAccessKey = 'synthetic-deployment-secret'; DownloadUrl = 'https://example.test' } }
        $path = Join-Path $TestDrive 'defender.html'
        $streams = Show-MyDefender -FilePath $path -Verbose -Debug *>&1
        Get-Content $path -Raw | Should -Not -Match 'synthetic-deployment-secret|DeploymentAccessKey|Defender Deployment Key'
        Get-Content $path -Raw | Should -Match 'sensor-1'
        $streams | Out-String | Should -Not -Match 'synthetic-deployment-secret'
        $Script:Reporting | ConvertTo-Json -Depth 10 | Should -Not -Match 'synthetic-deployment-secret'
        Should -Invoke Get-MyDefenderDeploymentKey -Times 0 -Exactly
    }

    It 'writes a visible Defender failure notice and retains successful sensor data' {
        Mock Get-MyDefenderHealthIssues { throw '403 Forbidden' }
        $path = Join-Path $TestDrive 'defender-failed.html'
        Show-MyDefender -FilePath $path -WarningAction SilentlyContinue
        $html = Get-Content $path -Raw
        $html | Should -Match '(?s)<header>.*Collection notice - report may be incomplete.*</header>'
        $html | Should -Match 'Get-MyDefenderHealthIssues'
        $html | Should -Match 'sensor-1'
    }

    It 'writes a visible notice for standalone <Command>' -ForEach @(
        @{ Command = 'Show-MyApp'; Collector = 'Get-MyApp' }
        @{ Command = 'Show-MyConditionalAccess'; Collector = 'Get-MyConditionalAccess' }
        @{ Command = 'Show-MyRole'; Collector = 'Get-MyRole' }
        @{ Command = 'Show-MyUserAuthentication'; Collector = 'Get-MyUserAuthentication' }
    ) {
        # Each endpoint fails here so a regression cannot silently fall through to an empty report.
        foreach ($collectorName in @('Get-MyApp', 'Get-MyAppCredentials', 'Get-MyConditionalAccess', 'Get-MyAuthenticationStrength', 'Get-MyRole', 'Get-MyRoleUsers', 'Get-MyRoleHistory', 'Get-MyUserAuthentication', 'Get-MyAuthenticationMethodsPolicy')) {
            Mock $collectorName { throw '403 Forbidden' }
        }
        $path = Join-Path $TestDrive "$Command.html"
        & $Command -FilePath $path -WarningAction SilentlyContinue
        $html = Get-Content $path -Raw
        $html | Should -Match '(?s)<header>.*Collection notice - report may be incomplete.*</header>'
        $html | Should -Match $Collector
    }

    It 'shows dispatcher failures with diagnostic switches <Mode> and split mode <Split>' -ForEach @(
        @{ Mode = 'Off'; Switches = @{}; Split = $false; Stream = $true }
        @{ Mode = 'On'; Switches = @{ ShowWarning = $true; ShowError = $true }; Split = $false; Stream = $true }
        @{ Mode = 'Off'; Switches = @{}; Split = $true; Stream = $false }
    ) {
        $Script:DefaultTypes = $null
        $Script:GraphEssentialsConfiguration = [ordered]@{
            Test = @{
                Enabled = $true; Name = 'Test inventory'; Variables = @{}
                Execute = { if ($Stream) { Write-Error '403 Forbidden synthetic-deployment-secret' } else { throw '403 Forbidden synthetic-deployment-secret' } }
                Processing = { }; Summary = $null
                Solution = { New-HTMLText -Text 'Inventory table' }
            }
        }
        $path = Join-Path $TestDrive 'inventory.html'
        $result = Invoke-MyGraphEssentials -Type Test -FilePath $path -PassThru -HideHTML -SplitReports:$Split @Switches -WarningAction SilentlyContinue
        $result.Test.WarningsAndErrors.Count | Should -Be 1
        $result | ConvertTo-Json -Depth 10 | Should -Not -Match 'synthetic-deployment-secret'
        $files = @(Get-ChildItem $TestDrive -Filter 'inventory*.html')
        $files.Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            Get-Content $file.FullName -Raw | Should -Match '(?s)<header>.*Collection notice - report may be incomplete.*</header>'
        }
    }

    It 'shows usage collection failures in HTML and returned objects' {
        Mock Get-MyUsageReports { Write-Warning '429 throttled'; @() }
        $path = Join-Path $TestDrive 'usage.html'
        $result = Invoke-MyGraphUsageReports -Period 30 -Report EmailActivityCounts -FilePath $path -DontSuppress -HideHTML
        Should -Invoke Get-MyUsageReports -Times 1 -Exactly
        $result.CollectionIssues.Count | Should -Be 1
        Get-Content $path -Raw | Should -Match '(?s)<header>.*Collection notice - report may be incomplete.*</header>'
        Get-Content $path -Raw | Should -Match 'EmailActivityCounts'
    }

    It 'shows guest policy failures collected by the summary in the persistent header' {
        $Script:DefaultTypes = $null
        $Script:GraphEssentialsConfiguration = [ordered]@{ Guests = $Script:Guests }
        Mock Get-MyGuest { @() }
        Mock Get-MyAuthenticationMethodsPolicy { throw '403 Forbidden synthetic-secret-value' }
        Mock Get-MyTermsOfUse { @() }
        Mock Get-MyCrossTenantAccess { $null }
        Mock Get-MyConditionalAccess { @() }
        $path = Join-Path $TestDrive 'guest-policy.html'
        $result = Invoke-MyGraphEssentials -Type Guests -FilePath $path -HideHTML -PassThru
        $result.Guests.WarningsAndErrors.Count | Should -Be 1
        Get-Content $path -Raw | Should -Match '(?s)<header>.*Guests summary.*Collection reported a problem.*</header>'
        Get-Content $path -Raw | Should -Not -Match 'synthetic-secret-value'
    }

    It 'reports denied federated credential collection while retaining ordinary credential metadata' {
        function Get-MgApplicationFederatedIdentityCredential { [CmdletBinding()] param($ApplicationId, [switch] $All) }
        Mock Get-MgApplicationFederatedIdentityCredential { throw '403 Forbidden synthetic-secret-value' }
        $application = [pscustomobject]@{
            Id = 'application-1'; AppId = 'client-1'; DisplayName = 'Example app'
            PasswordCredentials = @([pscustomobject]@{
                DisplayName = 'Metadata only'; KeyId = 'credential-1'
                StartDateTime = (Get-Date).AddDays(-1); EndDateTime = (Get-Date).AddDays(30)
            })
            KeyCredentials = @()
        }
        $issues = [System.Collections.Generic.List[object]]::new()
        $data = @(Invoke-GraphEssentialsReportCollection -Name 'Credentials' -Issues $issues -Collect {
            Get-MyAppCredentials -ApplicationList @($application) -IncludeFederated
        })
        $data.Count | Should -Be 1
        $data[0].KeyId | Should -Be 'credential-1'
        $issues.Count | Should -Be 1
        Should -Invoke Get-MgApplicationFederatedIdentityCredential -Times 1 -Exactly
        $issues | ConvertTo-Json | Should -Not -Match 'synthetic-secret-value'
    }

    It 'does not mark successful unfiltered period usage collection as a failure' {
        function Invoke-MgGraphRequest { [CmdletBinding()] param($Method, $Uri, $ContentType, $OutputFilePath) }
        Mock Invoke-MgGraphRequest {
            Set-Content -LiteralPath $OutputFilePath -Value "Count`r`n42" -Encoding Unicode
        }
        $path = Join-Path $TestDrive 'usage-activation-period.html'
        $result = Invoke-MyGraphUsageReports -Period 30 -Report Office365ActivationCounts -FilePath $path -DontSuppress -HideHTML
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/reports/getOffice365ActivationCounts' }
        $result.Reports['Office365ActivationCounts'][0].Count | Should -Be '42'
        $result.CollectionIssues.Count | Should -Be 0
        $result.SelectionNotices.Count | Should -Be 1
        Get-Content $path -Raw | Should -Match 'response contains all available data'
    }

    It 'labels successful date fallback as D7 without a collection failure for <Report>' -ForEach @(
        @{ Report = 'MailboxUsageDetail' }
        @{ Report = 'EmailActivityCounts' }
        @{ Report = 'SharePointActivityPages' }
        @{ Report = 'OneDriveUsageStorage' }
    ) {
        function Invoke-MgGraphRequest { [CmdletBinding()] param($Method, $Uri, $ContentType, $OutputFilePath) }
        Mock Invoke-MgGraphRequest {
            Set-Content -LiteralPath $OutputFilePath -Value "Count`r`n42" -Encoding Unicode
        }
        $path = Join-Path $TestDrive "$Report-date.html"
        $result = Invoke-MyGraphUsageReports -DateTime '2026-10-20' -Report $Report -FilePath $path -DontSuppress -HideHTML
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -match "get$Report\(period='D7'\)$" }
        $result.Reports[$Report][0].Count | Should -Be '42'
        $result.CollectionIssues.Count | Should -Be 0
        $result.SelectionNotices.Count | Should -Be 1
        $html = Get-Content $path -Raw
        $html | Should -Match '(?s)<header>.*Report selection notice.*</header>'
        $html | Should -Match 'period D7 \(the last 7 days\)'
        $html | Should -Not -Match 'Collection notice - report may be incomplete'
    }

    It 'discloses an ignored date for <Report> as unfiltered data' -ForEach @(
        @{ Report = 'Office365ActivationCounts' }
        @{ Report = 'Office365ActivationsUserCounts' }
        @{ Report = 'Office365ActivationsUserDetail' }
    ) {
        function Invoke-MgGraphRequest { [CmdletBinding()] param($Method, $Uri, $ContentType, $OutputFilePath) }
        Mock Invoke-MgGraphRequest {
            Set-Content -LiteralPath $OutputFilePath -Value "Count`r`n42" -Encoding Unicode
        }
        $warnings = @()
        $null = Get-MyUsageReports -DateTime '2026-10-20' -Report $Report -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings.Count | Should -Be 1
        $warnings[0] | Out-String | Should -Match 'does not support filtering'
        $path = Join-Path $TestDrive "$Report-date.html"
        $result = Invoke-MyGraphUsageReports -DateTime '2026-10-20' -Report $Report -FilePath $path -DontSuppress -HideHTML
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly -ParameterFilter { $Uri -eq "https://graph.microsoft.com/v1.0/reports/get$Report" }
        $result.Reports[$Report][0].Count | Should -Be '42'
        $result.CollectionIssues.Count | Should -Be 0
        $result.SelectionNotices.Count | Should -Be 1
        $html = Get-Content $path -Raw
        $html | Should -Match '(?s)<header>.*Report selection notice.*</header>'
        $html | Should -Match 'response contains all available data'
        $html | Should -Not -Match 'Collection notice - report may be incomplete'
    }

    It 'keeps a real Graph failure visible alongside a date fallback notice' {
        function Invoke-MgGraphRequest { [CmdletBinding()] param($Method, $Uri, $ContentType, $OutputFilePath) }
        Mock Invoke-MgGraphRequest { throw '403 Forbidden synthetic-secret-value' }
        $path = Join-Path $TestDrive 'usage-fallback-403.html'
        $result = Invoke-MyGraphUsageReports -DateTime '2026-10-20' -Report MailboxUsageDetail -FilePath $path -DontSuppress -HideHTML
        $result.SelectionNotices.Count | Should -Be 1
        $result.CollectionIssues.Count | Should -BeGreaterThan 0
        $html = Get-Content $path -Raw
        $html | Should -Match '(?s)<header>.*Report selection notice.*Collection notice - report may be incomplete.*</header>|(?s)<header>.*Collection notice - report may be incomplete.*Report selection notice.*</header>'
        $html | Should -Match '<div(?=[^>]*class="[^"]*graphEssentialsReportNoticeWarning)(?=[^>]*role="alert")[^>]*>'
        $html | Should -Match '<div(?=[^>]*class="[^"]*graphEssentialsReportNoticeInformation)(?=[^>]*role="note")[^>]*>'
        $html | Should -Match 'Warning: Collection notice - report may be incomplete'
        $html | Should -Not -Match 'synthetic-secret-value'
    }
}
