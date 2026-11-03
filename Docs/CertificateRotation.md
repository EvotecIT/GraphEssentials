# Opt-in application certificate rotation

GraphEssentials maintains an application's own certificate using the official Microsoft Graph PowerShell modules. `Register-MyAppCertificateRotation` enrolls an existing software certificate, `Get-MyAppCertificateRotation` reads status or loads the active certificate, and `Invoke-MyAppCertificateRotation` advances renewal when due. Importing the module and connecting to Graph do not rotate credentials.

The feature supports Windows PowerShell 5.1 and PowerShell 7 on Windows. It uses the existing `Microsoft.Graph.Authentication` and `Microsoft.Graph.Applications` dependencies, Windows DPAPI, and .NET cryptography. It does not require an additional engine, a new assembly, a certificate-store installation, or a new scheduled task.

## Enrollment

Start with an application registration and a currently valid, exportable RSA software certificate already registered on that application. Record the Graph credential key ID during provisioning: it is different from the certificate thumbprint, application client ID, application object ID and service principal ID.

Run enrollment as the Windows account that runs the scheduled script. Use a new local directory on that machine; DPAPI profiles cannot be moved between Windows identities or machines. Keep one profile per application identity, and enroll only a certificate whose retirement you control. Several processes can share the same profile under that account, but cannot advance it simultaneously. Coordinate other consumers of the original certificate before enabling retirement.

```powershell
Import-Module GraphEssentials

# $certificate is the existing exportable RSA software certificate.
# The identifiers below come from the application's provisioning record.
Register-MyAppCertificateRotation `
    -Path $profilePath `
    -TenantId $tenantId `
    -ClientId $clientId `
    -ApplicationObjectId $applicationObjectId `
    -KeyId $credentialKeyId `
    -Certificate $certificate `
    -CertificateLifetime ([timespan]::FromDays(30)) `
    -RenewBefore ([timespan]::FromDays(14)) `
    -Overlap ([timespan]::FromDays(1))
