function Import-MyAppCertificateRotationCredential {
    <# Load a software key only into the process, checking it against the protected public metadata. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Credential)

    $bytes = [Convert]::FromBase64String($Credential.Pfx)
    try {
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $bytes, [string]::Empty, [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet -bor
            [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
    if (-not $certificate.HasPrivateKey -or $certificate.Thumbprint -ne $Credential.Thumbprint -or
        $certificate.NotAfter.ToUniversalTime() -ne ([datetimeoffset] $Credential.NotAfterUtc).UtcDateTime) {
        $certificate.Dispose()
        throw 'The protected certificate does not match its enrolled identity.'
    }
    $certificate
}
