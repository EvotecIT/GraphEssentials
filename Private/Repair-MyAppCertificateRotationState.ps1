function Repair-MyAppCertificateRotationState {
    <# Reconcile an interrupted write using public certificate evidence from an authorized read-only Graph session. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)][string] $Path
    )

    if ($State.Phase -notin @('Registering', 'Retiring')) {
        throw 'Only an interrupted registration or retirement requires reconciliation.'
    }
    $application = Get-MgApplication -ApplicationId $State.ApplicationObjectId -Property Id, AppId, KeyCredentials -ErrorAction Stop
    if (-not $application -or [string] $application.AppId -ne [string] $State.ClientId) {
        throw 'The remote application does not match the enrolled client identity.'
    }
    $credential = $State.Pending
    if ($State.Phase -eq 'Retiring') {
        $credential = $State.Active
    }
    $certificate = Import-MyAppCertificateRotationCredential -Credential $credential
    try {
        $publicKey = [Convert]::ToBase64String($certificate.RawData)
        $matches = @(
            foreach ($key in $application.KeyCredentials) {
                if ($key.Key -and [Convert]::ToBase64String([byte[]] $key.Key) -ceq $publicKey) {
                    $key
                }
            }
        )
    } finally {
        $certificate.Dispose()
    }
    if ($matches.Count -ne 1 -or [guid] $matches[0].KeyId -eq [guid]::Empty) {
        throw 'A unique matching replacement is not visible in Graph. Keep the reconciliation hold and check again after propagation.'
    }
    if ($State.Phase -eq 'Registering') {
        if ([string] $matches[0].KeyId -eq $State.Active.KeyId) {
            throw 'The replacement key ID cannot equal the previous key ID.'
        }
        $State.Pending.KeyId = [string] $matches[0].KeyId
        $State.Phase = 'Registered'
    } else {
        if ([string] $matches[0].KeyId -ne $State.Active.KeyId) {
            throw 'The remote replacement key ID does not match the active receipt.'
        }
        $previousStillPresent = @($application.KeyCredentials | Where-Object { [string] $_.KeyId -eq $State.Previous.KeyId }).Count -gt 0
        if ($previousStillPresent) {
            $State.Phase = 'Overlap'
        } else {
            $State.Phase = 'Idle'
            $State.Previous = $null
            $State.RetireAfterUtc = $null
            $State.LastCompletedAtUtc = [datetime]::UtcNow.ToString('o')
        }
    }
    Save-MyAppCertificateRotationState -Path $Path -State $State
}