```

Enrollment protects the initial private key and policy in one DPAPI CurrentUser checkpoint. The new directory grants access to the current Windows identity and SYSTEM. Ordinary status output contains only identifiers, public thumbprints, expiry and progress. `-AsCertificate` explicitly returns a process-local private credential that the caller must dispose after disconnecting.

The default policy uses 30-day replacement certificates, starts renewal with 14 days remaining, and retains the previous key for at least one day after activation. Generated keys are RSA 2048 and self-signed. The tenant must permit that certificate type and lifetime. Policies requiring a trusted certificate authority need a different provisioning workflow; this feature does not bypass those policies.

## Scheduled script

Use the script's existing scheduling mechanism. Each run loads the current certificate rather than keeping a fixed thumbprint in configuration. A long-running process must reload and reconnect after `Action` is `Activated`; the maintenance command leaves the caller's SDK connection and certificate lifetime under the caller's control.

```powershell
Import-Module GraphEssentials
$certificate = Get-MyAppCertificateRotation -Path $profilePath -AsCertificate
try {
    Connect-MgGraph -TenantId $tenantId -ClientId $clientId `
        -Certificate $certificate -ContextScope Process -NoWelcome

    $maintenance = Invoke-MyAppCertificateRotation -Path $profilePath -Confirm:$false
    if ($maintenance.RequiresReconciliation) {
        throw 'Certificate maintenance requires operator reconciliation.'
    }
    if ($maintenance.Action -eq 'Activated') {
        Disconnect-MgGraph | Out-Null
        $certificate.Dispose()
        $certificate = Get-MyAppCertificateRotation -Path $profilePath -AsCertificate
        Connect-MgGraph -TenantId $tenantId -ClientId $clientId `
            -Certificate $certificate -ContextScope Process -NoWelcome
    }

    # Run the script's normal Graph workload here.
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    $certificate.Dispose()
}
```

Use a dedicated PowerShell process for maintenance, rather than concurrent SDK runspaces sharing process authentication and request settings. The enrolled application, tenant and public-cloud environment must match the app-only SDK connection. Reconciliation allows a different authorized reader in the same tenant.

Run maintenance immediately after a fresh `Connect-MgGraph`, as in the example. SDK 2.40.0 can leave its internal environment without an authentication endpoint after `Invoke-MgGraphRequest` uses an absolute URI; changing request settings then exposes an SDK authentication error. The maintenance requests use relative Graph URIs to preserve the environment. If the process previously used absolute Graph request URIs, reconnect before maintenance.

## Verification and write safety

Graph mutations use `Invoke-MgGraphRequest`. For each mutation, the command temporarily sets SDK `MaxRetry` to zero and restores the previous setting in `finally`. Correlation IDs identify requests; they are not server-side idempotency keys.

The rollover proof and OAuth client assertion are distinct signed JWTs. A small .NET RSA signer creates these standard protocol payloads without another identity library. Replacement verification makes a fresh certificate-based request to Microsoft's token endpoint through `Invoke-RestMethod`, because a successful SDK request could otherwise use a cached token issued for the old certificate. No access token or signed assertion is persisted or returned.

The replacement private key and an in-flight checkpoint are durable before `addKey` is dispatched. Only the public certificate is uploaded. After Graph returns the new key ID, fresh authentication must succeed before the profile's active reference changes. Retirement obtains another fresh token, signs the proof with the replacement certificate, saves retirement intent, and removes only the explicitly recorded previous key ID. The command never replaces the entire `keyCredentials` collection.

Both enrollment and maintenance support `-WhatIf` and `-Confirm`. A preview creates no profile, key, lock or Graph request. Keeping the previous key registered cannot extend its natural expiration, so schedule renewal early enough to preserve operational overlap and alert on failed or overdue maintenance.

## Progress and recovery

| Phase | Meaning | Next action |
| --- | --- | --- |
| `Idle` | The active certificate is enrolled and no rollover is pending | Invoke from the normal schedule; `Action NotDue` means no maintenance is needed. |
| `Registering` | addKey may have been accepted without a durable returned key ID | Use explicit reconciliation; automatic mutation is held. |
| `Registered` | The replacement key ID is durable; fresh authentication has not completed | Retry ordinary maintenance after backoff. The previous credential remains active. |
| `Overlap` | The replacement is active in the profile | Reload/reconnect long-running consumers after activation; retain the old key until the deadline. |
| `Retiring` | removeKey may have been accepted without a durable completion receipt | Use explicit reconciliation; automatic mutation is held. |

Inspect status with `Get-MyAppCertificateRotation -Path $profilePath`. After an uncertain write, connect an identity with permission to read the target application and run:

```powershell
Invoke-MyAppCertificateRotation -Path $profilePath -Reconcile
```

This mode reads public key evidence with `Get-MgApplication` and changes only local progress. A unique replacement must match the full public certificate, not just a display name. A missing or ambiguous registration remains held: a single read cannot establish that an uncertain write was never accepted. After registration reconciliation, reconnect as the enrolled application and resume ordinary maintenance. After retirement reconciliation, the profile either records completion or allows a later targeted retirement attempt when the previous key is still present.

Protect the profile and its recovery record. Do not delete an uncertain profile to force a new registration. If every registered certificate has expired, the profile or private key is lost, or the remote registration cannot be reconciled, use the application's separate authorized provisioning/recovery process.

## Permissions

An application does not need an application-management grant or self-ownership to roll its own keys. It needs a valid existing registered certificate and proof of its private key. Initial provisioning and recovery remain separate administrative operations; reconciliation also needs permission to read the target application. See Microsoft's [addKey](https://learn.microsoft.com/en-us/graph/api/application-addkey?view=graph-rest-1.0), [removeKey](https://learn.microsoft.com/en-us/graph/api/application-removekey?view=graph-rest-1.0), and [proof-token](https://learn.microsoft.com/en-us/graph/application-rollkey-prooftoken) documentation.
