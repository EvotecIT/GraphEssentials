BeforeAll {
    foreach ($folder in @('Private', 'Public')) {
        foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot "../$folder") -Filter '*MyAppCertificate*.ps1') { . $file.FullName }
    }
    function Connect-MgGraph { [CmdletBinding()] param($TenantId, $ClientId, $Certificate, $ContextScope, $NoWelcome) }
    function Disconnect-MgGraph { [CmdletBinding()] param() }
    function Get-MgContext { }
    function Get-MgRequestContext { }
    function Set-MgRequestContext { [CmdletBinding(SupportsShouldProcess)] param($MaxRetry) }
    function Invoke-MgGraphRequest { [CmdletBinding()] param($Method, $Uri, $Body, $ContentType, $Headers) }
    function Set-RegisteredRecoveryFixture {
        $null=Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false
        $rsa=[Security.Cryptography.RSA]::Create(2048)
        $expired=$null;$pending=$null
        try {
            $request=[Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=expired-recovery-fixture',$rsa,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $expired=$request.CreateSelfSigned([datetimeoffset]::UtcNow.AddDays(-2),[datetimeoffset]::UtcNow.AddDays(-1))
            $pending=New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(30))
            $state=Read-MyAppCertificateRotationState -Path $script:Profile
            $state.Active=ConvertTo-MyAppCertificateRotationCredential -Certificate $expired -KeyId $script:KeyId
            $state.Pending=ConvertTo-MyAppCertificateRotationCredential -Certificate $pending -KeyId ([guid]::NewGuid())
            $state.Phase='Registered';$state.OperationId=[guid]::NewGuid().ToString()
            Save-MyAppCertificateRotationState -Path $script:Profile -State $state
            $script:PendingThumbprint=$pending.Thumbprint
        } finally {
            if($expired){$expired.Dispose()};if($pending){$pending.Dispose()};$rsa.Dispose()
        }
        Mock Connect-MgGraph {
            if($Certificate.NotAfter.ToUniversalTime()-le[datetime]::UtcNow){throw 'Expired active credential cannot connect'}
            $script:ConnectedThumbprints.Add($Certificate.Thumbprint)
        }
    }
}

