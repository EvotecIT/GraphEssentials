function Read-MyAppCertificateRotationState {
    <# Read a DPAPI-authenticated checkpoint; never return this private record from a public command. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $file = Join-Path $Path 'rotation.dpapi'
    $item = Get-Item -LiteralPath $file -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or $item.Length -gt 1MB) {
        throw 'The certificate rotation checkpoint is not a supported regular file.'
    }
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect(
        [IO.File]::ReadAllBytes($file), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    try {
        $state = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
    if ($state.Version -ne 1 -or $state.Phase -notin @('Idle', 'Registering', 'Registered', 'Overlap', 'Retiring')) {
        throw 'The certificate rotation checkpoint has an unsupported schema or phase.'
    }
    foreach ($identity in @('TenantId', 'ClientId', 'ApplicationObjectId')) {
        $id = [guid] $state.$identity
        if ($id -eq [guid]::Empty) {
            throw "The checkpoint is missing $identity."
        }
    }
    if ($state.Policy.RenewBeforeSeconds -le 0 -or $state.Policy.OverlapSeconds -le 0 -or
        $state.Policy.CertificateLifetimeSeconds -le ($state.Policy.RenewBeforeSeconds + $state.Policy.OverlapSeconds)) {
        throw 'The checkpoint contains an invalid renewal policy.'
    }
    if ([guid] $state.Active.KeyId -eq [guid]::Empty -or -not $state.Active.Pfx) {
        throw 'The checkpoint has no active certificate identity.'
    }
    if ($state.Phase -in @('Registering', 'Registered')) {
        if (-not $state.Pending.Pfx -or ($state.Phase -eq 'Registered' -and [guid] $state.Pending.KeyId -eq [guid]::Empty)) {
            throw 'The checkpoint is missing the pending certificate.'
        }
        if ($state.Pending.Thumbprint -eq $state.Active.Thumbprint) {
            throw 'The replacement must differ from the active certificate.'
        }
    }
    if ($state.Phase -in @('Overlap', 'Retiring')) {
        if (-not $state.Previous.Pfx -or [guid] $state.Previous.KeyId -eq [guid]::Empty -or
            $state.Previous.KeyId -eq $state.Active.KeyId -or -not $state.ActivatedAtUtc -or -not $state.RetireAfterUtc -or
            [datetimeoffset] $state.RetireAfterUtc -ne ([datetimeoffset] $state.ActivatedAtUtc).AddSeconds($state.Policy.OverlapSeconds)) {
            throw 'The checkpoint is missing valid activation and retirement evidence.'
        }
    }
    $state
}
