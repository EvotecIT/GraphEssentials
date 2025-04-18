function Convert-GraphEssentialsAppToReportObject {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$App, # Raw Application object

        # Pre-fetched Data Structures
        [string]$TenantId,
        [hashtable]$SpDetailsByAppId,
        [hashtable]$AppPermissionsBySpId,
        [hashtable]$AllDelegatedPermissions,
        [hashtable]$SignInActivityReport,
        [hashtable]$LastSignInMethodReport,

        # Options
        [switch]$IncludeCredentials
    )

    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Processing App: $($App.DisplayName) ($($App.AppId))"

    # --- Look up pre-fetched SP data ---
    $spDetails = $SpDetailsByAppId[$App.AppId]
    $spId = $spDetails?.SPId
    $appOwnerOrganizationId = $spDetails?.OwnerOrgId
    $ApplicationScopes = if ($spId) { $AppPermissionsBySpId[$spId] } else { $null }

    # --- Determine Source (Improved Logic) ---
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

    # --- Get Credentials Details ---
    # Requires Get-MyAppCredentials function to be available
    # Pass the raw $App object which contains needed credential properties
    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Getting credentials details for $($App.DisplayName)"
    [Array] $AppCredentialsDetails = Get-MyAppCredentials -ApplicationList $App

    # --- Get Owners ---
    # Requires Get-GraphEssentialsAppOwners function to be available
    $Owners = Get-GraphEssentialsAppOwners -ApplicationObjectId $App.Id

    # --- Look up other pre-fetched data ---
    $SignInInfo = $SignInActivityReport[$App.AppId]
    $LastSignInMethod = $LastSignInMethodReport[$App.AppId]
    $DelegatedScopes = if ($spId) { $AllDelegatedPermissions[$spId] } else { $null }

    # Determine Combined Permission Type
    $PermissionType = "None"
    if ($DelegatedScopes -and $ApplicationScopes) {
        $PermissionType = "Delegated & Application"
    } elseif ($DelegatedScopes) {
        $PermissionType = "Delegated"
    } elseif ($ApplicationScopes) {
        $PermissionType = "Application"
    }

    # --- Credential Summary Calculation ---
    $DaysToExpireOldest = $null
    $DaysToExpireNewest = $null
    $KeysExpired = 'Not available'
    $KeysTypes = @()
    $KeysDescription = @()
    $DescriptionWithEmail = $false
    $KeysCount = 0
    $KeysDateOldest = $null
    $KeysDateNewest = $null

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

    # --- Build Final Output Object ---
    $AppInformation = [ordered] @{
        # Core App Info
        ApplicationName       = $App.DisplayName
        ApplicationId         = $App.Id
        AppId                 = $App.AppId
        CreatedDate           = $App.CreatedDateTime
        Source                = $Source
        # Owners
        Owners                = $Owners
        # Permissions
        PermissionType        = $PermissionType
        DelegatedPermissions  = $DelegatedScopes
        ApplicationPermissions= $ApplicationScopes
        # Sign-in Activity
        DelegatedLastSignIn   = if ($SignInInfo -and $SignInInfo.PSObject.Properties['delegatedClientSignInActivity']) { $SignInInfo.delegatedClientSignInActivity.lastSignInDateTime } else { $null }
        ApplicationLastSignIn = if ($SignInInfo -and $SignInInfo.PSObject.Properties['applicationAuthenticationClientSignInActivity']) { $SignInInfo.applicationAuthenticationClientSignInActivity.lastSignInDateTime } else { $null }
        LastSignInMethod      = $LastSignInMethod
        # Credentials Summary
        KeysCount             = $KeysCount
        KeysTypes             = $KeysTypes
        KeysExpired           = $KeysExpired
        DaysToExpireOldest    = $DaysToExpireOldest
        DaysToExpireNewest    = $DaysToExpireNewest
        KeysDateOldest        = $KeysDateOldest
        KeysDateNewest        = $KeysDateNewest
        KeysDescription       = $KeysDescription
        DescriptionWithEmail  = $DescriptionWithEmail
        # Other
        Notes                 = $App.Notes
    }
    if ($IncludeCredentials) {
        $AppInformation['Keys'] = $AppCredentialsDetails
    }

    Write-Verbose "Convert-GraphEssentialsAppToReportObject: Finished processing $($App.DisplayName)."
    return [PSCustomObject]$AppInformation
}