Describe 'Certificate session connection and workload lifetime' {
    BeforeEach {
        $script:Tenant = [guid]::NewGuid().ToString()
        $script:Client = [guid]::NewGuid().ToString()
        $script:ObjectId = [guid]::NewGuid().ToString()
        $script:KeyId = [guid]::NewGuid().ToString()
        $script:Profile = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:Old = New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(30))
        $script:Settings = @{ Enabled = $true; ProfilePath = $script:Profile; ApplicationObjectId = $script:ObjectId; KeyId = $script:KeyId }
        $script:Connection = @{ TenantId = $script:Tenant; ClientId = $script:Client; Certificate = $script:Old }
        $script:ConnectedThumbprints = [Collections.Generic.List[string]]::new()
        $script:Events = [Collections.Generic.List[object]]::new()
        $script:UsedCertificate = $null
        $script:Workloads = 0
        $script:FailAuthentication = $false
        $script:AdvanceDuringConnection = $false
        Mock Connect-MgGraph {
            $script:ConnectedThumbprints.Add($Certificate.Thumbprint)
            if ($script:AdvanceDuringConnection) {
                $script:AdvanceDuringConnection=$false
                Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false|Out-Null
            }
        }
        Mock Disconnect-MgGraph { }
        Mock Get-MgContext { [pscustomobject]@{TenantId=$script:Tenant;ClientId=$script:Client;Environment='Global';AuthType='AppOnly'} }
        Mock Get-MgRequestContext { [pscustomobject]@{MaxRetry=3} }
        Mock Set-MgRequestContext { }
        Mock Invoke-MgGraphRequest { @{keyId=[guid]::NewGuid().ToString()} }
        Mock Invoke-RestMethod {
            if ($script:FailAuthentication) { throw 'provider-private-secret-marker' }
            @{access_token='synthetic-token-never-log'; token_type='Bearer'; expires_in=3600}
        }
        $script:Sink = {param($entry) $script:Events.Add($entry)}
        $script:Workload = {param($effective,$status) $script:Workloads++;$script:UsedCertificate=$effective.Certificate; $effective.Certificate.Thumbprint}
    }
    AfterEach { if ($script:Old) { $script:Old.Dispose() } }

    It 'leaves disabled authentication maps intact without profiles, certificate stores or Graph access' {
        $connection=@{CertificateThumbprint='unchanged';ClientSecret='synthetic-secret'}
        $value=Invoke-MyAppCertificateSession -ConnectionParameters $connection -Rotation @{Enabled=$false;ProfilePath=$script:Profile} -ScriptBlock {param($effective) $effective.CertificateThumbprint} -OnEvent $script:Sink
        $value|Should -Be 'unchanged'
        $connection.ClientSecret|Should -Be 'synthetic-secret'
        Test-Path $script:Profile|Should -BeFalse
        Should -Invoke Connect-MgGraph -Times 0
        Should -Invoke Invoke-MgGraphRequest -Times 0
        $script:Events[0].Event|Should -Be RotationDisabled
        ($script:Events|ConvertTo-Json -Depth 5)|Should -Not -Match 'synthetic-secret'
    }
    It 'enrolls once, connects the active certificate and disposes only its owned credential after workload' {
        $result=Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink
        $result|Should -Be $script:Old.Thumbprint
        $script:Workloads|Should -Be 1
        $script:UsedCertificate.Handle|Should -Be ([intptr]::Zero)
        $script:Old.HasPrivateKey|Should -BeTrue
        (Get-MyAppCertificateRotation -Path $script:Profile).Action|Should -Be Inspect
        Should -Invoke Disconnect-MgGraph -Times 1
        Should -Invoke Invoke-MgGraphRequest -Times 0
        $script:Events.Event|Should -Contain RotationEnrolled
        $script:Events.Event|Should -Contain RotationStatus
    }
    It 'uses the saved active certificate instead of a stale bootstrap thumbprint or missing PFX path' {
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false|Out-Null
        $script:Connection.Remove('Certificate')
        $script:Connection.CertificateThumbprint='invalid-stale-thumbprint'
        $script:Connection.CertificatePath='missing-old.pfx'
        Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation @{Enabled=$true;ProfilePath=$script:Profile} -ScriptBlock $script:Workload -OnEvent $script:Sink|Should -Be $script:Old.Thumbprint
        $script:ConnectedThumbprints[0]|Should -Be $script:Old.Thumbprint
        $script:Connection.CertificateThumbprint|Should -Be 'invalid-stale-thumbprint'
    }
    It 'reconnects with the verified replacement before invoking the workload' {
        $script:Old.Dispose()
        $script:Old=New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(5))
        $script:Connection.Certificate=$script:Old
        $result=Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink
        $result|Should -Not -Be $script:Old.Thumbprint
        $script:ConnectedThumbprints.Count|Should -Be 2
        $script:ConnectedThumbprints[0]|Should -Be $script:Old.Thumbprint
        $script:ConnectedThumbprints[1]|Should -Be $result
        (Get-MyAppCertificateRotation -Path $script:Profile).ActiveThumbprint|Should -Be $result
        Should -Invoke Invoke-MgGraphRequest -Times 1 -ParameterFilter {$Uri-like'*/addKey'}
        Should -Invoke Disconnect-MgGraph -Times 2
        ($script:Events|Where-Object Event -eq RotationStatus).Data.Action|Should -Be Activated
    }
    It 'does not start the workload when replacement authentication fails and logs no provider secret' {
        $script:Old.Dispose()
        $script:Old=New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(5))
        $script:Connection.Certificate=$script:Old
        $script:FailAuthentication=$true
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Maintenance*'
        $script:Workloads|Should -Be 0
        (Get-MyAppCertificateRotation -Path $script:Profile).ActiveThumbprint|Should -Be $script:Old.Thumbprint
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase|Should -Be Registered
        ($script:Events|ConvertTo-Json -Depth 5)|Should -Not -Match 'provider-private-secret-marker|synthetic-token-never-log'
        Should -Invoke Disconnect-MgGraph -Times 1
    }
    It 'reloads an active replacement advanced by another process during connection' {
        $script:Old.Dispose()
        $script:Old=New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(5))
        $script:Connection.Certificate=$script:Old
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false|Out-Null
        $script:AdvanceDuringConnection=$true
        $result=Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink
        $script:ConnectedThumbprints.Count|Should -Be 2
        $result|Should -Not -Be $script:Old.Thumbprint
        $script:ConnectedThumbprints[1]|Should -Be $result
        ($script:Events|Where-Object Event -eq RotationStatus).Data.Action|Should -Be Overlap
        Should -Invoke Invoke-MgGraphRequest -Times 1
    }
    It 'disconnects a failed authentication attempt without starting the workload' {
        Mock Connect-MgGraph { throw 'provider-private-connection-marker' }
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*GraphConnectionFailed*'
        $script:Workloads|Should -Be 0
        Should -Invoke Disconnect-MgGraph -Times 1
        ($script:Events|ConvertTo-Json -Depth 5)|Should -Not -Match 'provider-private-connection-marker'
    }
    It 'rejects another application profile before opening a Graph connection' {
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false|Out-Null
        $script:Connection.ClientId=[guid]::NewGuid().ToString()
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Profile*'
        $script:Workloads|Should -Be 0
        Should -Invoke Connect-MgGraph -Times 0
    }
    It 'holds an uncertain existing profile rather than reconnecting or re-enrolling' {
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false|Out-Null
        $state=Read-MyAppCertificateRotationState -Path $script:Profile
        $pending=New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(30))
        try { $state.Pending=ConvertTo-MyAppCertificateRotationCredential -Certificate $pending }
        finally { $pending.Dispose() }
        $state.OperationId=[guid]::NewGuid().ToString()
        $state.Phase='Registering'
        Save-MyAppCertificateRotationState -Path $script:Profile -State $state
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Profile*'
        (Get-MyAppCertificateRotation -Path $script:Profile).RequiresReconciliation|Should -BeTrue
        Should -Invoke Connect-MgGraph -Times 0
    }
    It 'previews enrollment without creating a profile or mutating Graph while keeping the bootstrap alive' {
        Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink -WhatIf|Should -Be $script:Old.Thumbprint
        Test-Path $script:Profile|Should -BeFalse
        $script:Old.HasPrivateKey|Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -Times 0
        $script:Events.Event|Should -Contain RotationPreview
    }
    It 'releases its certificate and connection when the workload throws' {
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -OnEvent $script:Sink -ScriptBlock {param($effective) $script:UsedCertificate=$effective.Certificate;throw 'workload failure'}}|Should -Throw '*workload failure*'
        $script:UsedCertificate.Handle|Should -Be ([intptr]::Zero)
        Should -Invoke Disconnect-MgGraph -Times 1
        $script:Events.Event|Should -Not -Contain RotationFailed
    }
    It 'rejects enabled client-secret rotation instead of falling back to a different credential' {
        $script:Connection.ClientSecret='synthetic-secret'
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload}|Should -Throw '*not a secret*'
        Should -Invoke Connect-MgGraph -Times 0
        Test-Path $script:Profile|Should -BeFalse
    }
    It 'rejects an explicit policy change to an existing profile before connecting' {
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -Confirm:$false|Out-Null
        $script:Settings.CertificateLifetimeDays=60
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Profile*'
        Should -Invoke Connect-MgGraph -Times 0
    }
    It 'keeps the effective workload connection process scoped even when bootstrap settings request persistence' {
        $script:Connection.ContextScope='CurrentUser'
        $scope=Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -OnEvent $script:Sink -ScriptBlock {param($effective) $effective.ContextScope}
        $scope|Should -Be Process
        $script:Connection.ContextScope|Should -Be CurrentUser
    }
    It 'inherits omitted policy values from an existing profile before validating an explicit matching value' {
        Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:KeyId -Certificate $script:Old -CertificateLifetime ([timespan]::FromDays(90)) -RenewBefore ([timespan]::FromDays(60)) -Overlap ([timespan]::FromDays(1)) -Confirm:$false|Out-Null
        $settings=@{Enabled=$true;ProfilePath=$script:Profile;RenewBeforeDays=60}
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $settings -ScriptBlock $script:Workload -OnEvent $script:Sink|Out-Null}|Should -Not -Throw
        $script:Workloads|Should -Be 1
    }
    It 'resumes a positively registered replacement even after the previous active certificate expires' {
        Set-RegisteredRecoveryFixture
        $value=Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink
        $value|Should -Be $script:PendingThumbprint
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase|Should -Be Overlap
        (Get-MyAppCertificateRotation -Path $script:Profile).ActiveThumbprint|Should -Be $script:PendingThumbprint
        Should -Invoke Invoke-MgGraphRequest -Times 0
        Should -Invoke Invoke-RestMethod -Times 1
    }
    It 'retains registered recovery state and stops the workload when pending authentication still fails' {
        Set-RegisteredRecoveryFixture
        $script:FailAuthentication=$true
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Maintenance*'
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase|Should -Be Registered
        $script:Workloads|Should -Be 0
        Should -Invoke Invoke-MgGraphRequest -Times 0
        Should -Invoke Invoke-RestMethod -Times 1
    }
    It 'logs bounded configuration failures before any credential or Graph access' {
        $invalid=@{Enabled='synthetic-private-value-marker'}
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $invalid -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*Enabled must be true or false*'
        $script:Events[0].Event|Should -Be RotationFailed
        $script:Events[0].Data.Code|Should -Be RotationConfigurationInvalid
        ($script:Events|ConvertTo-Json -Depth 5)|Should -Not -Match 'synthetic-private-value-marker'
        $script:Events.Clear()
        $script:Connection.ClientSecret='synthetic-private-value-marker'
        {Invoke-MyAppCertificateSession -ConnectionParameters $script:Connection -Rotation $script:Settings -ScriptBlock $script:Workload -OnEvent $script:Sink}|Should -Throw '*not a secret*'
        $script:Events[0].Data.Code|Should -Be RotationConnectionInvalid
        ($script:Events|ConvertTo-Json -Depth 5)|Should -Not -Match 'synthetic-private-value-marker'
        Should -Invoke Connect-MgGraph -Times 0
        Test-Path $script:Profile|Should -BeFalse
    }
}
