function Invoke-MyAppCertificateRotation {
    <#
    .SYNOPSIS
    Advances opt-in application certificate renewal using the Microsoft Graph PowerShell SDK.
    .DESCRIPTION
    Renews the enrolled software certificate when due, verifies a fresh token using the replacement,
    activates its protected profile reference, and retires the previous key after overlap. Uses the
    current app-only SDK connection for the enrolled application and disables SDK write retries only
    for each mutation. Run maintenance in a dedicated PowerShell process, not parallel SDK runspaces.
    After Action Activated, load the new active certificate and reconnect long-running SDK consumers.
    This command does not replace the caller's SDK connection or dispose its certificate.
    Interrupted writes remain held until explicit reconciliation; importing or connecting never rotates.
    .PARAMETER Path
    Profile directory created by Register-MyAppCertificateRotation, under the same Windows account.
    .PARAMETER Reconcile
    Reads the application's public certificate evidence with Get-MgApplication and repairs only local
    progress after an interrupted write. Requires an SDK connection in the profile tenant with permission
    to read that application. No remote write occurs in this mode; reconnect as the enrolled application
    before ordinary maintenance. A missing or ambiguous replacement keeps the hold.
    .EXAMPLE
    Invoke-MyAppCertificateRotation -Path $profilePath -WhatIf
    Previews the next maintenance action without generating a certificate, contacting Graph or writing files.
    .EXAMPLE
    $result = Invoke-MyAppCertificateRotation -Path $profilePath -Confirm:$false
    Advances a scheduled renewal. Action Activated indicates that the script should reload and reconnect.
    .EXAMPLE
    Invoke-MyAppCertificateRotation -Path $profilePath -Reconcile
    Confirms remote public-key evidence before resolving a saved in-flight operation.
    .OUTPUTS
    System.Management.Automation.PSCustomObject. Safe profile metadata and the action taken.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string] $Path,
        [switch] $Reconcile
    )

    $profilePath = Resolve-MyAppCertificateRotationPath -Path $Path
    $state = Read-MyAppCertificateRotationState -Path $profilePath
    $action = 'Advance'
    if ($Reconcile) {
        $action = 'Reconcile'
    } elseif ($state.Phase -in @('Registering', 'Retiring')) {
        $action = 'ReconciliationRequired'
    } elseif ($state.Phase -eq 'Idle' -and
        [datetimeoffset]::UtcNow -lt ([datetimeoffset] $state.Active.NotAfterUtc).AddSeconds(-$state.Policy.RenewBeforeSeconds)) {
        $action = 'NotDue'
    } elseif ($state.Phase -eq 'Overlap' -and [datetimeoffset]::UtcNow -lt [datetimeoffset] $state.RetireAfterUtc) {
        $action = 'Overlap'
    }
    if ($action -in @('NotDue', 'Overlap', 'ReconciliationRequired') -or
        -not $PSCmdlet.ShouldProcess("$($state.ClientId) in $($state.TenantId)", "$action certificate maintenance")) {
        ConvertTo-MyAppCertificateRotationSummary -State $state -Path $profilePath -Action $action
    } else {
        $lease = Open-MyAppCertificateRotationLock -Path $profilePath
        $active = $null
        $replacement = $null
        try {
            # Re-read after acquiring the lease: another process may have completed the previous step.
            $state = Read-MyAppCertificateRotationState -Path $profilePath
            Assert-MyAppCertificateRotationContext -State $state -Reconcile:$Reconcile
            if ($Reconcile) {
                Repair-MyAppCertificateRotationState -State $state -Path $profilePath
                $action = 'Reconciled'
            } elseif ($state.Phase -in @('Registering', 'Retiring')) {
                $action = 'ReconciliationRequired'
            } else {
                if ($state.Phase -eq 'Idle' -and
                    [datetimeoffset]::UtcNow -ge ([datetimeoffset] $state.Active.NotAfterUtc).AddSeconds(-$state.Policy.RenewBeforeSeconds)) {
                    $active = Import-MyAppCertificateRotationCredential -Credential $state.Active
                    # Validate possession before staging; expiry requires separate provisioning recovery.
                    $proof = New-MyAppCertificateRotationJwt -Certificate $active -Issuer $state.ApplicationObjectId -Audience '00000002-0000-0000-c000-000000000000'
                    $replacement = New-MyAppCertificateRotationCertificate -ClientId $state.ClientId -Lifetime ([timespan]::FromSeconds($state.Policy.CertificateLifetimeSeconds))
                    $state.Pending = ConvertTo-MyAppCertificateRotationCredential -Certificate $replacement
                    $state.OperationId = [guid]::NewGuid().ToString('D')
                    $state.Phase = 'Registering'
                    Save-MyAppCertificateRotationState -Path $profilePath -State $state
                    $response = Send-MyAppCertificateRotationRequest -State $state -Action addKey -Body @{
                        keyCredential      = @{
                            type          = 'AsymmetricX509Cert'
                            usage         = 'Verify'
                            key           = [Convert]::ToBase64String($replacement.RawData)
                            startDateTime = $replacement.NotBefore.ToUniversalTime().ToString('o')
                            endDateTime   = $replacement.NotAfter.ToUniversalTime().ToString('o')
                        }
                        passwordCredential = $null
                        proof              = $proof
                    }
                    $keyId = [guid] $response.keyId
                    if ($keyId -eq [guid]::Empty -or $keyId -eq [guid] $state.Active.KeyId) {
                        throw 'Graph did not return a distinct replacement key ID. The registration intent remains held.'
                    }
                    $state.Pending.KeyId = $keyId.ToString('D')
                    $state.Phase = 'Registered'
                    Save-MyAppCertificateRotationState -Path $profilePath -State $state
                }
                if ($state.Phase -eq 'Registered') {
                    if (-not $replacement) {
                        $replacement = Import-MyAppCertificateRotationCredential -Credential $state.Pending
                    }
                    if ($replacement.NotAfter.ToUniversalTime() -le [datetime]::UtcNow.AddSeconds($state.Policy.OverlapSeconds)) {
                        throw 'The replacement no longer has enough lifetime for activation and overlap. Keep the previous credential.'
                    }
                    Test-MyAppCertificateRotationAuthentication -State $state -Certificate $replacement
                    $now = [datetimeoffset]::UtcNow
                    if ($replacement.NotAfter.ToUniversalTime() -le $now.AddSeconds($state.Policy.OverlapSeconds).UtcDateTime) {
                        throw 'The replacement no longer has enough lifetime for activation and overlap. Keep the previous credential.'
                    }
                    $state.Previous = $state.Active
                    $state.Active = $state.Pending
                    $state.Pending = $null
                    $state.ActivatedAtUtc = $now.ToString('o')
                    $state.RetireAfterUtc = $now.AddSeconds($state.Policy.OverlapSeconds).ToString('o')
                    $state.Phase = 'Overlap'
                    Save-MyAppCertificateRotationState -Path $profilePath -State $state
                    $action = 'Activated'
                } elseif ($state.Phase -eq 'Overlap' -and [datetimeoffset]::UtcNow -ge [datetimeoffset] $state.RetireAfterUtc) {
                    $active = Import-MyAppCertificateRotationCredential -Credential $state.Active
                    Test-MyAppCertificateRotationAuthentication -State $state -Certificate $active
                    $proof = New-MyAppCertificateRotationJwt -Certificate $active -Issuer $state.ApplicationObjectId -Audience '00000002-0000-0000-c000-000000000000'
                    $state.Phase = 'Retiring'
                    Save-MyAppCertificateRotationState -Path $profilePath -State $state
                    $null = Send-MyAppCertificateRotationRequest -State $state -Action removeKey -Body @{
                        keyId = $state.Previous.KeyId
                        proof = $proof
                    }
                    $state.Previous = $null
                    $state.Phase = 'Idle'
                    $state.RetireAfterUtc = $null
                    $state.LastCompletedAtUtc = [datetime]::UtcNow.ToString('o')
                    Save-MyAppCertificateRotationState -Path $profilePath -State $state
                    $action = 'Retired'
                }
            }
            ConvertTo-MyAppCertificateRotationSummary -State $state -Path $profilePath -Action $action
        } finally {
            if ($active) {
                $active.Dispose()
            }
            if ($replacement) {
                $replacement.Dispose()
            }
            $lease.Dispose()
        }
    }
}
