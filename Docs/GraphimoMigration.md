# Migrating Graphimo workflows

GraphEssentials uses the official Microsoft Graph PowerShell modules. Connect with `Connect-MgGraph`, use the SDK directly for ordinary CRUD, and use GraphEssentials for composed directory and invitation workflows. It does not accept Graphimo authorization-header envelopes, use Graphimo's token cache, or grant permissions automatically.

## Directory user queries

`Get-MyDirectoryUser` returns selected directory data for automation. `Get-MyUser` remains the enriched reporting command, with license and service information. A report projection is not a substitute for an automation inventory.

```powershell
Import-Module GraphEssentials
Connect-MgGraph -TenantId $tenantId -ClientId $clientId `
    -Certificate $certificate -ContextScope Process -NoWelcome

$users = Get-MyDirectoryUser -Filter "userType eq 'Guest'" `
    -Property Id, Mail, EmployeeId, AccountEnabled, extensionAttribute1 `
    -IncludeManager

foreach ($user in $users) {
    # Manager is a nested record or null, rather than a report's flattened manager ID.
    [pscustomobject] @{
        Id        = $user.Id
        Mail      = $user.Mail
        Division  = $user.extensionAttribute1
        ManagerId = if ($user.Manager) { $user.Manager.Id } else { $null }
    }
}
```

The command always selects `Id`, reads every list page before emitting records, and preserves null, false and empty-array values. It lifts requested custom directory extensions from the SDK's `AdditionalProperties` dictionary into the output record. `extensionAttribute1` through `extensionAttribute15` select `OnPremisesExtensionAttributes` and flatten the requested attribute. Selecting that nested property explicitly retains it as well. Use the complete `extension_<application-id-without-hyphens>_<name>` for a custom directory extension.

Use `-UserId` for an object ID or UPN lookup. `-Filter` and `-Sort` pass through to `Get-MgUser`; escape apostrophes inside OData string literals by doubling them. No beta endpoint is selected implicitly for employee or extension attributes.

`-CountVariable matchingUsers` follows the SDK's global-variable contract and enables eventual consistency. Manager expansion cannot be combined with advanced count/eventual-consistency queries; use separate manager and count queries when both are needed. A query failure terminates without returning an incomplete inventory or silently omitting a requested field. That does not make Graph's eventually consistent directory a transactional snapshot; deletion and cleanup policies still need their own safety checks.

Set `-MinimumCount` when processing must stop if a complete query returns too few users:

```powershell
$users = @(Get-MyDirectoryUser -Filter "userType eq 'Guest'" `
    -Property Id, Mail, EmployeeId -MinimumCount $minimumExpectedGuests)
```

The command checks the returned collection before emitting any records. The threshold belongs to the caller and must match its filter. It does not count unique employee IDs or usable email addresses. Validate those business keys, reject ambiguous duplicates, and enforce deletion limits before using the inventory for changes; do not let a dictionary silently overwrite two users with the same key.

## Invitations and outcomes

`New-MyGuestInvitation` accepts an array of records. Each needs `EmailAddress`; optional fields are `DisplayName`, `SendInvitationMessage`, `InviteRedirectUrl`, `UserType`, `ResetRedemption`, `InvitedUserId`, and opaque `Context`. CSV text `True` and `False` is parsed as Boolean data. Email delivery defaults to false and the redirect defaults to `https://myapps.microsoft.com`. A redemption reset requires the existing user's object ID. The identity needs permission for its chosen operation; member invitations and redemption resets can require more than an ordinary guest invitation.

```powershell
$invitations = @(
    @{ EmailAddress = 'guest@example.com'; DisplayName = 'Guest One'; Context = 'row-1' }
)

# Run immediately after a fresh Connect-MgGraph in a dedicated process.
$results = @(New-MyGuestInvitation -Invitation $invitations)
foreach ($result in $results) {
    if ($result.Success) {
        $createdUserId = $result.InvitedUserId
        # The original Graph invitation body is available as $result.Invitation.
    } elseif ($result.RequiresReconciliation) {
        # Preserve the pending record and investigate before resubmitting this input.
    } elseif ($result.Status -eq 'Deferred') {
        # Reschedule no earlier than RetryAfterSeconds.
    } else {
        # Record Failed, Skipped or WhatIf explicitly; a nonempty result is not success.
    }
}
```

The command submits at most 20 invitations per Graph JSON batch and returns one result per input in original order. `Succeeded` requires HTTP 201 and an invited-user ID. Invalid local records and explicit permanent rejections return `Failed`. Only HTTP 429 subresponses are retried; already successful inputs are not resubmitted. Retry-After seconds, HTTP dates and millisecond hints are honored. When retry attempts are exhausted or the server's delay exceeds `MaxRetryDelaySeconds`, `Deferred` preserves the requested delay for the scheduler.

Transport failures, HTTP 408/server failures, missing or duplicate response IDs, and malformed success bodies return `Uncertain`. They are not automatically retried because the invitation may already exist. Batch correlation IDs are not idempotency keys. An SDK token refresh or a lookup by email does not by itself prove that every intended invitation or redemption reset completed; recovery must inspect the expected user's identity and redemption state.

The workflow temporarily disables SDK request retries for each dispatch and restores the previous integer setting. It uses relative Graph URIs to preserve the SDK environment. Use a dedicated PowerShell process without concurrent SDK runspaces, and reconnect before maintenance if that process previously used absolute `Invoke-MgGraphRequest` URIs: SDK 2.40.0 can leave its internal authentication endpoint unset after those calls.

### Checkpoints and recovery

The host owns persistence. Supply `PendingBatchAction` to durably save the exact pending subset before every dispatch, including throttled retries. Each record includes `InputIndex`, `Context`, `EmailAddress`, `RequestId`, `AttemptCount`, and the request `Body`. If saving fails, throw to prevent that dispatch. Use `ResultBatchAction` to commit the ordered outcomes for a dispatched batch before they are emitted and before the next batch starts.

```powershell
$results = New-MyGuestInvitation -Invitation $invitations `
    -PendingBatchAction $savePendingIntent `
    -ResultBatchAction $saveCompletedBatch
```

These callbacks are application-supplied scriptblocks that write the application's durable checkpoint. They must preserve existing unresolved intent, use atomic persistence appropriate to their store, and must not change SDK identity or mutate results. A result-checkpoint exception stops processing; treat the saved pending intent as requiring reconciliation even if some remote operations succeeded. Do not blindly rerun the original collection. Reconcile uncertain entries, retain successful user IDs, and submit only entries established as safe to retry. No callbacks or SDK access occur during `-WhatIf`; declined batches are `Skipped`.

Invitation bodies and responses contain personal data, and a successful response can include a sensitive redemption URL. Protect recovery records. Log selected status/identity fields rather than serializing complete `Invitation` objects.

## Ordinary SDK operations

| Graphimo use | SDK or GraphEssentials replacement | Caller responsibility |
| --- | --- | --- |
| `Connect-Graphimo` or a legacy `Connect-Graph` helper | `Connect-MgGraph`, then `Get-MgContext` | Replace header/MSAL envelopes, preserve tenant/client/environment checks, and identify legacy aliases before removing them. |
| `Get-GraphUser` | `Get-MyDirectoryUser` | Choose selected properties and the explicit manager/extension shape. |
| `Set-GraphUser` | `Update-MgUser` | Map `Enabled` to `AccountEnabled`; preserve extension payloads and explicit result records. |
| `Add-GraphUser` | `New-MgUser` | Provide the SDK's required creation fields and protect password profiles. |
| `Remove-GraphUser` | `Remove-MgUser` | Preserve deletion safety limits and simulation. |
| `Set-GraphManager` | `Set-MgUserManagerByRef` | Set the subordinate user's manager reference. |
| `Remove-GraphManager` | `Remove-MgUserManagerByRef` | Pass the subordinate user's ID, not the manager's ID. |
| `Get-GraphGroup` / `Get-GraphGroupMember` | `Get-MgGroup` / `Get-MgGroupMember` | Preserve `-All`, selected fields and member object types. |
| `Add-GraphGroupMember` / `Remove-GraphGroupMember` | `New-MgGroupMemberByRef` / `Remove-MgGroupMemberByRef` | Use reference commands; removal must remove membership rather than the directory object. |
| `Get-GraphApplication` | `Get-MgApplication` | Preserve filter escaping and distinguish client and object IDs. |
| `Import-GraphGuest` / `Import-GraphGuestBatch` | `New-MyGuestInvitation` | Use `Success`, `Status` and `InvitedUserId`; checkpoint and reconcile uncertain operations. |

SDK write cmdlets often return no object on success. Do not treat an empty return value as failure or the absence of warnings as success. Use terminating errors, explicit simulation, and the application's result record:

```powershell
if ($WhatIfPreference) {
    $outcome = [pscustomobject] @{ Id = $userId; Status = 'WhatIf'; Success = $false }
} else {
    try {
        Update-MgUser -UserId $userId -AccountEnabled:$false -ErrorAction Stop
        $outcome = [pscustomobject] @{ Id = $userId; Status = 'Succeeded'; Success = $true }
    } catch {
        $outcome = [pscustomobject] @{ Id = $userId; Status = 'Failed'; Success = $false; Error = $_.Exception.Message }
    }
}
```

For a lost response to a write, read back the intended state before retrying; a caught transport error is not proof that the operation did nothing. Multi-step user/manager/group workflows need per-step outcomes because they are not an atomic transaction.

Keep `Connect-MgGraph` and ordinary SDK CRUD at the call site. Connection parameters, expected tenant/client, selected properties, and workload permissions should be explicit. Reuse a verified app-only context by its tenant and client identity; an empty `Account` is normal for app-only authentication. Mail delivery belongs to Mailozaurr rather than a directory workflow. Customer-specific matching, deletion limits, invitation schedules, and privileged directory-role policy stay in the application.

## Build dependencies and retirement

GraphEssentials belongs in the consumer's `RequiredModule` declarations, not its `ApprovedModule` helper-donor list. PowerForge can inline approved helpers into a merged consumer, and current PowerForge excludes approved donors from the published runtime dependency list. Copying stateful GraphEssentials workflows into each consumer would leave separate implementations to rebuild whenever they change.

Remove Graphimo from required and approved/integration inputs after migrating source calls. Rebuild in clean staging and inspect the resulting manifest, merged `.psm1`, nested module payloads, archives, installers and installed copy. Removing a manifest entry does not remove previously copied functions or bundled Graphimo files. Updating an installed donor does not refresh an inlined copy.

Use a tested published GraphEssentials version for deployed consumers. Keep Microsoft Graph workload modules and Authentication aligned, and validate Windows PowerShell 5.1 imports with its documented function/variable limits. GraphEssentials' existing report-related dependencies remain part of its module footprint. Clearing all maintained consumers and shipped artifacts is the retirement criterion; deprecating the Graphimo repository or deploying customer changes remains a separate step.

Microsoft references: [users and query behavior](https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0), [invitations](https://learn.microsoft.com/en-us/graph/api/invitation-post?view=graph-rest-1.0), [JSON batching](https://learn.microsoft.com/en-us/graph/json-batching), and [throttling](https://learn.microsoft.com/en-us/graph/throttling).
