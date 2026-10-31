---
external help file: GraphEssentials-help.xml
Module Name: GraphEssentials
online version:
schema: 2.0.0
---
# New-MyGuestInvitation
## SYNOPSIS
Submits guest invitations through bounded SDK batches with explicit per-input outcomes.

## SYNTAX
### __AllParameterSets
```powershell
New-MyGuestInvitation [-Invitation] <Object[]> [[-BatchSize] <int>] [[-MaxRetries] <int>] [[-MaxRetryDelaySeconds] <int>] [[-PendingBatchAction] <scriptblock>] [[-ResultBatchAction] <scriptblock>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Accepts one or more records with EmailAddress, optional DisplayName, SendInvitationMessage,
InviteRedirectUrl, UserType, ResetRedemption, InvitedUserId and opaque Context. CSV Boolean text
True/False is supported; email delivery defaults to false. Redirect defaults to myapps.microsoft.com.
Returns one ordered outcome per input. Only explicit HTTP 429 responses are retried. Lost responses,
malformed successes, duplicate receipts, HTTP 408 and server failures require reconciliation, not replay.
Run immediately after a fresh Connect-MgGraph in a dedicated process without concurrent SDK runspaces.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > $results = New-MyGuestInvitation -Invitation @(@{ EmailAddress = 'guest@example.com'; DisplayName = 'Guest One'; Context = 'row-1' })
Invites one guest without sending email and returns its explicit outcome and invited-user ID.
```


### EXAMPLE 2
```powershell
PS > New-MyGuestInvitation -Invitation $invitations -WhatIf
Validates and previews batches without contacting Graph, changing SDK request settings or invoking callbacks.
```


### EXAMPLE 3
```powershell
PS > $results = New-MyGuestInvitation -Invitation $invitations -PendingBatchAction $saveIntent -ResultBatchAction $saveResults
Lets the host persist intent before writes and final outcomes before advancing to the next batch.
```


## PARAMETERS

### -BatchSize
Maximum invitations per Graph JSON batch, from 1 to 20. Defaults to 20.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
Default value: 20
Accept pipeline input: False
Accept wildcard characters: False
```

### -Invitation
Invitation records. ResetRedemption requires the existing user's object ID in InvitedUserId.
Optional UserType accepts Guest or Member; inviting members can require additional permissions.

```yaml
Type: Object[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxRetries
Additional attempts after explicit throttling. Defaults to 3. Transport or ambiguous outcomes are never retried.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: 3
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxRetryDelaySeconds
Maximum wait accepted within this invocation. Defaults to 300. A longer Retry-After returns Deferred,
preserving the server's delay so the caller can reschedule without retrying too early.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 3
Default value: 300
Accept pipeline input: False
Accept wildcard characters: False
```

### -PendingBatchAction
Optional checkpoint callback receiving the exact input indices, context, request IDs, attempt counts and
public request bodies immediately before each dispatch, including throttled subsets. Throwing prevents
that dispatch and terminates processing. Correlation IDs are not server-side idempotency keys.

```yaml
Type: ScriptBlock
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResultBatchAction
Optional callback receiving ordered final outcomes for each dispatched batch before output and before
the next batch starts. If it throws, processing stops; reconcile the durable pending intent before rerun.
Callbacks must not change the SDK connection or mutate results. No callbacks run during WhatIf or a declined batch.

```yaml
Type: ScriptBlock
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `System.Management.Automation.PSCustomObject. InputIndex, Context, EmailAddress, Status, Success,%25u000ARequiresReconciliation, StatusCode, AttemptCount, RetryDelaySeconds, RetryAfterSeconds, RequestId,%25u000AInvitedUserId, Invitation, ErrorCode and ErrorMessage. Invitation can contain a sensitive redemption URL.`

## RELATED LINKS

- None
