function Get-MyLicense {
    [CmdletBinding()]
    param(
        [Parameter(DontShow)][switch] $Internal
    )
    $Skus = Get-MgSubscribedSku -All
    if ($Internal) {
        # This is used by Get-MyUser to get the list of licenses and service plans and faster search
        $Output = [ordered] @{
            Licenses     = [ordered] @{}
            ServicePlans = [ordered] @{}
        }
        foreach ($SKU in $Skus) {
            $Output['Licenses'][$Sku.SkuId] = Convert-Office365License -License $SKU.SkuPartNumber
            foreach ($Plan in $Sku.ServicePlans) {
                $Output['ServicePlans'][$Plan.ServicePlanId] = Convert-Office365License -License $Plan.ServicePlanName
            }
        }
        $Output
    } else {
        foreach ($SKU in $Skus) {
            if ($SKU.PrepaidUnits.Enabled -gt 0) {
                $LicensesUsedPercent = [math]::Round(($SKU.ConsumedUnits / $SKU.PrepaidUnits.Enabled) * 100, 0)
            } else {
                $LicensesUsedPercent = 100
            }
            [PSCustomObject] @{
                Name                  = Convert-Office365License -License $SKU.SkuPartNumber
                SkuId                 = $SKU.SkuId                # : 26124093 - 3d78-432b-b5dc-48bf992543d5
                SkuPartNumber         = $SKU.SkuPartNumber        # : IDENTITY_THREAT_PROTECTION
                AppliesTo             = $SKU.AppliesTo            # : User
                CapabilityStatus      = $SKU.CapabilityStatus     # : Enabled
                LicensesUsedPercent   = $LicensesUsedPercent
                LicensesUsedCount     = $SKU.ConsumedUnits        # : 1
                #Id                   = $SKU.Id                   # : ceb371f6 - 8745 - 4876-a040 - 69f2d10a9d1a_26124093-3d78-432b-b5dc-48bf992543d5
                LicenseCountEnabled   = $SKU.PrepaidUnits.Enabled
                LicenseCountWarning   = $SKU.PrepaidUnits.Warning
                LicenseCountSuspended = $SKU.PrepaidUnits.Suspended
                #ServicePlans          = $SKU.ServicePlans         # : { MTP, SAFEDOCS, WINDEFATP, THREAT_INTELLIGENCE… }
                ServicePlansCount     = $SKU.ServicePlans.Count   # : 5
                ServicePlans          = $SKU.ServicePlans | ForEach-Object {
                    Convert-Office365License -License $_.ServicePlanName
                }
                #AdditionalProperties  = $SKU.AdditionalProperties # : {}
            }
        }
    }
}