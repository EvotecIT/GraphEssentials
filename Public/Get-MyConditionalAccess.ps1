function Get-MyConditionalAccess {
    <#
    .SYNOPSIS
    Gets conditional access policies from Microsoft Graph and categorizes them.

    .DESCRIPTION
    This function retrieves conditional access policies from Microsoft Graph API and
    categorizes them based on their purpose (MFA for admins, block legacy access, etc.).
    It can also include statistics about the policies when requested.

    .PARAMETER IncludeStatistics
    When specified, includes statistics about the policies in the output.

    .EXAMPLE
    Get-MyConditionalAccess

    Returns categorized conditional access policies.

    .EXAMPLE
    Get-MyConditionalAccess -IncludeStatistics

    Returns both statistics and categorized conditional access policies.
    #>

    [cmdletBinding()]
    param(
        [switch] $IncludeStatistics
    )

    Write-Verbose -Message "Get-MyConditionalAccess - Getting conditional access policies"
    try {
        [array]$ConditionalAccessPolicyArray = Get-MgIdentityConditionalAccessPolicy -All -Property * -ErrorAction Stop
        Write-Verbose -Message "Get-MyConditionalAccess - Retrieved $($ConditionalAccessPolicyArray.Count) conditional access policies"
    } catch {
        Write-Warning -Message "Get-MyConditionalAccess - Failed to get conditional access policies. Error: $($_.Exception.Message)"
        return
    }

    # Get Azure AD roles to map GUIDs to names
    $RolesHashTable = @{}
    Write-Verbose -Message "Get-MyConditionalAccess - Getting Azure AD directory roles"
    try {
        $Roles = Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop
        foreach ($Role in $Roles) {
            $RolesHashTable[$Role.Id] = $Role.DisplayName
        }
        Write-Verbose -Message "Get-MyConditionalAccess - Retrieved $($Roles.Count) directory roles"
    } catch {
        Write-Warning -Message "Get-MyConditionalAccess - Failed to get directory roles. Roles will be displayed as GUIDs. Error: $($_.Exception.Message)"
    }

    # Create hashtable for users and groups with default entries
    $UsersAndGroupsHashTable = @{
        'All'                   = 'All users'
        'GuestsOrExternalUsers' = 'All guests'
        'None'                  = 'No users'
    }

    # Known application mapping for common application IDs
    $ApplicationsHashTable = @{
        'All'                                  = 'All applications'
        'Office365'                            = 'Office 365'
        'MicrosoftAdminPortals'                = 'Microsoft Admin Portals'
        '00000003-0000-0ff1-ce00-000000000000' = 'Microsoft Graph'
        '00000002-0000-0ff1-ce00-000000000000' = 'Exchange Online'
        '00000004-0000-0ff1-ce00-000000000000' = 'Microsoft 365 Exchange Online'
        '00000003-0000-0000-c000-000000000000' = 'Azure AD Graph API'
        '00000002-0000-0000-c000-000000000000' = 'Azure AD'
        '00000007-0000-0ff1-ce00-000000000000' = 'Microsoft Teams'
        '00000006-0000-0ff1-ce00-000000000000' = 'Microsoft SharePoint Online'
        '09abbdfd-ed23-44ee-a2d9-a627aa1c90f3' = 'Microsoft Azure Management'
        '797f4846-ba00-4fd7-ba43-dac1f8f63013' = 'Office 365 Management'
    }

    # Authentication strength mappings - predefined common values
    $AuthStrengthTable = @{
        'FedMFA'                                = 'Federated MFA'
        'Phishing-resistant MFA'                = 'Phishing-resistant MFA'
        'WindowsHelloForBusiness'               = 'Windows Hello for Business'
        'SuperiorSecurityFIDO2'                 = 'FIDO2 Security Key'
        'SuperiorSecurityPasswordless'          = 'Passwordless'
        'MultiFactorAuthentication'             = 'Multifactor Authentication'
        'PasswordlessWithSecurityKey'           = 'Passwordless with Security Key'
        'SecurePasswordAndPhishingResistantMFA' = 'Password + Phishing-resistant MFA'
    }

    # Try to get additional application information from Microsoft Graph
    Write-Verbose -Message "Get-MyConditionalAccess - Getting application information for ID resolution"
    try {
        $GraphApplications = Get-MgApplication -All -Property AppId, DisplayName -ErrorAction Stop
        foreach ($App in $GraphApplications) {
            if ($App.AppId -and $App.DisplayName) {
                $ApplicationsHashTable[$App.AppId] = $App.DisplayName
            }
        }
        Write-Verbose -Message "Get-MyConditionalAccess - Retrieved $($GraphApplications.Count) applications for ID resolution"
    } catch {
        Write-Warning -Message "Get-MyConditionalAccess - Failed to get application information. Some application IDs may not be resolved. Error: $($_.Exception.Message)"
    }

    # Get authentication strength policies
    Write-Verbose -Message "Get-MyConditionalAccess - Getting authentication strength information"
    try {
        $AuthStrengths = Get-MgPolicyAuthenticationStrengthPolicy -ErrorAction Stop
        foreach ($Strength in $AuthStrengths) {
            $AuthStrengthTable[$Strength.Id] = $Strength.DisplayName
        }
        Write-Verbose -Message "Get-MyConditionalAccess - Retrieved $($AuthStrengths.Count) authentication strength policies"
    } catch {
        Write-Warning -Message "Get-MyConditionalAccess - Failed to get authentication strength information. Using predefined values only. Error: $($_.Exception.Message)"
    }

    # Extract all user, group, application, location, and authentication context IDs from policies for targeted lookup
    $userIdsToLookup = [System.Collections.Generic.HashSet[string]]::new()
    $groupIdsToLookup = [System.Collections.Generic.HashSet[string]]::new()
    $appIdsToLookup = [System.Collections.Generic.HashSet[string]]::new()
    $locationIdsToLookup = [System.Collections.Generic.HashSet[string]]::new()
    $authContextIdsToLookup = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($CAPolicy in $ConditionalAccessPolicyArray) {
        # Collect user IDs
        if ($CAPolicy.Conditions.Users.IncludeUsers) {
            foreach ($userId in $CAPolicy.Conditions.Users.IncludeUsers) {
                if ($userId -notin @('All', 'GuestsOrExternalUsers', 'None')) {
                    [void]$userIdsToLookup.Add($userId)
                }
            }
        }

        if ($CAPolicy.Conditions.Users.ExcludeUsers) {
            foreach ($userId in $CAPolicy.Conditions.Users.ExcludeUsers) {
                if ($userId -notin @('All', 'GuestsOrExternalUsers', 'None')) {
                    [void]$userIdsToLookup.Add($userId)
                }
            }
        }

        # Collect group IDs
        if ($CAPolicy.Conditions.Users.IncludeGroups) {
            foreach ($groupId in $CAPolicy.Conditions.Users.IncludeGroups) {
                [void]$groupIdsToLookup.Add($groupId)
            }
        }

        if ($CAPolicy.Conditions.Users.ExcludeGroups) {
            foreach ($groupId in $CAPolicy.Conditions.Users.ExcludeGroups) {
                [void]$groupIdsToLookup.Add($groupId)
            }
        }

        # Collect application IDs for include/exclude lists
        if ($CAPolicy.Conditions.Applications.IncludeApplications) {
            foreach ($appId in $CAPolicy.Conditions.Applications.IncludeApplications) {
                $parsedGuid = [guid]::Empty
                if ([guid]::TryParse($appId, [ref] $parsedGuid)) {
                    [void]$appIdsToLookup.Add($appId)
                }
            }
        }

        if ($CAPolicy.Conditions.Applications.ExcludeApplications) {
            foreach ($appId in $CAPolicy.Conditions.Applications.ExcludeApplications) {
                $parsedGuid = [guid]::Empty
                if ([guid]::TryParse($appId, [ref] $parsedGuid)) {
                    [void]$appIdsToLookup.Add($appId)
                }
            }
        }

        # Collect named location IDs for include/exclude lists
        if ($CAPolicy.Conditions.Locations.IncludeLocations) {
            foreach ($locationId in $CAPolicy.Conditions.Locations.IncludeLocations) {
                $parsedGuid = [guid]::Empty
                if ([guid]::TryParse($locationId, [ref] $parsedGuid)) {
                    [void]$locationIdsToLookup.Add($locationId)
                }
            }
        }

        if ($CAPolicy.Conditions.Locations.ExcludeLocations) {
            foreach ($locationId in $CAPolicy.Conditions.Locations.ExcludeLocations) {
                $parsedGuid = [guid]::Empty
                if ([guid]::TryParse($locationId, [ref] $parsedGuid)) {
                    [void]$locationIdsToLookup.Add($locationId)
                }
            }
        }

        # Collect authentication context references
        if ($CAPolicy.Conditions.Applications.IncludeAuthenticationContextClassReferences) {
            foreach ($contextId in $CAPolicy.Conditions.Applications.IncludeAuthenticationContextClassReferences) {
                if ($contextId) {
                    [void]$authContextIdsToLookup.Add($contextId)
                }
            }
        }
    }

    Write-Verbose -Message "Get-MyConditionalAccess - Found $($userIdsToLookup.Count) unique user IDs and $($groupIdsToLookup.Count) unique group IDs to resolve"
    Write-Verbose -Message "Get-MyConditionalAccess - Found $($appIdsToLookup.Count) unique application IDs and $($locationIdsToLookup.Count) unique location IDs to resolve"

    # Lookup users by ID in batches
    if ($userIdsToLookup.Count -gt 0) {
        $batchSize = 15 # Microsoft Graph has limits on URL length
        $userIdBatches = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
        $currentBatch = [System.Collections.Generic.List[string]]::new()

        foreach ($userId in $userIdsToLookup) {
            if ($currentBatch.Count -eq $batchSize) {
                $userIdBatches.Add($currentBatch)
                $currentBatch = [System.Collections.Generic.List[string]]::new()
            }
            $currentBatch.Add($userId)
        }

        if ($currentBatch.Count -gt 0) {
            $userIdBatches.Add($currentBatch)
        }

        foreach ($batch in $userIdBatches) {
            try {
                $filter = "id in ('" + ($batch -join "','") + "')"
                Write-Verbose -Message "Get-MyConditionalAccess - Looking up users with filter: $filter"
                $batchUsers = Get-MgUser -Filter $filter -Property Id, DisplayName, UserPrincipalName -ErrorAction Stop
                foreach ($user in $batchUsers) {
                    $UsersAndGroupsHashTable[$user.Id] = "$($user.DisplayName) ($($user.UserPrincipalName))"
                }
            } catch {
                Write-Warning -Message "Get-MyConditionalAccess - Failed to resolve some user IDs. Error: $($_.Exception.Message)"
            }
        }
    }

    # Lookup groups by ID in batches
    if ($groupIdsToLookup.Count -gt 0) {
        $batchSize = 15
        $groupIdBatches = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
        $currentBatch = [System.Collections.Generic.List[string]]::new()

        foreach ($groupId in $groupIdsToLookup) {
            if ($currentBatch.Count -eq $batchSize) {
                $groupIdBatches.Add($currentBatch)
                $currentBatch = [System.Collections.Generic.List[string]]::new()
            }
            $currentBatch.Add($groupId)
        }

        if ($currentBatch.Count -gt 0) {
            $groupIdBatches.Add($currentBatch)
        }

        foreach ($batch in $groupIdBatches) {
            try {
                $filter = "id in ('" + ($batch -join "','") + "')"
                Write-Verbose -Message "Get-MyConditionalAccess - Looking up groups with filter: $filter"
                $batchGroups = Get-MgGroup -Filter $filter -Property Id, DisplayName, Mail -ErrorAction Stop
                foreach ($group in $batchGroups) {
                    $GroupMail = if ($group.Mail) { " ($($group.Mail))" } else { "" }
                    $UsersAndGroupsHashTable[$group.Id] = "Group: $($group.DisplayName)$GroupMail"
                }
            } catch {
                Write-Warning -Message "Get-MyConditionalAccess - Failed to resolve some group IDs. Error: $($_.Exception.Message)"
            }
        }
    }

    # Lookup service principals to resolve application IDs not found in app registrations
    if ($appIdsToLookup.Count -gt 0) {
        $servicePrincipalIdsToLookup = [System.Collections.Generic.List[string]]::new()
        foreach ($appId in $appIdsToLookup) {
            if (-not $ApplicationsHashTable.ContainsKey($appId)) {
                $servicePrincipalIdsToLookup.Add($appId)
            }
        }

        if ($servicePrincipalIdsToLookup.Count -gt 0) {
            Write-Verbose -Message "Get-MyConditionalAccess - Resolving $($servicePrincipalIdsToLookup.Count) application IDs via service principals"
            $batchSize = 10
            $servicePrincipalBatches = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
            $currentBatch = [System.Collections.Generic.List[string]]::new()

            foreach ($appId in $servicePrincipalIdsToLookup) {
                if ($currentBatch.Count -eq $batchSize) {
                    $servicePrincipalBatches.Add($currentBatch)
                    $currentBatch = [System.Collections.Generic.List[string]]::new()
                }
                $currentBatch.Add($appId)
            }

            if ($currentBatch.Count -gt 0) {
                $servicePrincipalBatches.Add($currentBatch)
            }

            foreach ($batch in $servicePrincipalBatches) {
                try {
                    $filterParts = [System.Collections.Generic.List[string]]::new()
                    foreach ($appId in $batch) {
                        $filterParts.Add("appId eq '$appId'")
                    }
                    $filter = $filterParts -join ' or '
                    Write-Verbose -Message "Get-MyConditionalAccess - Looking up service principals with filter: $filter"
                    $servicePrincipals = Get-MgServicePrincipal -Filter $filter -Property AppId, DisplayName -ErrorAction Stop
                    foreach ($servicePrincipal in $servicePrincipals) {
                        if ($servicePrincipal.AppId -and $servicePrincipal.DisplayName) {
                            $ApplicationsHashTable[$servicePrincipal.AppId] = $servicePrincipal.DisplayName
                        }
                    }
                } catch {
                    Write-Warning -Message "Get-MyConditionalAccess - Failed to resolve some application IDs via service principals. Error: $($_.Exception.Message)"
                }
            }
        }
    }

    # Lookup named locations for ID resolution
    $NamedLocationsHashTable = @{}
    if ($locationIdsToLookup.Count -gt 0) {
        Write-Verbose -Message "Get-MyConditionalAccess - Getting named locations for ID resolution"
        $NamedLocations = Get-MyNamedLocation
        if ($NamedLocations) {
            foreach ($Location in $NamedLocations) {
                if ($Location.Id -and $Location.DisplayName -and (-not $NamedLocationsHashTable.ContainsKey($Location.Id))) {
                    $NamedLocationsHashTable[$Location.Id] = $Location.DisplayName
                }
            }
        }
    }

    # Lookup authentication contexts for ID resolution
    $AuthContextHashTable = @{}
    if ($authContextIdsToLookup.Count -gt 0) {
        Write-Verbose -Message "Get-MyConditionalAccess - Getting authentication contexts for ID resolution"
        $AuthContexts = Get-MyAuthenticationContext
        if ($AuthContexts) {
            foreach ($AuthContext in $AuthContexts) {
                if ($AuthContext.Id -and $AuthContext.DisplayName -and (-not $AuthContextHashTable.ContainsKey($AuthContext.Id))) {
                    $AuthContextHashTable[$AuthContext.Id] = $AuthContext.DisplayName
                }
            }
        }
    }

    # Stage arrays for each category
    $CategorizedPolicies = [ordered] @{
        All                 = [System.Collections.Generic.List[PSCustomObject]]::new()
        BlockLegacyAccess   = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforAdmins        = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforUsers         = [System.Collections.Generic.List[PSCustomObject]]::new()
        Risk                = [System.Collections.Generic.List[PSCustomObject]]::new()
        AppProtection       = [System.Collections.Generic.List[PSCustomObject]]::new()
        DeviceCompliance    = [System.Collections.Generic.List[PSCustomObject]]::new()
        UsingLocations      = [System.Collections.Generic.List[PSCustomObject]]::new()
        RestrictAdminPortal = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforDeviceJoin    = [System.Collections.Generic.List[PSCustomObject]]::new()
        Uncategorized       = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    # Statistics
    $Statistics = @{
        TotalCount            = $ConditionalAccessPolicyArray.Count
        MicrosoftManagedCount = 0
        EnabledCount          = 0
        ReportOnlyCount       = 0
        DisabledCount         = 0
    }

    Write-Verbose -Message "Get-MyConditionalAccess - Categorizing $($ConditionalAccessPolicyArray.Count) conditional access policies"

    $Today = Get-Date

    foreach ($CAPolicy in $ConditionalAccessPolicyArray) {
        # Update statistics during the loop for better performance
        if ($CAPolicy.DisplayName -like 'Microsoft-managed:*') {
            $Statistics.MicrosoftManagedCount++
        }

        switch ($CAPolicy.State) {
            'enabled' { $Statistics.EnabledCount++ }
            'enabledForReportingButNotEnforced' { $Statistics.ReportOnlyCount++ }
            'disabled' { $Statistics.DisabledCount++ }
        }

        $PolicyCategorized = $false
        $PolicyType = [System.Collections.Generic.List[string]]::new()

        # Convert role IDs to readable names
        $IncludedRoleNames = [System.Collections.Generic.List[string]]::new()
        $ExcludedRoleNames = [System.Collections.Generic.List[string]]::new()

        if ($CAPolicy.Conditions.Users.IncludeRoles) {
            foreach ($RoleId in $CAPolicy.Conditions.Users.IncludeRoles) {
                if ($RolesHashTable.ContainsKey($RoleId)) {
                    $IncludedRoleNames.Add($RolesHashTable[$RoleId])
                } else {
                    $IncludedRoleNames.Add("Unknown role ($RoleId)")
                }
            }
        }

        if ($CAPolicy.Conditions.Users.ExcludeRoles) {
            foreach ($RoleId in $CAPolicy.Conditions.Users.ExcludeRoles) {
                if ($RolesHashTable.ContainsKey($RoleId)) {
                    $ExcludedRoleNames.Add($RolesHashTable[$RoleId])
                } else {
                    $ExcludedRoleNames.Add("Unknown role ($RoleId)")
                }
            }
        }

        # Convert user IDs to readable names
        $IncludedUserNames = [System.Collections.Generic.List[string]]::new()
        $ExcludedUserNames = [System.Collections.Generic.List[string]]::new()

        if ($CAPolicy.Conditions.Users.IncludeUsers) {
            foreach ($UserId in $CAPolicy.Conditions.Users.IncludeUsers) {
                if ($UsersAndGroupsHashTable.ContainsKey($UserId)) {
                    $IncludedUserNames.Add($UsersAndGroupsHashTable[$UserId])
                } else {
                    $IncludedUserNames.Add($UserId)
                }
            }
        }

        if ($CAPolicy.Conditions.Users.ExcludeUsers) {
            foreach ($UserId in $CAPolicy.Conditions.Users.ExcludeUsers) {
                if ($UsersAndGroupsHashTable.ContainsKey($UserId)) {
                    $ExcludedUserNames.Add($UsersAndGroupsHashTable[$UserId])
                } else {
                    $ExcludedUserNames.Add($UserId)
                }
            }
        }

        # Convert group IDs to readable names
        $IncludedGroupNames = [System.Collections.Generic.List[string]]::new()
        $ExcludedGroupNames = [System.Collections.Generic.List[string]]::new()

        if ($CAPolicy.Conditions.Users.IncludeGroups) {
            foreach ($GroupId in $CAPolicy.Conditions.Users.IncludeGroups) {
                if ($UsersAndGroupsHashTable.ContainsKey($GroupId)) {
                    $IncludedGroupNames.Add($UsersAndGroupsHashTable[$GroupId])
                } else {
                    $IncludedGroupNames.Add("Unknown group ($GroupId)")
                }
            }
        }

        if ($CAPolicy.Conditions.Users.ExcludeGroups) {
            foreach ($GroupId in $CAPolicy.Conditions.Users.ExcludeGroups) {
                if ($UsersAndGroupsHashTable.ContainsKey($GroupId)) {
                    $ExcludedGroupNames.Add($UsersAndGroupsHashTable[$GroupId])
                } else {
                    $ExcludedGroupNames.Add("Unknown group ($GroupId)")
                }
            }
        }

        # Convert application IDs to readable names
        $ApplicationNames = [System.Collections.Generic.List[string]]::new()
        if ($CAPolicy.Conditions.Applications.IncludeApplications) {
            foreach ($AppId in $CAPolicy.Conditions.Applications.IncludeApplications) {
                if ($ApplicationsHashTable.ContainsKey($AppId)) {
                    $ApplicationNames.Add($ApplicationsHashTable[$AppId])
                } else {
                    $ApplicationNames.Add($AppId)
                }
            }
        }

        $ApplicationExcludedNames = [System.Collections.Generic.List[string]]::new()
        if ($CAPolicy.Conditions.Applications.ExcludeApplications) {
            foreach ($AppId in $CAPolicy.Conditions.Applications.ExcludeApplications) {
                if ($ApplicationsHashTable.ContainsKey($AppId)) {
                    $ApplicationExcludedNames.Add($ApplicationsHashTable[$AppId])
                } else {
                    $ApplicationExcludedNames.Add($AppId)
                }
            }
        }

        # Convert location IDs to readable names
        $LocationsIncludedNames = [System.Collections.Generic.List[string]]::new()
        $LocationsExcludedNames = [System.Collections.Generic.List[string]]::new()

        if ($CAPolicy.Conditions.Locations.IncludeLocations) {
            foreach ($LocationId in $CAPolicy.Conditions.Locations.IncludeLocations) {
                if ($NamedLocationsHashTable.ContainsKey($LocationId)) {
                    $LocationsIncludedNames.Add($NamedLocationsHashTable[$LocationId])
                } else {
                    $LocationsIncludedNames.Add($LocationId)
                }
            }
        }

        if ($CAPolicy.Conditions.Locations.ExcludeLocations) {
            foreach ($LocationId in $CAPolicy.Conditions.Locations.ExcludeLocations) {
                if ($NamedLocationsHashTable.ContainsKey($LocationId)) {
                    $LocationsExcludedNames.Add($NamedLocationsHashTable[$LocationId])
                } else {
                    $LocationsExcludedNames.Add($LocationId)
                }
            }
        }

        # Convert authentication context IDs to readable names
        $AuthContextNames = [System.Collections.Generic.List[string]]::new()
        if ($CAPolicy.Conditions.Applications.IncludeAuthenticationContextClassReferences) {
            foreach ($ContextId in $CAPolicy.Conditions.Applications.IncludeAuthenticationContextClassReferences) {
                if ($AuthContextHashTable.ContainsKey($ContextId)) {
                    $AuthContextNames.Add($AuthContextHashTable[$ContextId])
                } else {
                    $AuthContextNames.Add($ContextId)
                }
            }
        }

        # Extract platform, device, and filter data
        $PlatformsExcluded = [System.Collections.Generic.List[string]]::new()
        if ($CAPolicy.Conditions.Platforms.ExcludePlatforms) {
            foreach ($Platform in $CAPolicy.Conditions.Platforms.ExcludePlatforms) {
                $PlatformsExcluded.Add($Platform)
            }
        }

        $DevicesIncluded = [System.Collections.Generic.List[string]]::new()
        $DevicesExcluded = [System.Collections.Generic.List[string]]::new()
        $DeviceFilterRule = $null
        $DeviceFilterMode = $null

        if ($CAPolicy.Conditions.Devices) {
            if ($CAPolicy.Conditions.Devices.IncludeDevices) {
                foreach ($Device in $CAPolicy.Conditions.Devices.IncludeDevices) {
                    $DevicesIncluded.Add($Device)
                }
            }
            if ($CAPolicy.Conditions.Devices.ExcludeDevices) {
                foreach ($Device in $CAPolicy.Conditions.Devices.ExcludeDevices) {
                    $DevicesExcluded.Add($Device)
                }
            }
            if ($CAPolicy.Conditions.Devices.DeviceFilter) {
                $DeviceFilterRule = $CAPolicy.Conditions.Devices.DeviceFilter.Rule
                $DeviceFilterMode = $CAPolicy.Conditions.Devices.DeviceFilter.Mode
            }
        }

        # Extract session control details
        $SessionControlsAdditionalProperties = $null
        $ApplicationEnforcedRestrictionsIsEnabled = $null
        $ApplicationEnforcedRestrictionsAdditionalProperties = $null
        $CloudAppSecurityType = $null
        $CloudAppSecurityIsEnabled = $null
        $CloudAppSecurityAdditionalProperties = $null
        $DisableResilienceDefaults = $null
        $PersistentBrowserIsEnabled = $null
        $PersistentBrowserMode = $null
        $PersistentBrowserAdditionalProperties = $null
        $SignInFrequencyAuthenticationType = $null
        $SignInFrequencyInterval = $null
        $SignInFrequencyIsEnabled = $null
        $SignInFrequencyType = $null
        $SignInFrequencyValue = $null
        $SignInFrequencyAdditionalProperties = $null

        $SessionControlsAdditionalPropertiesDisplay = $null
        $ApplicationEnforcedRestrictionsAdditionalPropertiesDisplay = $null
        $CloudAppSecurityAdditionalPropertiesDisplay = $null
        $PersistentBrowserAdditionalPropertiesDisplay = $null
        $SignInFrequencyAdditionalPropertiesDisplay = $null

        if ($CAPolicy.SessionControls) {
            $SessionControlsAdditionalProperties = $CAPolicy.SessionControls.AdditionalProperties
            $DisableResilienceDefaults = $CAPolicy.SessionControls.DisableResilienceDefaults

            if ($CAPolicy.SessionControls.ApplicationEnforcedRestrictions) {
                $ApplicationEnforcedRestrictionsIsEnabled = $CAPolicy.SessionControls.ApplicationEnforcedRestrictions.IsEnabled
                $ApplicationEnforcedRestrictionsAdditionalProperties = $CAPolicy.SessionControls.ApplicationEnforcedRestrictions.AdditionalProperties
            }

            if ($CAPolicy.SessionControls.CloudAppSecurity) {
                $CloudAppSecurityType = $CAPolicy.SessionControls.CloudAppSecurity.CloudAppSecurityType
                $CloudAppSecurityIsEnabled = $CAPolicy.SessionControls.CloudAppSecurity.IsEnabled
                $CloudAppSecurityAdditionalProperties = $CAPolicy.SessionControls.CloudAppSecurity.AdditionalProperties
            }

            if ($CAPolicy.SessionControls.PersistentBrowser) {
                $PersistentBrowserIsEnabled = $CAPolicy.SessionControls.PersistentBrowser.IsEnabled
                $PersistentBrowserMode = $CAPolicy.SessionControls.PersistentBrowser.Mode
                $PersistentBrowserAdditionalProperties = $CAPolicy.SessionControls.PersistentBrowser.AdditionalProperties
            }

            if ($CAPolicy.SessionControls.SignInFrequency) {
                $SignInFrequencyAuthenticationType = $CAPolicy.SessionControls.SignInFrequency.AuthenticationType
                $SignInFrequencyInterval = $CAPolicy.SessionControls.SignInFrequency.FrequencyInterval
                $SignInFrequencyIsEnabled = $CAPolicy.SessionControls.SignInFrequency.IsEnabled
                $SignInFrequencyType = $CAPolicy.SessionControls.SignInFrequency.Type
                $SignInFrequencyValue = $CAPolicy.SessionControls.SignInFrequency.Value
                $SignInFrequencyAdditionalProperties = $CAPolicy.SessionControls.SignInFrequency.AdditionalProperties
            }
        }

        $SessionControlsAdditionalPropertiesDisplay = ConvertTo-MyDisplayString -Value $SessionControlsAdditionalProperties
        $ApplicationEnforcedRestrictionsAdditionalPropertiesDisplay = ConvertTo-MyDisplayString -Value $ApplicationEnforcedRestrictionsAdditionalProperties
        $CloudAppSecurityAdditionalPropertiesDisplay = ConvertTo-MyDisplayString -Value $CloudAppSecurityAdditionalProperties
        $PersistentBrowserAdditionalPropertiesDisplay = ConvertTo-MyDisplayString -Value $PersistentBrowserAdditionalProperties
        $SignInFrequencyAdditionalPropertiesDisplay = ConvertTo-MyDisplayString -Value $SignInFrequencyAdditionalProperties

        # Extract grant control details
        $GrantControlsTermsOfUse = $null
        $GrantControlsCustomControls = $null
        $GrantControlsOperator = $null
        if ($CAPolicy.GrantControls) {
            $GrantControlsTermsOfUse = $CAPolicy.GrantControls.TermsOfUse
            $GrantControlsCustomControls = $CAPolicy.GrantControls.CustomAuthenticationFactors
            $GrantControlsOperator = $CAPolicy.GrantControls.Operator
        }

        # Calculate creation and modification days
        $CreatedDays = $null
        $ModifiedDays = $null

        if ($CAPolicy.CreatedDateTime) {
            $CreatedDays = ($Today - $CAPolicy.CreatedDateTime).Days
        }

        if ($CAPolicy.ModifiedDateTime) {
            $ModifiedDays = ($Today - $CAPolicy.ModifiedDateTime).Days
        }

        # Resolve Authentication Strength
        $AuthStrengthName = $null
        if ($CAPolicy.GrantControls.AuthenticationStrength.Id) {
            if ($AuthStrengthTable.ContainsKey($CAPolicy.GrantControls.AuthenticationStrength.Id)) {
                $AuthStrengthName = $AuthStrengthTable[$CAPolicy.GrantControls.AuthenticationStrength.Id]
            } else {
                $AuthStrengthName = "Unknown strength ($($CAPolicy.GrantControls.AuthenticationStrength.Id))"
            }
        }

        $UsersInclude = [System.Collections.Generic.List[string]]::new()
        foreach ($Value in $IncludedUserNames) {
            $UsersInclude.Add($Value)
        }
        foreach ($Value in $IncludedGroupNames) {
            $UsersInclude.Add($Value)
        }
        foreach ($Value in $IncludedRoleNames) {
            $UsersInclude.Add($Value)
        }

        $UsersExclude = [System.Collections.Generic.List[string]]::new()
        foreach ($Value in $ExcludedUserNames) {
            $UsersExclude.Add($Value)
        }
        foreach ($Value in $ExcludedGroupNames) {
            $UsersExclude.Add($Value)
        }
        foreach ($Value in $ExcludedRoleNames) {
            $UsersExclude.Add($Value)
        }

        # Convert to PSCustomObject for consistent output
        $PolicyObj = [PSCustomObject]@{
            DisplayName        = $CAPolicy.DisplayName
            Id                 = $CAPolicy.Id
            State              = $CAPolicy.State
            CreatedDateTime    = $CAPolicy.CreatedDateTime
            ModifiedDateTime   = $CAPolicy.ModifiedDateTime
            CreatedDays        = $CreatedDays
            ModifiedDays       = $ModifiedDays
            Type               = $null # Will be populated below
            IncludedUsersGuid  = $CAPolicy.Conditions.Users.IncludeUsers
            ExcludedUsersGuid  = $CAPolicy.Conditions.Users.ExcludeUsers
            IncludedGroupsGuid = $CAPolicy.Conditions.Users.IncludeGroups
            ExcludedGroupsGuid = $CAPolicy.Conditions.Users.ExcludeGroups
            IncludedRolesGuid  = $CAPolicy.Conditions.Users.IncludeRoles
            ExcludedRolesGuid  = $CAPolicy.Conditions.Users.ExcludeRoles
            IncludedUsers      = $IncludedUserNames
            ExcludedUsers      = $ExcludedUserNames
            IncludedGroups     = $IncludedGroupNames
            ExcludedGroups     = $ExcludedGroupNames
            IncludedRoles      = $IncludedRoleNames
            ExcludedRoles      = $ExcludedRoleNames
            UsersInclude       = $UsersInclude
            UsersExclude       = $UsersExclude
            ClientAppTypes     = $CAPolicy.Conditions.ClientAppTypes
            ApplicationsGuid   = $CAPolicy.Conditions.Applications.IncludeApplications
            Applications       = $ApplicationNames
            ApplicationsExcludedGuid = $CAPolicy.Conditions.Applications.ExcludeApplications
            ApplicationsExcluded     = $ApplicationExcludedNames
            UserActions        = $CAPolicy.Conditions.Applications.IncludeUserActions
            AuthContextGuid    = $CAPolicy.Conditions.Applications.IncludeAuthenticationContextClassReferences
            AuthContext        = $AuthContextNames
            Platforms          = $CAPolicy.Conditions.Platforms.IncludePlatforms
            PlatformsExcluded  = $PlatformsExcluded
            LocationsGuid      = $CAPolicy.Conditions.Locations.IncludeLocations
            Locations          = $LocationsIncludedNames
            LocationsExcludedGuid = $CAPolicy.Conditions.Locations.ExcludeLocations
            LocationsExcluded     = $LocationsExcludedNames
            SignInRiskLevels   = $CAPolicy.Conditions.SignInRiskLevels
            UserRiskLevels     = $CAPolicy.Conditions.UserRiskLevels
            DevicesIncluded    = $DevicesIncluded
            DevicesExcluded    = $DevicesExcluded
            DeviceFilterRule   = $DeviceFilterRule
            DeviceFilterMode   = $DeviceFilterMode
            GrantControls      = $CAPolicy.GrantControls.BuiltInControls
            GrantControlsTermsOfUse     = $GrantControlsTermsOfUse
            GrantControlsCustomControls = $GrantControlsCustomControls
            GrantControlsOperator       = $GrantControlsOperator
            AuthStrengthGuid   = $CAPolicy.GrantControls.AuthenticationStrength.Id
            AuthStrength       = $AuthStrengthName
            SessionControlsAdditionalProperties                 = $SessionControlsAdditionalPropertiesDisplay
            ApplicationEnforcedRestrictionsIsEnabled            = $ApplicationEnforcedRestrictionsIsEnabled
            ApplicationEnforcedRestrictionsAdditionalProperties = $ApplicationEnforcedRestrictionsAdditionalPropertiesDisplay
            CloudAppSecurityType                                = $CloudAppSecurityType
            CloudAppSecurityIsEnabled                           = $CloudAppSecurityIsEnabled
            CloudAppSecurityAdditionalProperties                = $CloudAppSecurityAdditionalPropertiesDisplay
            DisableResilienceDefaults                           = $DisableResilienceDefaults
            PersistentBrowserIsEnabled                          = $PersistentBrowserIsEnabled
            PersistentBrowserMode                               = $PersistentBrowserMode
            PersistentBrowserAdditionalProperties               = $PersistentBrowserAdditionalPropertiesDisplay
            SignInFrequencyAuthenticationType                   = $SignInFrequencyAuthenticationType
            SignInFrequencyInterval                             = $SignInFrequencyInterval
            SignInFrequencyIsEnabled                            = $SignInFrequencyIsEnabled
            SignInFrequencyType                                 = $SignInFrequencyType
            SignInFrequencyValue                                = $SignInFrequencyValue
            SignInFrequencyAdditionalProperties                 = $SignInFrequencyAdditionalPropertiesDisplay
        }

        # Add to All collection
        $CategorizedPolicies.All.Add($PolicyObj)

        # Policy that blocks legacy authentication (EAS, or other)
        if ((($CAPolicy.Conditions.ClientAppTypes -contains 'exchangeActiveSync') -or ($CAPolicy.Conditions.ClientAppTypes -contains 'other')) -and
            (($CAPolicy.Conditions.ClientAppTypes -notcontains 'browser') -and ($CAPolicy.Conditions.ClientAppTypes -notcontains 'mobileAppsAndDesktopClients')) -and
            ($CAPolicy.GrantControls.BuiltInControls -eq 'block')) {
            $CategorizedPolicies.BlockLegacyAccess.Add($PolicyObj)
            $PolicyType.Add('BlockLegacyAccess')
            $PolicyCategorized = $true
        }

        # Policy that requires MFA for admins
        if ((($CAPolicy.GrantControls.BuiltInControls -contains 'mfa') -or ($CAPolicy.GrantControls.AuthenticationStrength.Id)) -and
            ($CAPolicy.Conditions.Users.IncludeRoles)) {
            $CategorizedPolicies.MFAforAdmins.Add($PolicyObj)
            $PolicyType.Add('MFAforAdmins')
            $PolicyCategorized = $true
        }

        # Policy that requires MFA for users
        if ((($CAPolicy.GrantControls.BuiltInControls -contains 'mfa') -or ($CAPolicy.GrantControls.AuthenticationStrength.Id)) -and
            (($CAPolicy.Conditions.Users.IncludeUsers -contains 'All') -or ($CAPolicy.Conditions.Users.IncludeGroups))) {
            $CategorizedPolicies.MFAforUsers.Add($PolicyObj)
            $PolicyType.Add('MFAforUsers')
            $PolicyCategorized = $true
        }

        # Policy that addresses risky users or sign-ins
        if (($CAPolicy.Conditions.SignInRiskLevels) -or ($CAPolicy.Conditions.UserRiskLevels)) {
            $CategorizedPolicies.Risk.Add($PolicyObj)
            $PolicyType.Add('Risk')
            $PolicyCategorized = $true
        }

        # Policy that targets mobile platforms
        if (($CAPolicy.Conditions.Platforms.IncludePlatforms -contains 'Android') -and
            ($CAPolicy.Conditions.Platforms.IncludePlatforms -contains 'iOS')) {
            $CategorizedPolicies.AppProtection.Add($PolicyObj)
            $PolicyType.Add('AppProtection')
            $PolicyCategorized = $true
        }

        # Policy that requires device compliance
        if (($CAPolicy.GrantControls.BuiltInControls -contains 'compliantDevice') -or
            ($CAPolicy.GrantControls.BuiltInControls -contains 'domainJoinedDevice')) {
            $CategorizedPolicies.DeviceCompliance.Add($PolicyObj)
            $PolicyType.Add('DeviceCompliance')
            $PolicyCategorized = $true
        }

        # Policy that uses locations
        if ($CAPolicy.Conditions.Locations.IncludeLocations -or $CAPolicy.Conditions.Locations.ExcludeLocations) {
            $CategorizedPolicies.UsingLocations.Add($PolicyObj)
            $PolicyType.Add('UsingLocations')
            $PolicyCategorized = $true
        }

        # Policy that restricts access to admin portal
        if ($CAPolicy.Conditions.Applications.IncludeApplications -contains 'MicrosoftAdminPortals') {
            $CategorizedPolicies.RestrictAdminPortal.Add($PolicyObj)
            $PolicyType.Add('RestrictAdminPortal')
            $PolicyCategorized = $true
        }

        # Policy that requires MFA for device registration
        if ($CAPolicy.Conditions.Applications.IncludeUserActions -like '*registerdevice*') {
            $CategorizedPolicies.MFAforDeviceJoin.Add($PolicyObj)
            $PolicyType.Add('MFAforDeviceJoin')
            $PolicyCategorized = $true
        }

        # If policy doesn't fit into any category
        if (-not $PolicyCategorized) {
            $CategorizedPolicies.Uncategorized.Add($PolicyObj)
            $PolicyType.Add('Uncategorized')
        }

        # Set the Type property with the categories
        $PolicyObj.Type = $PolicyType
    }

    # Check MFA policies that target admin roles to see if they include the 14 default roles
    if ($CategorizedPolicies.MFAforAdmins.Count -gt 0) {
        Write-Verbose -Message "Get-MyConditionalAccess - Analyzing MFA policies for admin roles"
        $default14Roles = @(
            '62e90394-69f5-4237-9190-012177145e10', # Global Administrator
            '194ae4cb-b126-40b2-bd5b-6091b380977d', # Privileged Role Administrator
            'f28a1f50-f6e7-4571-818b-6a12f2af6b6c', # Security Administrator
            '29232cdf-9323-42fd-ade2-1d097af3e4de', # Authentication Administrator
            'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9', # SharePoint Administrator
            '729827e3-9c14-49f7-bb1b-9608f156bbb8', # Exchange Administrator
            'b0f54661-2d74-4c50-afa3-1ec803f12efe', # Teams Administrator
            'fe930be7-5e62-47db-91af-98c3a49a38b1', # User Administrator
            'c4e39bd9-1100-46d3-8c65-fb160da0071f', # Compliance Administrator
            '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3', # Application Administrator
            '158c047a-c907-4556-b7ef-446551a6b5f7', # Security Reader
            '966707d0-3269-4727-9be2-8c3a10f19b9d', # Conditional Access Administrator
            '7be44c8a-adaf-4e2a-84d6-ab2649e08a13', # Reports Reader
            'e8611ab8-c189-46e8-94e1-60213ab1f814'  # Cloud Application Administrator
        )

        $default14RoleNames = [System.Collections.Generic.List[string]]::new()
        foreach ($roleId in $default14Roles) {
            if ($RolesHashTable.ContainsKey($roleId)) {
                $default14RoleNames.Add($RolesHashTable[$roleId])
            }
        }

        $AdminRoleAnalysis = foreach ($adminCAP in $CategorizedPolicies.MFAforAdmins) {
            $defaultCount = 0
            $nonDefaultCount = 0
            $includeCount = 0
            $coveredDefaultRoles = [System.Collections.Generic.List[string]]::new()
            $additionalRoles = [System.Collections.Generic.List[string]]::new()

            if ($adminCAP.IncludedRolesGuid) {
                $includeCount = $adminCAP.IncludedRolesGuid.Count

                foreach ($role in $adminCAP.IncludedRolesGuid) {
                    if ($default14Roles -contains $role) {
                        $defaultCount++
                        if ($RolesHashTable.ContainsKey($role)) {
                            $coveredDefaultRoles.Add($RolesHashTable[$role])
                        }
                    } else {
                        $nonDefaultCount++
                        if ($RolesHashTable.ContainsKey($role)) {
                            $additionalRoles.Add($RolesHashTable[$role])
                        }
                    }
                }

                [PSCustomObject]@{
                    PolicyName      = $adminCAP.DisplayName
                    TotalRoles      = $includeCount
                    DefaultRoles    = "$defaultCount/14"
                    AdditionalRoles = $nonDefaultCount
                    CoveredDefaults = $coveredDefaultRoles
                    OtherRoles      = $additionalRoles
                }
            }
        }

        # Add the admin role analysis to categorized policies
        $CategorizedPolicies['AdminRoleAnalysis'] = $AdminRoleAnalysis
        $CategorizedPolicies['DefaultRoles'] = $default14RoleNames
    }

    if ($IncludeStatistics) {
        [ordered]@{
            Statistics = $Statistics
            Policies   = $CategorizedPolicies
        }
    } else {
        $CategorizedPolicies
    }
}
