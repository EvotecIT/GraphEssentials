# Certificate sessions on local hosts and Azure DevOps

`Invoke-MyAppCertificateSession` uses a protected profile as the stable credential reference. The original thumbprint or PFX enrolls that profile; later runs load its active certificate. The script and JSON do not need a new thumbprint after each renewal. This API is available from GraphEssentials 0.0.71.

The current profile uses Windows DPAPI CurrentUser protection. It needs the same persistent Windows identity and disk between runs. Local scheduled hosts and suitably configured self-hosted Windows agents can use it. Microsoft-hosted Azure DevOps jobs cannot preserve this profile across fresh agents.

## First enabled run

Start with the application's currently valid, exportable RSA software certificate and access to its private key. A thumbprint identifies the certificate; it does not contain the private key. Record the application registration object ID and the existing certificate credential key ID during provisioning. These differ from the client ID, service principal ID and thumbprint.

For a JSON adapter, keep the existing tenant/client and certificate settings and add the rotation section below. Replace the two example IDs with provisioning values. This is a configuration fragment, not a complete application's configuration file.

```json
{
  "CertificateRotation": {
    "Enabled": true,
    "ProfilePath": "D:\\ServiceData\\Automation\\Graph",
    "ApplicationObjectId": "11111111-1111-4111-8111-111111111111",
    "KeyId": "22222222-2222-4222-8222-222222222222"
  }
}
```

Rotation is disabled when omitted or set to `false`. A JSON adapter must explicitly call the session API; importing GraphEssentials alone does not enable renewal.

Run enrollment under the Windows account that runs the scheduled script or agent service. Enrolling as an interactive administrator and later running as another service account does not give that service account a usable profile. Choose a persistent directory outside the checkout, job workspace, temporary folders and report output.

The first enabled run enrolls the existing private credential and policy in a protected local profile, establishes the expected Graph application connection, performs due maintenance, then runs the workload. For policy settings, certificate requirements and permissions, see [enrollment and recovery](CertificateRotation.md).

## Later runs and renewal

Once enrolled, a JSON adapter can use the saved profile without the bootstrap fields:

```json
{
  "CertificateRotation": {
    "Enabled": true,
    "ProfilePath": "D:\\ServiceData\\Automation\\Graph"
  }
}
```

The existing tenant and client identification remains required. Explicit renewal-policy values must match the enrolled policy; omitting them retains it.

```text
First run:     bootstrap certificate A -> profile active A -> workload uses A
Ordinary run:  profile active A -> workload uses A
Renewal run:   register and freshly verify B -> profile active B -> reconnect -> workload uses B
Later run:     profile active B -> workload uses B
After overlap: remove only the recorded previous registration A
```

The original thumbprint can remain in JSON as a bootstrap reference. Enabled adapters skip obsolete thumbprint/PFX selection when the profile exists. The session supplies a certificate object to authentication, so the configured thumbprint does not need to change. It does not rewrite scripts, JSON, the original PFX, Azure DevOps Secure Files or pipeline variables.

Replacement private keys stay in the protected profile and are loaded into the process for the workload. They are not automatically installed in the Windows certificate store. The session reconnects when the active credential changes and disposes its loaded certificate after the synchronous workload ends; do not retain it for background work.

For another PowerShell script with an enrolled profile, use the public session API:

```powershell
$connection = @{ TenantId = $tenantId; ClientId = $clientId }
$rotation = @{ Enabled = $true; ProfilePath = $profilePath }
Invoke-MyAppCertificateSession -ConnectionParameters $connection -Rotation $rotation `
    -ScriptBlock {
        param($activeConnection, $maintenance)
        Get-MyDirectoryUser
    }
```

Use an absolute `$profilePath`, or supply `-ConfigurationDirectory` for a relative path. Run the session in a dedicated PowerShell process. The command does not restore a previous Graph SDK connection.

## Local scheduled hosts

Keep the profile on persistent storage accessible to the scheduled identity. The bootstrap certificate is needed only for initial enrollment; the profile is needed on every subsequent run. Do not delete it during cleanup or copy it to another account or machine as a migration method. DPAPI CurrentUser protection is tied to the running identity; see [Microsoft's data-protection scope documentation](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.dataprotectionscope).

Several scheduled scripts under that identity can load the same profile. They must use the session or explicitly load its active credential. Maintenance is serialized by the profile lease; the SDK connection must not be shared concurrently across runspaces.

## Self-hosted Azure DevOps agents

Use a persistent Windows agent running under the enrolled identity. Store the profile outside `$(Build.SourcesDirectory)`, the agent workspace and temporary directories, so checkout cleaning and workspace cleanup cannot remove it.

If the pool has several machines, route jobs to the machine that owns the profile; selecting a self-hosted pool alone does not guarantee that. Replacing the machine or changing its service identity requires an appropriate provisioning/recovery plan. Downloading the original PFX on every job does not transfer the profile's newer active credential.

## Microsoft-hosted Azure DevOps agents

A pipeline using a Microsoft-hosted image such as `vmImage: windows-latest` receives a fresh VM for each job, and the filesystem is discarded afterward. The next job cannot load the previous job's active credential and renewal progress. See [Microsoft-hosted agent lifecycle](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops).

Keep rotation disabled for this hosting model:

```json
{ "CertificateRotation": { "Enabled": false } }
```

Do not enable local-profile rotation for one job and assume that downloading the original PFX on the next job restores it. Do not upload the profile through reports, build artefacts or pipeline cache: it contains protected private credential material, and copying it does not make it portable.

Azure Key Vault support is [planned](../ROADMAP.md#azure-key-vault-backed-certificate-sessions), not available in the current API. Until a suitable remote provider exists, use externally managed credentials or a persistent self-hosted agent for this workflow.

## Common questions

**Does an independent script with a hardcoded thumbprint follow renewal?** No. A direct fixed-thumbprint connection continues to use the old certificate. Coordinate every consumer before its registration is retired, or use a separate credential for the rotating workload.

**What if the profile disappears or every certificate expires?** Use the separate provisioning/recovery process. Do not delete an uncertain profile to force enrollment. Losing the active private key is not repaired by changing the thumbprint in JSON.

**How can I inspect progress safely?** Run `Get-MyAppCertificateRotation -Path $profilePath` under the enrolled identity. Status shows public thumbprints, expiry, phase and maintenance deadlines. Session events report enrollment, maintenance action and bounded failure stages/codes without private keys, tokens or assertions. Authentication or maintenance failure stops the workload and retains protected state; it does not silently fall back to the old JSON credential.

**Does WhatIf preview the entire script?** The session's `-WhatIf` previews credential enrollment/maintenance. Ordinary authenticated workload reads can still run. The workload must respect its own write/WhatIf controls; an email-preview option does not preview certificate maintenance.

**Does this also rotate client secrets?** No. Password credentials need a separate implementation covering application-management authorization, secure persistence and distribution to consumers. See the [scope of the current implementation](CertificateRotation.md#workload-session-and-json-configuration).