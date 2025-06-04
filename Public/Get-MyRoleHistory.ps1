function Get-MyRoleHistory {
    <#
    .SYNOPSIS
    Retrieves Azure AD/Entra ID Privileged Identity Management (PIM) role assignment history.

    .DESCRIPTION
    Gets detailed information about PIM role assignment requests and their history, including activations,
    deactivations, assignments, and removals. Translates all IDs to readable names and provides
    comprehensive information about each PIM event.

        .PARAMETER RoleId
    Optional. Filter results to show history for a specific role definition ID.

    .PARAMETER RoleName
    Optional. Filter results to show history for a specific role name (supports wildcards).

    .PARAMETER PrincipalId
    Optional. Filter results to show history for a specific user, group, or service principal ID.

    .PARAMETER UserPrincipalName
    Optional. Filter results to show history for a specific user principal name (supports wildcards).

    .PARAMETER DaysBack
    Optional. Number of days to look back for history. Defaults to 30 days.

    .PARAMETER IncludeAllStatuses
    When specified, includes all statuses including pending and failed requests.
    By default, only shows completed requests.

    .EXAMPLE
    Get-MyRoleHistory
    Returns PIM role assignment history for the last 30 days.

    .EXAMPLE
    Get-MyRoleHistory -RoleId "b0f54661-2d74-4c50-afa3-1ec803f12efe"
    Returns PIM history for a specific role ID.

    .EXAMPLE
    Get-MyRoleHistory -RoleName "Global Administrator"
    Returns PIM history for the Global Administrator role.

    .EXAMPLE
    Get-MyRoleHistory -UserPrincipalName "john.doe@company.com"
    Returns PIM history for a specific user.

    .EXAMPLE
    Get-MyRoleHistory -RoleName "*Admin*" -DaysBack 90
    Returns PIM history for all admin roles in the last 90 days.

    .EXAMPLE
    Get-MyRoleHistory -IncludeAllStatuses
    Returns all PIM requests including pending and failed ones.

    .NOTES
    This function requires the Microsoft.Graph.Identity.Governance module and appropriate permissions.
    Typically requires RoleManagement.Read.Directory or Directory.Read.All permissions.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string]$RoleId,
        [Parameter()][string]$RoleName,
        [Parameter()][string]$PrincipalId,
        [Parameter()][string]$UserPrincipalName,
        [Parameter()][int]$DaysBack = 30,
        [switch]$IncludeAllStatuses
    )

    $ErrorsCount = 0
    $StartDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Get all required data with error handling
    try {
        Write-Verbose "Getting users..."
        $Users = Get-MgUser -ErrorAction Stop -All -Property DisplayName, CreatedDateTime, 'AccountEnabled', 'Mail', 'UserPrincipalName', 'Id', 'UserType', 'OnPremisesDistinguishedName', 'OnPremisesSamAccountName'
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get users. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    try {
        Write-Verbose "Getting groups..."
        $Groups = Get-MgGroup -ErrorAction Stop -All -Filter "IsAssignableToRole eq true" -Property CreatedDateTime, Id, DisplayName, Mail, SecurityEnabled
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get groups. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    try {
        Write-Verbose "Getting service principals..."
        $ServicePrincipals = Get-MgServicePrincipal -ErrorAction Stop -All -Property CreatedDateTime, 'ServicePrincipalType', 'DisplayName', 'AccountEnabled', 'Id', 'AppID'
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get service principals. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    try {
        Write-Verbose "Getting role definitions..."
        $Roles = Get-MgRoleManagementDirectoryRoleDefinition -ErrorAction Stop -All
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get roles. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    try {
        Write-Verbose "Getting role assignment schedule requests (PIM history)..."
        $Filter = "createdDateTime ge $StartDate"
        $RoleAssignmentRequests = Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -ErrorAction Stop -All -Filter $Filter
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get role assignment schedule requests. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    try {
        Write-Verbose "Getting role eligibility schedule requests (PIM eligible assignment history)..."
        $Filter = "createdDateTime ge $StartDate"
        $RoleEligibilityRequests = Get-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -ErrorAction Stop -All -Filter $Filter
    } catch {
        Write-Warning -Message "Get-MyRoleHistory - Failed to get role eligibility schedule requests. Error: $($_.Exception.Message)"
        $ErrorsCount++
    }

    if ($ErrorsCount -gt 0) {
        Write-Error "Failed to retrieve required data. Cannot continue."
        return
    }

    # Build caches for quick lookups
    Write-Verbose "Building lookup caches..."
    $CacheUsersAndApps = [ordered]@{}

    foreach ($User in $Users) {
        $CacheUsersAndApps[$User.Id] = @{
            DisplayName              = $User.DisplayName
            Type                     = "User"
            UserType                 = $User.UserType
            Mail                     = $User.Mail
            UserPrincipalName        = $User.UserPrincipalName
            AccountEnabled           = $User.AccountEnabled
            OnPremisesSamAccountName = $User.OnPremisesSamAccountName
        }
    }

    foreach ($ServicePrincipal in $ServicePrincipals) {
        $CacheUsersAndApps[$ServicePrincipal.Id] = @{
            DisplayName          = $ServicePrincipal.DisplayName
            Type                 = "ServicePrincipal"
            ServicePrincipalType = $ServicePrincipal.ServicePrincipalType
            AppId                = $ServicePrincipal.AppId
            AccountEnabled       = $ServicePrincipal.AccountEnabled
        }
    }

    foreach ($Group in $Groups) {
        $CacheUsersAndApps[$Group.Id] = @{
            DisplayName     = $Group.DisplayName
            Type            = "Group"
            Mail            = $Group.Mail
            SecurityEnabled = $Group.SecurityEnabled
        }
    }

    $CacheRoles = [ordered]@{}
    foreach ($Role in $Roles) {
        $CacheRoles[$Role.Id] = @{
            DisplayName = $Role.DisplayName
            Description = $Role.Description
            IsBuiltIn   = $Role.IsBuiltIn
        }
    }

        # Translate role name to role ID if specified
    $ResolvedRoleId = $RoleId
    if ($RoleName) {
        $MatchingRoles = $CacheRoles.Keys | Where-Object { $CacheRoles[$_].DisplayName -like $RoleName }
        if ($MatchingRoles) {
            $ResolvedRoleId = $MatchingRoles
            Write-Verbose "Found $($MatchingRoles.Count) role(s) matching '$RoleName'"
        } else {
            Write-Warning "No roles found matching '$RoleName'"
            return
        }
    }

    # Translate UPN to principal ID if specified
    $ResolvedPrincipalId = $PrincipalId
    if ($UserPrincipalName) {
        $MatchingUsers = $CacheUsersAndApps.Keys | Where-Object {
            $CacheUsersAndApps[$_].UserPrincipalName -like $UserPrincipalName -or
            $CacheUsersAndApps[$_].DisplayName -like $UserPrincipalName
        }
        if ($MatchingUsers) {
            $ResolvedPrincipalId = $MatchingUsers
            Write-Verbose "Found $($MatchingUsers.Count) user(s) matching '$UserPrincipalName'"
        } else {
            Write-Warning "No users found matching '$UserPrincipalName'"
            return
        }
    }

    # Combine both assignment and eligibility requests
    $AllRequests = @()
    if ($RoleAssignmentRequests) {
        $AllRequests += $RoleAssignmentRequests | ForEach-Object {
            $_ | Add-Member -NotePropertyName 'RequestType' -NotePropertyValue 'Assignment' -PassThru
        }
    }
    if ($RoleEligibilityRequests) {
        $AllRequests += $RoleEligibilityRequests | ForEach-Object {
            $_ | Add-Member -NotePropertyName 'RequestType' -NotePropertyValue 'Eligibility' -PassThru
        }
    }

    # Apply filters if specified
    if ($ResolvedRoleId) {
        if ($ResolvedRoleId -is [array]) {
            $AllRequests = $AllRequests | Where-Object { $_.RoleDefinitionId -in $ResolvedRoleId }
        } else {
            $AllRequests = $AllRequests | Where-Object { $_.RoleDefinitionId -eq $ResolvedRoleId }
        }
    }

    if ($ResolvedPrincipalId) {
        if ($ResolvedPrincipalId -is [array]) {
            $AllRequests = $AllRequests | Where-Object { $_.PrincipalId -in $ResolvedPrincipalId }
        } else {
            $AllRequests = $AllRequests | Where-Object { $_.PrincipalId -eq $ResolvedPrincipalId }
        }
    }

    if (-not $IncludeAllStatuses) {
        $AllRequests = $AllRequests | Where-Object { $_.Status -in @('Provisioned', 'Revoked', 'Granted', 'Denied') }
    }

        # Process and format the results
    Write-Verbose "Processing $($AllRequests.Count) role requests (assignments and eligibility)..."

    [array]$Results = foreach ($Request in $AllRequests) {
        # Get principal information
        $Principal = $CacheUsersAndApps[$Request.PrincipalId]
        $PrincipalName = if ($Principal) { $Principal.DisplayName } else { "Unknown ($($Request.PrincipalId))" }
        $PrincipalType = if ($Principal) { $Principal.Type } else { "Unknown" }

        # Get role information
        $Role = $CacheRoles[$Request.RoleDefinitionId]
        $RoleName = if ($Role) { $Role.DisplayName } else { "Unknown Role ($($Request.RoleDefinitionId))" }

        # Translate action to readable format
        $ActionDescription = switch ($Request.Action) {
            'selfActivate' { 'User Activated Role' }
            'selfDeactivate' { 'User Deactivated Role' }
            'adminAssign' { if ($Request.RequestType -eq 'Eligibility') { 'Admin Assigned Eligible Role' } else { 'Admin Assigned Active Role' } }
            'adminRemove' { if ($Request.RequestType -eq 'Eligibility') { 'Admin Removed Eligible Role' } else { 'Admin Removed Active Role' } }
            'adminUpdate' { 'Admin Updated Assignment' }
            'selfExtend' { 'User Extended Role' }
            'adminExtend' { 'Admin Extended Role' }
            'provision' { 'Role Provisioned' }
            default { $Request.Action }
        }

        # Translate status to readable format
        $StatusDescription = switch ($Request.Status) {
            'Provisioned' { 'Completed Successfully' }
            'Revoked' { 'Revoked/Removed' }
            'Granted' { 'Granted' }
            'Denied' { 'Denied' }
            'PendingApproval' { 'Pending Approval' }
            'PendingScheduleCreation' { 'Pending Schedule Creation' }
            'Failed' { 'Failed' }
            default { $Request.Status }
        }

        # Calculate duration if available
        $Duration = $null
        if ($Request.ScheduleInfo -and $Request.ScheduleInfo.StartDateTime -and $Request.ScheduleInfo.Expiration -and $Request.ScheduleInfo.Expiration.EndDateTime) {
            $StartTime = [DateTime]$Request.ScheduleInfo.StartDateTime
            $EndTime = [DateTime]$Request.ScheduleInfo.Expiration.EndDateTime
            $Duration = ($EndTime - $StartTime).ToString()
        }

        [PSCustomObject]@{
            RequestId             = $Request.Id
            CreatedDateTime       = $Request.CreatedDateTime
            CompletedDateTime     = $Request.CompletedDateTime
            Action                = $ActionDescription
            Status                = $StatusDescription
            RequestType           = $Request.RequestType
            RoleName              = $RoleName
            RoleId                = $Request.RoleDefinitionId
            PrincipalName         = $PrincipalName
            PrincipalType         = $PrincipalType
            PrincipalId           = $Request.PrincipalId
            PrincipalMail         = if ($Principal) { $Principal.Mail -or $Principal.UserPrincipalName } else { $null }
            Justification         = $Request.Justification
            DirectoryScope        = $Request.DirectoryScopeId
            Duration              = $Duration
            TicketNumber          = if ($Request.TicketInfo) { $Request.TicketInfo.TicketNumber } else { $null }
            TicketSystem          = if ($Request.TicketInfo) { $Request.TicketInfo.TicketSystem } else { $null }
            ApprovalId            = $Request.ApprovalId
            IsValidationOnly      = $Request.IsValidationOnly
            # Additional useful properties
            CreatedBy             = if ($Request.CreatedBy -and $Request.CreatedBy.User) { $Request.CreatedBy.User.DisplayName } else { 'System' }
            ScheduleType          = if ($Request.ScheduleInfo -and $Request.ScheduleInfo.Expiration) { $Request.ScheduleInfo.Expiration.Type } else { $null }
            ScheduleStartDateTime = if ($Request.ScheduleInfo) { $Request.ScheduleInfo.StartDateTime } else { $null }
            ScheduleEndDateTime   = if ($Request.ScheduleInfo -and $Request.ScheduleInfo.Expiration) { $Request.ScheduleInfo.Expiration.EndDateTime } else { $null }
        }
    }

    # Sort results by CreatedDateTime (newest first) and return
    $Results | Sort-Object CreatedDateTime -Descending
}
