function Test-MyAppCertificateRotationAuthentication {
    <# Prove the private key through an uncached token-endpoint request; an SDK cache hit cannot prove rotation. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)][Security.Cryptography.X509Certificates.X509Certificate2] $Certificate
    )

    $endpoint = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token' -f $State.TenantId
    $assertion = New-MyAppCertificateRotationJwt -Certificate $Certificate -Issuer $State.ClientId -Audience $endpoint -ClientAssertion
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -ContentType 'application/x-www-form-urlencoded' -Body @{
            grant_type            = 'client_credentials'
            client_id             = $State.ClientId
            scope                 = 'https://graph.microsoft.com/.default'
            client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            client_assertion      = $assertion
        } -MaximumRedirection 0 -TimeoutSec 60 -Verbose:$false -Debug:$false -ErrorAction Stop
        if (-not $response.access_token) {
            throw 'Token response is empty.'
        }
    } catch {
        # Do not propagate token endpoint bodies, assertions or private credential records into logs.
        throw 'Fresh certificate authentication failed. Keep the previous credential and retry after checking propagation and tenant policy.'
    } finally {
        $assertion = $null
        $response = $null
    }
}
