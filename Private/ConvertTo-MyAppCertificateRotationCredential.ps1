function ConvertTo-MyAppCertificateRotationCredential {
    <# Export only into memory; the caller persists this record inside a DPAPI-protected checkpoint. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [guid] $KeyId = [guid]::Empty
    )

    $bytes = $Certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, [string]::Empty)
    try {
        [pscustomobject] @{
            KeyId       = $KeyId.ToString('D')
            Thumbprint  = $Certificate.Thumbprint
            NotAfterUtc = $Certificate.NotAfter.ToUniversalTime().ToString('o')
            Pfx         = [Convert]::ToBase64String($bytes)
        }
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
}
