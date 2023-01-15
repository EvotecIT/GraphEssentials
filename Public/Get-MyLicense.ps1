function Get-MyLicense {
    [CmdletBinding()]
    param(
        [switch] $Internal
    )
    $Skus = Get-MgSubscribedSku -All
    if ($Internal) {
        $Licenses = [ordered] @{}
        foreach ($SKU in $Skus) {
            $Licenses[$Sku.SkuId] = Convert-Office365License -License $SKU.SkuPartNumber
            foreach ($Plan in $Sku.ServicePlans) {
                $Licenses[$Plan.ServicePlanId] = Convert-Office365License -License $Plan.ServicePlanName
            }
        }
        $Licenses
    } else {
        foreach ($SKU in $Skus) {
            [PSCustomObject] @{
                Name                  = Convert-Office365License -License $SKU.SkuPartNumber
                SkuId                 = $SKU.SkuId                # : 26124093 - 3d78-432b-b5dc-48bf992543d5
                SkuPartNumber         = $SKU.SkuPartNumber        # : IDENTITY_THREAT_PROTECTION
                AppliesTo             = $SKU.AppliesTo            # : User
                CapabilityStatus      = $SKU.CapabilityStatus     # : Enabled
                LicenseCountUsed      = $SKU.ConsumedUnits        # : 1
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