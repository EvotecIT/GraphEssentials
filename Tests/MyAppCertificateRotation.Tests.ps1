BeforeAll {
    $rotationRoot = Split-Path -Parent $PSScriptRoot
    foreach ($folder in @('Private', 'Public')) {
        Get-ChildItem -LiteralPath (Join-Path $rotationRoot $folder) -Filter '*MyAppCertificateRotation*.ps1' -File | ForEach-Object {
            . $_.FullName
        }
    }
    function Get-MgContext {}
    function Get-MgRequestContext {}
    function Set-MgRequestContext {
        [CmdletBinding(SupportsShouldProcess)]
        param($MaxRetry)
    }
    function Invoke-MgGraphRequest {
        [CmdletBinding()]
        param($Method, $Uri, $Body, $ContentType, $Headers)
    }
    function Get-MgApplication {
        [CmdletBinding()]
        param($ApplicationId, $Property)
    }
    function Assert-RotationJwt {
        param($Jwt, $Certificate, $Issuer, $Audience, $LifetimeSeconds)
        $parts = $Jwt.Split('.')
        $decoded = foreach ($part in $parts) {
            $value = $part.Replace('-', '+').Replace('_', '/')
            $value += '=' * ((4 - $value.Length % 4) % 4)
            , [Convert]::FromBase64String($value)
        }
        $header = [Text.Encoding]::UTF8.GetString($decoded[0]) | ConvertFrom-Json
        $payload = [Text.Encoding]::UTF8.GetString($decoded[1]) | ConvertFrom-Json
        $header.alg | Should -Be 'RS256'
        $payload.iss | Should -Be $Issuer
        $payload.aud | Should -Be $Audience
        ($payload.exp - $payload.nbf) | Should -BeGreaterThan 0
        ($payload.exp - $payload.nbf) | Should -BeLessOrEqual $LifetimeSeconds
        $payload.exp | Should -BeLessOrEqual ([datetimeoffset] $Certificate.NotAfter.ToUniversalTime()).ToUnixTimeSeconds()
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
        try {
            $rsa.VerifyData([Text.Encoding]::UTF8.GetBytes($parts[0] + '.' + $parts[1]), $decoded[2],
                [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) | Should -BeTrue
        } finally {
            $rsa.Dispose()
        }
    }
    function Set-RotationOverlapElapsed {
        $state = Read-MyAppCertificateRotationState -Path $script:Profile
        $state.ActivatedAtUtc = [datetimeoffset]::UtcNow.AddDays(-2).ToString('o')
        $state.RetireAfterUtc = ([datetimeoffset] $state.ActivatedAtUtc).AddSeconds($state.Policy.OverlapSeconds).ToString('o')
        Save-MyAppCertificateRotationState -Path $script:Profile -State $state
    }
}

Describe 'Opt-in application certificate rotation' {
    BeforeEach {
        $script:Profile = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:Tenant = [guid]::NewGuid().ToString('D')
        $script:Client = [guid]::NewGuid().ToString('D')
        $script:ObjectId = [guid]::NewGuid().ToString('D')
        $script:OldId = [guid]::NewGuid().ToString('D')
        $script:NewId = [guid]::NewGuid().ToString('D')
        $script:CurrentRetry = 3
        $script:RequestContext = [pscustomobject] @{ MaxRetry = $script:CurrentRetry }
        $script:ServerKeys = @()
        $script:FailToken = $false
        $script:LoseAdd = $false
        $script:LoseRemove = $false
        $script:Old = New-MyAppCertificateRotationCertificate -ClientId $script:Client -Lifetime ([timespan]::FromDays(7))
        $script:ServerKeys = @([pscustomobject] @{ KeyId = $script:OldId; Key = $script:Old.RawData })
        $null = Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:OldId -Certificate $script:Old -Confirm:$false
        Mock Get-MgContext { [pscustomobject] @{ TenantId = $script:Tenant; ClientId = $script:Client; AuthType = 'AppOnly'; Environment = 'Global' } }
        Mock Get-MgRequestContext { $script:RequestContext }
        Mock Set-MgRequestContext {
            $script:CurrentRetry = $MaxRetry
            $script:RequestContext.MaxRetry = $MaxRetry
        }
        Mock Get-MgApplication { [pscustomobject] @{ Id = $script:ObjectId; AppId = $script:Client; KeyCredentials = $script:ServerKeys } }
        Mock Invoke-RestMethod {
            $state = Read-MyAppCertificateRotationState -Path $script:Profile
            $credential = $state.Pending
            if ($state.Phase -eq 'Overlap') {
                $credential = $state.Active
            }
            $certificate = Import-MyAppCertificateRotationCredential -Credential $credential
            try {
                Assert-RotationJwt -Jwt $Body.client_assertion -Certificate $certificate -Issuer $script:Client -Audience $Uri -LifetimeSeconds 300
            } finally {
                $certificate.Dispose()
            }
            $Body.ContainsKey('client_secret') | Should -BeFalse
            if ($script:FailToken) {
                throw 'sensitive-token-endpoint-error'
            }
            @{ access_token = 'synthetic-token' }
        }
        Mock Invoke-MgGraphRequest {
            $script:CurrentRetry | Should -Be 0
            $Method | Should -Be 'POST'
            $state = Read-MyAppCertificateRotationState -Path $script:Profile
            $payload = $Body | ConvertFrom-Json
            $Headers.'client-request-id' | Should -Be $state.OperationId
            if ($Uri.EndsWith('/addKey')) {
                $Uri | Should -Be "/v1.0/applications(appId='$script:Client')/addKey"
                $state.Phase | Should -Be 'Registering'
                Assert-RotationJwt -Jwt $payload.proof -Certificate $script:Old -Issuer $script:ObjectId -Audience '00000002-0000-0000-c000-000000000000' -LifetimeSeconds 600
                $replacement = Import-MyAppCertificateRotationCredential -Credential $state.Pending
                try {
                    $payload.keyCredential.key | Should -Be ([Convert]::ToBase64String($replacement.RawData))
                    $replacement.Thumbprint | Should -Not -Be $script:Old.Thumbprint
                } finally {
                    $replacement.Dispose()
                }
                $payload.keyCredential.type | Should -Be 'AsymmetricX509Cert'
                $payload.keyCredential.usage | Should -Be 'Verify'
                $payload.passwordCredential | Should -BeNullOrEmpty
                $script:ServerKeys += [pscustomobject] @{ KeyId = $script:NewId; Key = [Convert]::FromBase64String($payload.keyCredential.key) }
                if ($script:LoseAdd) {
                    throw 'response lost after registration'
                }
                @{ keyId = $script:NewId }
            } else {
                $state.Phase | Should -Be 'Retiring'
                $payload.keyId | Should -Be $script:OldId
                $active = Import-MyAppCertificateRotationCredential -Credential $state.Active
                try {
                    Assert-RotationJwt -Jwt $payload.proof -Certificate $active -Issuer $script:ObjectId -Audience '00000002-0000-0000-c000-000000000000' -LifetimeSeconds 600
                } finally {
                    $active.Dispose()
                }
                $script:ServerKeys = @($script:ServerKeys | Where-Object KeyId -NE $script:OldId)
                if ($script:LoseRemove) {
                    throw 'response lost after retirement'
                }
            }
        }
    }

    AfterEach {
        if ($script:Old) {
            $script:Old.Dispose()
        }
    }

    It 'protects the enrolled software key and returns only safe status unless a certificate is explicitly requested' {
        $status = Get-MyAppCertificateRotation -Path $script:Profile
        $status.ActiveThumbprint | Should -Be $script:Old.Thumbprint
        ($status | ConvertTo-Json) | Should -Not -Match 'Pfx|client_assertion|access_token'
        $file = Join-Path $script:Profile 'rotation.dpapi'
        [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($file)) | Should -Not -Match 'TenantId|Pfx|private'
        $certificate = Get-MyAppCertificateRotation -Path $script:Profile -AsCertificate
        try {
            $certificate.HasPrivateKey | Should -BeTrue
            $certificate.Thumbprint | Should -Be $script:Old.Thumbprint
        } finally {
            $certificate.Dispose()
        }
        $acl = Get-Acl -LiteralPath $script:Profile
        $acl.AreAccessRulesProtected | Should -BeTrue
    }

    It 'registers and freshly verifies a replacement then retires only the old key after overlap' {
        $result = Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false
        $result.Action | Should -Be 'Activated'
        $result.ActiveKeyId | Should -Be $script:NewId
        $script:ServerKeys.Count | Should -Be 2
        (Invoke-MyAppCertificateRotation -Path $script:Profile).Action | Should -Be 'Overlap'
        Set-RotationOverlapElapsed
        $result = Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false
        $result.Action | Should -Be 'Retired'
        $result.Phase | Should -Be 'Idle'
        $script:ServerKeys.Count | Should -Be 1
        $script:ServerKeys[0].KeyId | Should -Be $script:NewId
        (Invoke-MyAppCertificateRotation -Path $script:Profile).Action | Should -Be 'NotDue'
        $script:CurrentRetry | Should -Be 3
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }

    It 'does not generate credentials contact Graph or change any files during WhatIf' {
        $file = Join-Path $script:Profile 'rotation.dpapi'
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
        $null = Invoke-MyAppCertificateRotation -Path $script:Profile -WhatIf
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) | Should -Be $before
        Test-Path -LiteralPath (Join-Path $script:Profile 'rotation.lock') | Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        $newPath = Join-Path $TestDrive 'not-created'
        Register-MyAppCertificateRotation -Path $newPath -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:OldId -Certificate $script:Old -WhatIf
        Test-Path -LiteralPath $newPath | Should -BeFalse
    }

    It 'holds a lost registration response and resumes only after matching public certificate reconciliation' {
        $script:LoseAdd = $true
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw '*Reconcile*'
        (Get-MyAppCertificateRotation -Path $script:Profile).RequiresReconciliation | Should -BeTrue
        $script:CurrentRetry | Should -Be 3
        (Invoke-MyAppCertificateRotation -Path $script:Profile).Action | Should -Be 'ReconciliationRequired'
        $null = Invoke-MyAppCertificateRotation -Path $script:Profile -Reconcile -Confirm:$false
        (Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false).Action | Should -Be 'Activated'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
    }

    It 'keeps the previous credential active when fresh replacement authentication fails' {
        $script:FailToken = $true
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw '*Fresh certificate authentication failed*'
        $status = Get-MyAppCertificateRotation -Path $script:Profile
        $status.Phase | Should -Be 'Registered'
        $status.ActiveKeyId | Should -Be $script:OldId
        $script:FailToken = $false
        (Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false).Action | Should -Be 'Activated'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
    }

    It 'reconciles a lost retirement response without repeating the remote removal' {
        $null = Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false
        Set-RotationOverlapElapsed
        $script:LoseRemove = $true
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw '*Reconcile*'
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase | Should -Be 'Retiring'
        $script:ServerKeys.Count | Should -Be 1
        $null = Invoke-MyAppCertificateRotation -Path $script:Profile -Reconcile -Confirm:$false
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase | Should -Be 'Idle'
        Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
    }

    It 'keeps a registration hold when no unique matching public certificate is visible' {
        $script:LoseAdd = $true
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw
        $script:ServerKeys = @($script:ServerKeys | Where-Object KeyId -EQ $script:OldId)
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Reconcile -Confirm:$false } | Should -Throw '*unique matching replacement*'
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase | Should -Be 'Registering'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
    }

    It 'refuses maintenance under a mismatched <ContextField> before staging or contacting Graph' -ForEach @(
        @{ ContextField = 'TenantId'; Value = '00000000-0000-0000-0000-000000000001' }
        @{ ContextField = 'ClientId'; Value = '00000000-0000-0000-0000-000000000002' }
        @{ ContextField = 'AuthType'; Value = 'Delegated' }
        @{ ContextField = 'Environment'; Value = 'USGov' }
    ) {
        $script:WrongField = $ContextField
        $script:WrongValue = $Value
        Mock Get-MgContext {
            $context = [pscustomobject] @{ TenantId = $script:Tenant; ClientId = $script:Client; AuthType = 'AppOnly'; Environment = 'Global' }
            $context.($script:WrongField) = $script:WrongValue
            $context
        }
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:Profile 'rotation.dpapi')))
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw
        [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:Profile 'rotation.dpapi'))) | Should -Be $before
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'keeps a reader snapshot usable while an atomic checkpoint save completes' {
        $file = Join-Path $script:Profile 'rotation.dpapi'
        $before = [IO.File]::ReadAllBytes($file)
        $snapshot = Open-MyAppCertificateRotationSnapshot -Path $script:Profile
        $buffer = [IO.MemoryStream]::new()
        try {
            $state = Read-MyAppCertificateRotationState -Path $script:Profile
            $completed = '2026-10-01T12:00:00.0000000Z'
            $state.LastCompletedAtUtc = $completed
            Save-MyAppCertificateRotationState -Path $script:Profile -State $state
            (Get-MyAppCertificateRotation -Path $script:Profile).LastCompletedAtUtc | Should -Be ([datetimeoffset] $completed)
            $snapshot.CopyTo($buffer)
            [Convert]::ToBase64String($buffer.ToArray()) | Should -Be ([Convert]::ToBase64String($before))
            Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        } finally {
            $buffer.Dispose()
            $snapshot.Dispose()
        }
    }

    It 'refuses a competing process lease without changing the saved profile' {
        $lease = Open-MyAppCertificateRotationLock -Path $script:Profile
        try {
            { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw '*profile lock*'
            (Get-MyAppCertificateRotation -Path $script:Profile).Phase | Should -Be 'Idle'
            Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        } finally {
            $lease.Dispose()
        }
    }

    It 'retains the durable registration intent when saving its accepted response fails' {
        $file = Join-Path $script:Profile 'rotation.dpapi'
        Mock Invoke-MgGraphRequest {
            (Get-Item -LiteralPath (Join-Path $script:Profile 'rotation.dpapi')).IsReadOnly = $true
            @{ keyId = $script:NewId }
        }
        try {
            { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw
        } finally {
            (Get-Item -LiteralPath $file).IsReadOnly = $false
        }
        (Get-MyAppCertificateRotation -Path $script:Profile).Phase | Should -Be 'Registering'
        $script:CurrentRetry | Should -Be 3
        (Invoke-MyAppCertificateRotation -Path $script:Profile).Action | Should -Be 'ReconciliationRequired'
        Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
    }

    It 'rejects tampered protected state before any authentication or Graph request' {
        $file = Join-Path $script:Profile 'rotation.dpapi'
        $bytes = [IO.File]::ReadAllBytes($file)
        $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 1
        [IO.File]::WriteAllBytes($file, $bytes)
        { Get-MyAppCertificateRotation -Path $script:Profile } | Should -Throw
        { Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false } | Should -Throw
        Should -Invoke Invoke-MgGraphRequest -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'never overwrites an enrolled profile and retains an independently usable active certificate after maintenance' {
        { Register-MyAppCertificateRotation -Path $script:Profile -TenantId $script:Tenant -ClientId $script:Client -ApplicationObjectId $script:ObjectId -KeyId $script:OldId -Certificate $script:Old -Confirm:$false } | Should -Throw '*already exists*'
        $held = Get-MyAppCertificateRotation -Path $script:Profile -AsCertificate
        try {
            $null = Invoke-MyAppCertificateRotation -Path $script:Profile -Confirm:$false
            $proof = New-MyAppCertificateRotationJwt -Certificate $held -Issuer $script:ObjectId -Audience '00000002-0000-0000-c000-000000000000'
            Assert-RotationJwt -Jwt $proof -Certificate $script:Old -Issuer $script:ObjectId -Audience '00000002-0000-0000-c000-000000000000' -LifetimeSeconds 600
        } finally {
            $held.Dispose()
        }
    }
}
