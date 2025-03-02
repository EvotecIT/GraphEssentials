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

    # Stage arrays for each category
    $CategorizedPolicies = [ordered] @{
        All                = [System.Collections.Generic.List[PSCustomObject]]::new()
        BlockLegacyAccess  = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforAdmins       = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforUsers        = [System.Collections.Generic.List[PSCustomObject]]::new()
        Risk               = [System.Collections.Generic.List[PSCustomObject]]::new()
        AppProtection      = [System.Collections.Generic.List[PSCustomObject]]::new()
        DeviceCompliance   = [System.Collections.Generic.List[PSCustomObject]]::new()
        UsingLocations     = [System.Collections.Generic.List[PSCustomObject]]::new()
        RestrictAdminPortal = [System.Collections.Generic.List[PSCustomObject]]::new()
        MFAforDeviceJoin   = [System.Collections.Generic.List[PSCustomObject]]::new()
        Uncategorized      = [System.Collections.Generic.List[PSCustomObject]]::new()
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

        # Convert to PSCustomObject for consistent output
        $PolicyObj = [PSCustomObject]@{
            DisplayName      = $CAPolicy.DisplayName
            Id               = $CAPolicy.Id
            State            = $CAPolicy.State
            CreatedDateTime  = $CAPolicy.CreatedDateTime
            ModifiedDateTime = $CAPolicy.ModifiedDateTime
            Type             = $null # Will be populated below
            IncludedUsers    = $CAPolicy.Conditions.Users.IncludeUsers
            ExcludedUsers    = $CAPolicy.Conditions.Users.ExcludeUsers
            IncludedGroups   = $CAPolicy.Conditions.Users.IncludeGroups
            ExcludedGroups   = $CAPolicy.Conditions.Users.ExcludeGroups
            IncludedRoles    = $CAPolicy.Conditions.Users.IncludeRoles
            ExcludedRoles    = $CAPolicy.Conditions.Users.ExcludeRoles
            ClientAppTypes   = $CAPolicy.Conditions.ClientAppTypes
            Applications     = $CAPolicy.Conditions.Applications.IncludeApplications
            UserActions      = $CAPolicy.Conditions.Applications.IncludeUserActions
            Platforms        = $CAPolicy.Conditions.Platforms.IncludePlatforms
            Locations        = $CAPolicy.Conditions.Locations.IncludeLocations
            SignInRiskLevels = $CAPolicy.Conditions.SignInRiskLevels
            UserRiskLevels   = $CAPolicy.Conditions.UserRiskLevels
            GrantControls    = $CAPolicy.GrantControls.BuiltInControls
            AuthStrength     = $CAPolicy.GrantControls.AuthenticationStrength.Id
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

        $AdminRoleAnalysis = foreach ($adminCAP in $CategorizedPolicies.MFAforAdmins) {
            $defaultCount = 0
            $nonDefaultCount = 0
            $includeCount = 0

            if ($adminCAP.IncludedRoles) {
                $includeCount = $adminCAP.IncludedRoles.Count

                foreach ($role in $adminCAP.IncludedRoles) {
                    if ($default14Roles -contains $role) {
                        $defaultCount++
                    } else {
                        $nonDefaultCount++
                    }
                }

                [PSCustomObject]@{
                    PolicyName      = $adminCAP.DisplayName
                    TotalRoles      = $includeCount
                    DefaultRoles    = "$defaultCount/14"
                    AdditionalRoles = $nonDefaultCount
                }
            }
        }

        # Add the admin role analysis to categorized policies
        $CategorizedPolicies['AdminRoleAnalysis'] = $AdminRoleAnalysis
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