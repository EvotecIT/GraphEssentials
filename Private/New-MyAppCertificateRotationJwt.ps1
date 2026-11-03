function New-MyAppCertificateRotationJwt {
    <# Sign the distinct Graph rollover or OAuth assertion contract with an explicitly supplied RSA key. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [Parameter(Mandatory)][guid] $Issuer,
        [Parameter(Mandatory)][string] $Audience,
        [switch] $ClientAssertion
    )

    $now = [datetimeoffset]::UtcNow
    if ($Issuer -eq [guid]::Empty -or $now.UtcDateTime -lt $Certificate.NotBefore.ToUniversalTime() -or
        $now.UtcDateTime -ge $Certificate.NotAfter.ToUniversalTime()) {
        throw 'A nonempty issuer and a currently valid certificate are required.'
    }
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    if (-not $rsa) {
        throw 'An accessible RSA private key is required.'
    }
    try {
        if ($rsa.KeySize -lt 2048) {
            throw 'Certificate rotation requires RSA keys of at least 2048 bits.'
        }
        $thumbprint = [Convert]::ToBase64String($Certificate.GetCertHash()).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $header = @{ alg = 'RS256'; typ = 'JWT'; x5t = $thumbprint } | ConvertTo-Json -Compress
        $minutes = 10
        if ($ClientAssertion) {
            $minutes = 5
        }
        $end = $now.AddMinutes($minutes)
        $certificateEnd = [datetimeoffset] $Certificate.NotAfter.ToUniversalTime()
        if ($end -gt $certificateEnd) {
            $end = $certificateEnd
        }
        if ($end.ToUnixTimeSeconds() -le $now.ToUnixTimeSeconds()) {
            throw 'The certificate expires before a usable assertion can be issued.'
        }
        $claims = @{
            aud = $Audience
            iss = $Issuer.ToString('D')
            jti = [guid]::NewGuid().ToString('D')
            nbf = $now.ToUnixTimeSeconds()
            exp = $end.ToUnixTimeSeconds()
        }
        if ($ClientAssertion) {
            $claims.sub = $Issuer.ToString('D')
        }
        $payload = $claims | ConvertTo-Json -Compress
        $parts = foreach ($text in @($header, $payload)) {
            [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        }
        $inputText = $parts -join '.'
        $signature = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($inputText),
            [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $inputText + '.' + [Convert]::ToBase64String($signature).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    } finally {
        $rsa.Dispose()
    }
}
