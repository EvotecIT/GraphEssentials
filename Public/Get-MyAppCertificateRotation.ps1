function Get-MyAppCertificateRotation {
    <#
    .SYNOPSIS
    Reads safe renewal status or loads the active certificate for Connect-MgGraph.
    .DESCRIPTION
    Reads a profile protected for the current Windows account. Ordinary output contains identifiers,
    public thumbprints, expiry and lifecycle state. AsCertificate explicitly loads a private credential
    into this process; keep it alive for the SDK connection and dispose it after disconnecting.
    No Graph connection, certificate-store import or credential write occurs.
    .PARAMETER Path
    Local profile directory created by Register-MyAppCertificateRotation.
    .PARAMETER AsCertificate
    Returns the active X509Certificate2 with an ephemeral private key instead of status metadata.
    .EXAMPLE
    Get-MyAppCertificateRotation -Path $profilePath
    Inspects renewal and reconciliation status without exposing private credentials.
    .EXAMPLE
    $certificate = Get-MyAppCertificateRotation -Path $profilePath -AsCertificate
    Connect-MgGraph -TenantId $tenantId -ClientId $clientId -Certificate $certificate -ContextScope Process -NoWelcome
    Loads the enrolled credential for the script's normal Microsoft Graph authentication.
    .OUTPUTS
    System.Management.Automation.PSCustomObject, or System.Security.Cryptography.X509Certificates.X509Certificate2 with AsCertificate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [switch] $AsCertificate
    )

    $profilePath = Resolve-MyAppCertificateRotationPath -Path $Path
    $state = Read-MyAppCertificateRotationState -Path $profilePath
    if ($AsCertificate) {
        Import-MyAppCertificateRotationCredential -Credential $state.Active
    } else {
        ConvertTo-MyAppCertificateRotationSummary -State $state -Path $profilePath
    }
}
