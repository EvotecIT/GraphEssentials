function Invoke-MyAppCertificateSession {
    <#
    .SYNOPSIS
    Runs a workload with the active certificate from an opt-in renewal profile.
    .DESCRIPTION
    Uses the existing certificate only to enroll a new profile. Later runs load the profile's
    active certificate, connect, maintain renewal and reconnect after activation before invoking
    the workload. Owns its Graph connection and loaded certificate until the workload completes.
    Disabled configuration passes the original connection map to the workload without accessing
    credentials or Graph. Bootstrap and maintenance honor WhatIf; ordinary workload reads can run.
    .PARAMETER ConnectionParameters
    Existing Graph connection settings, including TenantId and ClientId (or AppId). Certificate
    or CertificateThumbprint is required only for enrollment. Secret/access-token connections
    cannot be combined with enabled certificate rotation. The supplied map is never modified.
    .PARAMETER Rotation
    JSON-friendly map: Enabled (false by default), ProfilePath, optional bootstrap
    ApplicationObjectId/KeyId and CertificateLifetimeDays/RenewBeforeDays/OverlapDays.
    The bootstrap identifiers are required only when creating a new profile.
    .PARAMETER ConfigurationDirectory
    Base directory for a relative ProfilePath. Required unless ProfilePath is absolute.
    .PARAMETER ScriptBlock
    Workload called with the effective connection map and a safe maintenance summary. A loaded
    Certificate remains valid only inside this callback. Do not retain it or start background work.
    .PARAMETER OnEvent
    Optional logging callback receiving Event, Message and public Data. It receives no private
    certificate, assertion, token or raw provider error. Without it, events use Information.
    .EXAMPLE
    Invoke-MyAppCertificateSession -ConnectionParameters $graph -Rotation $settings.CertificateRotation -ConfigurationDirectory $configDirectory -ScriptBlock { param($connection, $status) Get-MyDirectoryUser }
    Connects and maintains an enrolled identity, then runs the workload with the active credential.
    .OUTPUTS
    The workload's output. Session events and ordinary status contain no private credentials.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.IDictionary] $ConnectionParameters,
        [System.Collections.IDictionary] $Rotation,
        [string] $ConfigurationDirectory,
        [Parameter(Mandatory)][scriptblock] $ScriptBlock,
        [scriptblock] $OnEvent
    )
    try {
        $options = Resolve-MyAppCertificateSessionOptions -Configuration $Rotation -ConfigurationDirectory $ConfigurationDirectory
    } catch {
        Write-MyAppCertificateSessionEvent -Event RotationFailed -Message 'Certificate session configuration is invalid; no credential or Graph operation was started.' -Data @{ Stage = 'Configuration'; Code = 'RotationConfigurationInvalid' } -OnEvent $OnEvent
        throw
    }
    $effective = @{}
    foreach ($key in $ConnectionParameters.Keys) { $effective[$key] = $ConnectionParameters[$key] }
    if (-not $options.Enabled) {
        Write-MyAppCertificateSessionEvent -Event RotationDisabled -Message 'Certificate rotation is disabled; existing authentication is unchanged.' -OnEvent $OnEvent
        & $ScriptBlock $effective $null
        return
    }
    try {
    $tenant = [guid]::Empty
    $client = [guid]::Empty
    $clientValue = if ($effective.ClientId) { $effective.ClientId } else { $effective.AppId }
    if (-not [guid]::TryParse([string] $effective.TenantId, [ref] $tenant) -or $tenant -eq [guid]::Empty -or
        -not [guid]::TryParse([string] $clientValue, [ref] $client) -or $client -eq [guid]::Empty) {
        throw 'Certificate rotation requires tenant and application client GUIDs.'
    }
    foreach ($name in @('AccessToken', 'ClientSecret', 'ClientSecretEncrypted', 'ClientSecretCredential', 'Identity', 'MgGraph')) {
        if ($effective[$name]) { throw 'Enabled certificate rotation requires a dedicated certificate connection, not a secret, token or reused session.' }
    }
    if ($effective.Environment -and $effective.Environment -ne 'Global') { throw 'Certificate rotation currently supports the Microsoft public cloud only.' }
    } catch {
        Write-MyAppCertificateSessionEvent -Event RotationFailed -Message 'The configured connection cannot be used for certificate rotation; no credential or Graph operation was started.' -Data @{ Stage = 'Configuration'; Code = 'RotationConnectionInvalid' } -OnEvent $OnEvent
        throw
    }
    $preview = -not $PSCmdlet.ShouldProcess("$client in $tenant", 'Enroll or maintain application certificate credentials')
    $certificate = $null
    $ownedBootstrap = $null
    $connected = $false
    $stage = 'Profile'
    $failureCode = 'ProfileLoadFailed'
    $status = $null
    try {
        Write-MyAppCertificateSessionEvent -Event RotationStarting -Message 'Loading the certificate renewal profile.' -Data @{ TenantId = $tenant.ToString(); ClientId = $client.ToString(); Preview = $preview } -OnEvent $OnEvent
        if (Test-Path -LiteralPath $options.Path) {
            $state = Read-MyAppCertificateRotationState -Path $options.Path
            if ([guid] $state.TenantId -ne $tenant -or [guid] $state.ClientId -ne $client -or
                ($options.ApplicationObjectId -and [guid] $state.ApplicationObjectId -ne $options.ApplicationObjectId)) {
                $failureCode = 'ProfileIdentityMismatch'
                throw 'The renewal profile belongs to another application identity.'
            }
            foreach ($pair in @(@('CertificateLifetimeDays', 'CertificateLifetimeSeconds'), @('RenewBeforeDays', 'RenewBeforeSeconds'), @('OverlapDays', 'OverlapSeconds'))) {
                if ($Rotation.Contains($pair[0]) -and $state.Policy.($pair[1]) -ne ([timespan]::FromDays($options.Policy[$pair[0]])).TotalSeconds) {
                    $failureCode = 'ProfilePolicyMismatch'
                    throw 'Configured renewal policy differs from the enrolled profile; do not silently replace its policy.'
                }
            }
            $status = Get-MyAppCertificateRotation -Path $options.Path
            if ($status.RequiresReconciliation) { $failureCode = 'ReconciliationRequired'; throw 'The profile requires explicit read-only reconciliation before maintenance.' }
            if ($state.Phase -eq 'Registered') {
                # addKey has a durable key ID. The pending credential can recover even if the
                # previous certificate expired; maintenance still freshly verifies before activation.
                $certificate = Import-MyAppCertificateRotationCredential -Credential $state.Pending
                Write-MyAppCertificateSessionEvent -Event RotationRecovery -Message 'Resuming authentication of the positively registered replacement; it is not active until fresh verification succeeds.' -Data @{ Thumbprint = $certificate.Thumbprint; Phase = $state.Phase } -OnEvent $OnEvent
            } else {
                $certificate = Get-MyAppCertificateRotation -Path $options.Path -AsCertificate
            }
        } else {
            $stage = 'Enrollment'
            $failureCode = 'EnrollmentFailed'
            if ($options.Policy.CertificateLifetimeDays -le ($options.Policy.RenewBeforeDays + $options.Policy.OverlapDays)) {
                throw 'Certificate lifetime must exceed renewal lead time plus overlap.'
            }
            if (-not $options.ApplicationObjectId -or -not $options.KeyId) { throw 'A new profile requires ApplicationObjectId and KeyId from provisioning.' }
            $bootstrap = $effective.Certificate
            if (-not $bootstrap -and $effective.CertificateThumbprint) {
                $thumbprint = ([string] $effective.CertificateThumbprint).Replace(' ', '')
                if ($thumbprint -notmatch '\A[0-9A-Fa-f]{40}\z') { throw 'Bootstrap certificate thumbprint must contain 40 hexadecimal characters.' }
                foreach ($location in @('CurrentUser', 'LocalMachine')) {
                    $candidate = "Cert:\$location\My\$thumbprint"
                    if (Test-Path -LiteralPath $candidate) { $ownedBootstrap = Get-Item -LiteralPath $candidate -ErrorAction Stop; $bootstrap = $ownedBootstrap; break }
                }
            }
            if ($bootstrap -isnot [Security.Cryptography.X509Certificates.X509Certificate2]) { throw 'A new profile requires its existing valid exportable RSA certificate.' }
            $status = Register-MyAppCertificateRotation -Path $options.Path -TenantId $tenant -ClientId $client -ApplicationObjectId $options.ApplicationObjectId -KeyId $options.KeyId -Certificate $bootstrap -CertificateLifetime ([timespan]::FromDays($options.Policy.CertificateLifetimeDays)) -RenewBefore ([timespan]::FromDays($options.Policy.RenewBeforeDays)) -Overlap ([timespan]::FromDays($options.Policy.OverlapDays)) -WhatIf:$preview -Confirm:$false
            if ($preview) {
                # Copy only for this session; the caller retains ownership of the bootstrap certificate.
                $bytes = $bootstrap.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, '')
                try { $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes, '', [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet) }
                finally { [Array]::Clear($bytes, 0, $bytes.Length) }
            } else {
                $certificate = Get-MyAppCertificateRotation -Path $options.Path -AsCertificate
                Write-MyAppCertificateSessionEvent -Event RotationEnrolled -Message 'Enrolled the existing certificate in the protected profile.' -Data @{ Thumbprint = $status.ActiveThumbprint; ExpiresOn = $status.ActiveExpiresOn } -OnEvent $OnEvent
            }
        }
        $effective.Remove('CertificateThumbprint'); $effective.Remove('AppId'); $effective.Remove('CertificatePath')
        $effective.ClientId = $client.ToString(); $effective.TenantId = $tenant.ToString(); $effective.Certificate = $certificate
        $effective.ContextScope = 'Process'
        $connect = @{ TenantId = $effective.TenantId; ClientId = $effective.ClientId; Certificate = $certificate; ContextScope = 'Process'; NoWelcome = $true }
        $stage = 'GraphConnection'
        $failureCode = 'GraphConnectionFailed'
        $connected = $true
        Connect-MgGraph @connect -ErrorAction Stop | Out-Null
        $context = Get-MgContext -ErrorAction Stop
        if (-not $context -or [string] $context.TenantId -ne $tenant.ToString() -or
            [string] $context.ClientId -ne $client.ToString() -or $context.AuthType -ne 'AppOnly' -or $context.Environment -ne 'Global') {
            throw 'Graph did not establish the expected process-scoped application identity.'
        }
        $stage = 'Maintenance'
        $failureCode = 'MaintenanceFailed'
        if (Test-Path -LiteralPath $options.Path) {
            $status = Invoke-MyAppCertificateRotation -Path $options.Path -WhatIf:$preview -Confirm:$false
            if ($status.RequiresReconciliation) { $failureCode = 'ReconciliationRequired'; throw 'Maintenance requires explicit reconciliation; the protected state was retained.' }
            # Another process may activate a replacement between our load and maintenance lease.
            if ($status.ActiveThumbprint -ne $certificate.Thumbprint) {
                Disconnect-MgGraph -ErrorAction Stop | Out-Null
                $connected = $false
                $certificate.Dispose()
                $certificate = Get-MyAppCertificateRotation -Path $options.Path -AsCertificate
                $effective.Certificate = $certificate; $connect.Certificate = $certificate
                $stage = 'GraphReconnection'
                $failureCode = 'GraphReconnectionFailed'
                $connected = $true
                Connect-MgGraph @connect -ErrorAction Stop | Out-Null
                $context = Get-MgContext -ErrorAction Stop
                if (-not $context -or [string] $context.TenantId -ne $tenant.ToString() -or
                    [string] $context.ClientId -ne $client.ToString() -or $context.AuthType -ne 'AppOnly' -or $context.Environment -ne 'Global') {
                    throw 'Graph did not reconnect the expected application identity.'
                }
            }
            Write-MyAppCertificateSessionEvent -Event RotationStatus -Message "Certificate maintenance: $($status.Action)." -Data @{ Action = $status.Action; Phase = $status.Phase; Thumbprint = $status.ActiveThumbprint; ExpiresOn = $status.ActiveExpiresOn; RenewAfterUtc = $status.RenewAfterUtc; RetireAfterUtc = $status.RetireAfterUtc } -OnEvent $OnEvent
        } else {
            Write-MyAppCertificateSessionEvent -Event RotationPreview -Message 'Enrollment preview only; no profile or Graph credential changes were made.' -OnEvent $OnEvent
        }
        $stage = 'Workload'
        & $ScriptBlock $effective $status
    } catch {
        if ($stage -eq 'Workload') { throw }
        $diagnostic = $failureCode
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $diagnostic += ':HTTP' + [int] $_.Exception.Response.StatusCode }
        Write-MyAppCertificateSessionEvent -Event RotationFailed -Message "Certificate session failed at $stage; the workload was not started. Inspect profile status and provisioning; no credential values are logged." -Data @{ Stage = $stage; Code = $diagnostic; ErrorType = $_.Exception.GetType().Name } -OnEvent $OnEvent
        throw "Certificate session failed at $stage ($diagnostic). Existing profile state is retained; inspect status and use explicit reconciliation if required."
    } finally {
        if ($connected) { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }
        if ($certificate) { $certificate.Dispose() }
        if ($ownedBootstrap) { $ownedBootstrap.Dispose() }
    }
}
