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

    # --- Get Owners ---
    # Owners are associated with the Application object, not the SP directly in this context for reporting.
    # We need the Application Object ID if it exists.
    $Owners = @()
    $ApplicationObjectId = $ApplicationDetails?.Id
    if ($ApplicationObjectId) {
        # Requires Get-GraphEssentialsAppOwners function
        $Owners = Get-GraphEssentialsAppOwners -ApplicationObjectId $ApplicationObjectId
    } else {
        Write-Verbose "Convert-GraphEssentialsAppToReportObject: Cannot fetch owners for SP $displayName as corresponding Application details are missing."
        # SPs like Microsoft ones might have owners via different means not fetched here (e.g. servicePrincipal:addOwner)
        # For simplicity, we report no owners if no Application object was found/provided.
    }

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
        ApplicationName       = $displayName # From SP
        ApplicationId         = $spId # SP Object ID
        AppId                 = $appId # App/Client ID
        Source                = $Source
        # Owners (from Application)
        Owners                = $Owners
        # Permissions
        PermissionType        = $PermissionType
        DelegatedPermissions  = $DelegatedScopes
        ApplicationPermissions= $ApplicationScopes
        # Sign-in Activity (from Reports)
        DelegatedLastSignIn   = if ($SignInInfo -and $SignInInfo.PSObject.Properties['delegatedClientSignInActivity']) { $SignInInfo.delegatedClientSignInActivity.lastSignInDateTime } else { $null }
        ApplicationLastSignIn = if ($SignInInfo -and $SignInInfo.PSObject.Properties['applicationAuthenticationClientSignInActivity']) { $SignInInfo.applicationAuthenticationClientSignInActivity.lastSignInDateTime } else { $null }
        LastSignInMethod      = $LastSignInMethod
        # Credentials Summary (from Application)
        KeysCount             = $KeysCount
        KeysTypes             = $KeysTypes
        KeysExpired           = $KeysExpired
        DaysToExpireOldest    = $DaysToExpireOldest
        DaysToExpireNewest    = $DaysToExpireNewest
        KeysDateOldest        = $KeysDateOldest
        KeysDateNewest        = $KeysDateNewest
        KeysDescription       = $KeysDescription # From Application credentials
        DescriptionWithEmail  = $DescriptionWithEmail # From Application credentials
        # Other (from Application, if available)
        Notes                 = $ApplicationDetails?.Notes
        CreatedDate           = $ApplicationDetails?.CreatedDateTime # CreatedDate is on Application, not SP
    }
    if ($IncludeCredentials -and $AppCredentialsDetails) {
        $OutputObject['Keys'] = $AppCredentialsDetails
    }

    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Finished processing SP $displayName."
    return [PSCustomObject]$OutputObject
}