function New-MyAppCertificateRotationCertificate {
    <# Generate an exportable software certificate entirely in memory, without a persistent certificate-store entry. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][guid] $ClientId,
        [Parameter(Mandatory)][timespan] $Lifetime
    )

    $rsa = [Security.Cryptography.RSACng]::new(2048)
    $generated = $null
    try {
        $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=GraphEssentials $ClientId", $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
            [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $now = [datetimeoffset]::UtcNow
        $generated = $request.CreateSelfSigned($now.AddMinutes(-5), $now.Add($Lifetime))
        $record = ConvertTo-MyAppCertificateRotationCredential -Certificate $generated
        Import-MyAppCertificateRotationCredential -Credential $record
    } finally {
        if ($generated) {
            $generated.Dispose()
        }
        $rsa.Dispose()
    }
}
