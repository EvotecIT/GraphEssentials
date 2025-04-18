function Convert-GraphEssentialsAppToReportObject {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ServicePrincipal, # Service Principal object (contains AppId, DisplayName, Id, AppOwnerOrganizationId, AppRoleAssignments)

        [PSCustomObject]$ApplicationDetails, # Optional corresponding Application object (contains Notes, PasswordCredentials, KeyCredentials)

        # Pre-fetched Data Structures
        [string]$TenantId,
        [hashtable]$AllDelegatedPermissions, # Keyed by SP ID
        [hashtable]$SignInActivityReport,    # Keyed by AppId
        [hashtable]$LastSignInMethodReport,  # Keyed by AppId
        [string]$GraphSpId,
        [hashtable]$GraphAppRoles,

        # Options
        [switch]$IncludeCredentials
    )

    $spId = $ServicePrincipal.Id
    $appId = $ServicePrincipal.AppId
    $displayName = $ServicePrincipal.DisplayName
    $appOwnerOrganizationId = $ServicePrincipal.AppOwnerOrganizationId

    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Processing SP: $displayName ($appId - $spId)"

    # --- Determine Application Permissions ---
    $ApplicationScopes = $null
    if ($graphSpId -and $GraphAppRoles -and $ServicePrincipal.AppRoleAssignments) {
        $graphAssignments = $ServicePrincipal.AppRoleAssignments | Where-Object { $_.ResourceId -eq $GraphSpId }
        if ($graphAssignments) {
            $appRoles = $graphAssignments.AppRoleId | ForEach-Object { $GraphAppRoles[$_].Value } | Sort-Object -Unique
            if ($appRoles) {
                $ApplicationScopes = $appRoles
            }
        }
    }

    # --- Determine Source ---
    $Source = "Unknown"
    if ($TenantId) {
        if ($appOwnerOrganizationId -eq $TenantId) {
            $Source = "First Party"
        } elseif ($null -eq $appOwnerOrganizationId) {
            $Source = "Microsoft"
        } else {
            $Source = "Third Party"
        }
    } else {
        $Source = if ($null -ne $appOwnerOrganizationId) { "Third Party (Assumed)" } else { "First Party (Assumed)" }
    }

    # --- Get Owners (Combine SP and App Owners) ---
    $spOwnersRaw = Get-GraphEssentialsAppOwners -ServicePrincipalObjectId $spId
    $appOwnersRawList = [System.Collections.Generic.List[object]]::new() # Use generic list
    $ApplicationObjectId = if ($ApplicationDetails) { $ApplicationDetails.Id } else { $null }
    if ($ApplicationObjectId) {
        try {
            $rawAppOwnersResult = Get-MgApplicationOwner -ApplicationId $ApplicationObjectId -ErrorAction Stop
            if ($rawAppOwnersResult) {
                $rawAppOwnersResult | ForEach-Object {
                    $ownerDetail = $_ | Select-Object Id, DeletedDateTime, @{n = 'ODataType'; e = { $_.AdditionalProperties.'@odata.type' } }, AdditionalProperties
                    $appOwnersRawList.Add($ownerDetail) # Add to list
                }
            }
        } catch {
            Write-Warning "Convert-GraphEssentialsAppToReportObject: Failed to get owners for Application $ApplicationObjectId. Error: $($_.Exception.Message)"
            $appOwnersRawList.Add([PSCustomObject]@{ Error = "Error fetching app owners: $($_.Exception.Message)" }) # Add to list
        }
    }

    # Combine and format
    $allOwnerObjects = [System.Collections.Generic.List[object]]::new()
    if ($spOwnersRaw.Count -gt 1) {
        $allOwnerObjects.AddRange($spOwnersRaw)
    } elseif ($spOwnersRaw.Count -eq 1) {
        $allOwnerObjects.Add($spOwnersRaw)
    }
    if ($appOwnersRawList.Count -gt 1) {
        $allOwnerObjects.AddRange($appOwnersRawList)
    } elseif ($appOwnersRawList.Count -eq 1) {
        $allOwnerObjects.Add($appOwnersRawList)
    }

    $CombinedOwners = @()
    $processedOwnerIds = @{}
    $allOwnerObjects | ForEach-Object {
        $ownerObject = $_ # The richer object
        if ($ownerObject.PSObject.Properties['Id'] -and $processedOwnerIds.ContainsKey($ownerObject.Id)) {
            continue # Skip duplicate ID
        }
        if ($ownerObject.PSObject.Properties['Id']) {
            $processedOwnerIds[$ownerObject.Id] = $true
        }
        $ownerString = "(Processing error)" # Default
        if ($ownerObject.PSObject.Properties['Error']) {
            $ownerString = $ownerObject.Error # Use the error message
        } elseif ($ownerObject) {
            # Standard checks for AdditionalProperties hashtable
            $dispName = if ($ownerObject.AdditionalProperties.ContainsKey('displayName')) { $ownerObject.AdditionalProperties.displayName } else { $null }
            $upn = if ($ownerObject.AdditionalProperties.ContainsKey('userPrincipalName')) { $ownerObject.AdditionalProperties.userPrincipalName } else { $null }
            $mail = if ($ownerObject.AdditionalProperties.ContainsKey('mail')) { $ownerObject.AdditionalProperties.mail } else { $null }
            $oDataType = $ownerObject.ODataType
            $ownerString = $dispName # Start with display name if available

            # Add UPN or Mail
            if ($upn) { $ownerString += " <$upn>" }
            elseif ($mail) { $ownerString += " <$mail>" }

            # Add Type if available and name wasn't found
            if (-not $dispName -and $oDataType) { $ownerString = $oDataType }

            # Fallback to ID if still nothing useful
            if (-not $ownerString) { $ownerString = $ownerObject.Id }

            # Optionally add type in parentheses
            if ($oDataType) { $ownerString += " ($($oDataType.Split('.')[-1]))" }
        }
        $CombinedOwners += $ownerString
    }
    $CombinedOwners = $CombinedOwners | Sort-Object -Unique

    # --- Get Delegated Permissions ---
    $DelegatedScopes = if ($spId) { $AllDelegatedPermissions[$spId] } else { $null }

    # --- Get Sign-in Info ---
    $SignInInfo = $SignInActivityReport[$appId]
    $LastSignInMethod = $LastSignInMethodReport[$appId]

    # Determine Combined Permission Type
    $PermissionType = "None"
    if ($DelegatedScopes -and $ApplicationScopes) {
        $PermissionType = "Delegated & Application"
    } elseif ($DelegatedScopes) {
        $PermissionType = "Delegated"
    } elseif ($ApplicationScopes) {
        $PermissionType = "Application"
    }

    # --- Get Credentials Details & Summary ---
    $AppCredentialsDetails = $null
    $DaysToExpireOldest = $null
    $DaysToExpireNewest = $null
    $KeysExpired = 'Not available'
    $KeysTypes = @()
    $KeysDescription = @()
    $DescriptionWithEmail = $false
    $KeysCount = 0
    $KeysDateOldest = $null
    $KeysDateNewest = $null

    # Credentials require the corresponding Application object
    if ($ApplicationDetails) {
        Write-Verbose "Convert-GraphEssentialsAppToReportObject: Getting credentials details for $displayName from provided Application object."
        # Requires Get-MyAppCredentials function
        # Pass the Application object which contains needed credential properties
        $AppCredentialsDetails = Get-MyAppCredentials -ApplicationList $ApplicationDetails

        if ($AppCredentialsDetails) {
            $KeysCount = $AppCredentialsDetails.Count
            $KeysTypes = $AppCredentialsDetails.Type | Sort-Object -Unique
            $KeysDescription = $AppCredentialsDetails.KeyDisplayName | Sort-Object -Unique
            $DaysToExpire = $AppCredentialsDetails.DaysToExpire | Where-Object { $_ -ne $null } | Sort-Object
            if ($DaysToExpire.Count -gt 0) {
                $DaysToExpireOldest = $DaysToExpire[0]
                $DaysToExpireNewest = $DaysToExpire[-1]
            }

            if ($AppCredentialsDetails.Expired -contains $true) {
                $KeysExpired = 'Yes'
                if (-not ($AppCredentialsDetails.Expired -contains $false)) {
                    $KeysExpired = 'All Yes'
                }
            } elseif ($AppCredentialsDetails.Expired -contains $false) {
                $KeysExpired = 'No'
            }

            foreach ($CredentialName in $AppCredentialsDetails.KeyDisplayName) {
                if ($CredentialName -like '*@*') {
                    $DescriptionWithEmail = $true
                    break
                }
            }
            [Array] $DatesSorted = $AppCredentialsDetails.StartDateTime | Where-Object { $_ -ne $null } | Sort-Object
            if ($DatesSorted.Count -gt 0) {
                $KeysDateOldest = $DatesSorted[0]
                $KeysDateNewest = $DatesSorted[-1]
            }
        }
    } else {
        # KeysExpired remains 'Not available' if no Application object provided
        Write-Verbose "Convert-GraphEssentialsAppToReportObject: Skipping credential details for $displayName as no corresponding Application object was provided."
    }

    # --- Build Final Output Object ---
    $OutputObject = [ordered] @{
        # Core Info (from Service Principal)
        ApplicationName        = $displayName # From SP
        ApplicationId          = $spId # SP Object ID
        AppId                  = $appId # App/Client ID
        Source                 = $Source
        ServicePrincipalType   = $ServicePrincipal.ServicePrincipalType # Added SP Type
        # Owners (from Application)
        Owners                 = $CombinedOwners
        # Permissions
        PermissionType         = $PermissionType
        DelegatedPermissions   = $DelegatedScopes
        ApplicationPermissions = $ApplicationScopes
        # Sign-in Activity (from Reports)
        DelegatedLastSignIn    = if ($SignInInfo -and $SignInInfo.PSObject.Properties['delegatedClientSignInActivity']) { $SignInInfo.delegatedClientSignInActivity.lastSignInDateTime } else { $null }
        ApplicationLastSignIn  = if ($SignInInfo -and $SignInInfo.PSObject.Properties['applicationAuthenticationClientSignInActivity']) { $SignInInfo.applicationAuthenticationClientSignInActivity.lastSignInDateTime } else { $null }
        LastSignInMethod       = $LastSignInMethod
        # Credentials Summary (from Application)
        KeysCount              = $KeysCount
        KeysTypes              = $KeysTypes
        KeysExpired            = $KeysExpired
        DaysToExpireOldest     = $DaysToExpireOldest
        DaysToExpireNewest     = $DaysToExpireNewest
        KeysDateOldest         = $KeysDateOldest
        KeysDateNewest         = $KeysDateNewest
        KeysDescription        = $KeysDescription # From Application credentials
        DescriptionWithEmail   = $DescriptionWithEmail # From Application credentials
        # Other (from Application, if available)
        Notes                  = $ApplicationDetails?.Notes
        CreatedDate            = $ApplicationDetails?.CreatedDateTime # CreatedDate is on Application, not SP
    }
    if ($IncludeCredentials -and $AppCredentialsDetails) {
        $OutputObject['Keys'] = $AppCredentialsDetails
    }

    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Finished processing SP $displayName."
    [PSCustomObject] $OutputObject
}