function Register-MyAppCertificateRotation {
    <#
    .SYNOPSIS
    Enrolls an existing application certificate in an opt-in local renewal profile.

    .DESCRIPTION
    Protects an exportable RSA software certificate and renewal policy with Windows DPAPI CurrentUser.
    Enrollment creates a new dedicated directory with access restricted to the current account and SYSTEM.
    Run enrollment and maintenance as the same Windows account. The supplied certificate must already be
    registered on the application. This command does not create applications, consent permissions or change Graph.
    Use one profile per application identity and enroll only a credential whose retirement you control.

    .PARAMETER Path
    New dedicated local profile directory. Existing directories are never overwritten.
    .PARAMETER TenantId
    Home tenant containing the application registration.
    .PARAMETER ClientId
    Application client ID used for app-only authentication.
    .PARAMETER ApplicationObjectId
    Object ID of the app registration, distinct from its client ID and service principal ID.
    .PARAMETER KeyId
    Graph credential key ID corresponding to Certificate, recorded during provisioning.
    .PARAMETER Certificate
    Existing valid exportable RSA software certificate with its private key. Caller retains ownership.
    .PARAMETER RenewBefore
    Renew when this much certificate lifetime remains. Defaults to 14 days.
    .PARAMETER CertificateLifetime
    Lifetime of each generated replacement certificate. Defaults to 30 days and must exceed RenewBefore plus Overlap.
    .PARAMETER Overlap
    Minimum interval after activation before retiring the previous key. Defaults to one day.
    .EXAMPLE
    Register-MyAppCertificateRotation -Path $profilePath -TenantId $tenantId -ClientId $clientId -ApplicationObjectId $objectId -KeyId $keyId -Certificate $certificate
    Enrolls an existing certificate under the Windows account that runs the scheduled script.
    .OUTPUTS
    System.Management.Automation.PSCustomObject. Safe profile metadata without private keys or tokens.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][guid] $TenantId,
        [Parameter(Mandatory)][guid] $ClientId,
        [Parameter(Mandatory)][guid] $ApplicationObjectId,
        [Parameter(Mandatory)][guid] $KeyId,
        [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [timespan] $RenewBefore = [timespan]::FromDays(14),
        [timespan] $CertificateLifetime = [timespan]::FromDays(30),
        [timespan] $Overlap = [timespan]::FromDays(1)
    )

    $profilePath = Resolve-MyAppCertificateRotationPath -Path $Path
    if ($TenantId -eq [guid]::Empty -or $ClientId -eq [guid]::Empty -or $ApplicationObjectId -eq [guid]::Empty -or $KeyId -eq [guid]::Empty) {
        throw 'Tenant, client, application object and credential key IDs must be nonempty.'
    }
    if ($RenewBefore -le [timespan]::Zero -or $Overlap -le [timespan]::Zero -or $CertificateLifetime -le ($RenewBefore + $Overlap)) {
        throw 'Use positive renewal and overlap intervals, with a certificate lifetime longer than their sum.'
    }
    if (Test-Path -LiteralPath $profilePath) {
        throw 'The profile directory already exists. Enrollment never overwrites credentials or recovery state.'
    }
    if ($PSCmdlet.ShouldProcess($profilePath, "Enroll certificate renewal for application $ClientId in tenant $TenantId")) {
        $null = New-MyAppCertificateRotationJwt -Certificate $Certificate -Issuer $ApplicationObjectId -Audience '00000002-0000-0000-c000-000000000000'
        $credential = ConvertTo-MyAppCertificateRotationCredential -Certificate $Certificate -KeyId $KeyId
        $state = [pscustomobject] @{
            Version            = 1
            TenantId           = $TenantId.ToString('D')
            ClientId           = $ClientId.ToString('D')
            ApplicationObjectId = $ApplicationObjectId.ToString('D')
            Phase              = 'Idle'
            OperationId        = $null
            Policy             = [pscustomobject] @{
                RenewBeforeSeconds         = $RenewBefore.TotalSeconds
                CertificateLifetimeSeconds = $CertificateLifetime.TotalSeconds
                OverlapSeconds             = $Overlap.TotalSeconds
            }
            Active             = $credential
            Pending            = $null
            Previous           = $null
            ActivatedAtUtc     = $null
            RetireAfterUtc     = $null
            LastCompletedAtUtc = $null
        }
        # Do not take ownership of an existing directory created by a racing enrollment.
        $directory = New-Item -ItemType Directory -Path $profilePath -ErrorAction Stop
        $security = [Security.AccessControl.DirectorySecurity]::new()
        $security.SetAccessRuleProtection($true, $false)
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().User
        foreach ($sid in @($user, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
            $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            $null = $security.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $directory.FullName -AclObject $security -ErrorAction Stop
        $lease = Open-MyAppCertificateRotationLock -Path $profilePath
        try {
            Save-MyAppCertificateRotationState -Path $profilePath -State $state
        } finally {
            $lease.Dispose()
        }
        ConvertTo-MyAppCertificateRotationSummary -State $state -Path $profilePath -Action Enrolled
    }
}
