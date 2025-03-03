function Get-MyCrossTenantAccess {
    <#
    .SYNOPSIS
    Retrieves Cross-tenant Access Policy configurations from Microsoft Graph.

    .DESCRIPTION
    Gets detailed information about Cross-tenant Access Policies configured in Azure AD/Entra ID,
    including both the default configuration and tenant-specific policies.

    .EXAMPLE
    Get-MyCrossTenantAccess
    Returns the default and tenant-specific cross-tenant access policies.

    .NOTES
    This function requires the Microsoft.Graph.Identity.SignIns module and appropriate permissions.
    Typically requires Policy.Read.All permission.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Get-MyCrossTenantAccess - Getting default policy configuration"
        $DefaultPolicy = Get-MgPolicyCrossTenantAccessPolicyDefault -ErrorAction Stop

        Write-Verbose -Message "Get-MyCrossTenantAccess - Getting tenant-specific policies"
        $TenantPolicies = Get-MgPolicyCrossTenantAccessPolicyPartner -All -ErrorAction Stop
        Write-Verbose -Message "Get-MyCrossTenantAccess - Retrieved policies for $($TenantPolicies.Count) partner tenants"

        $Results = [ordered]@{
            DefaultPolicy  = [PSCustomObject]@{
                InboundTrust     = @{
                    IsCompliantDeviceAccepted           = $DefaultPolicy.InboundTrust.IsCompliantDeviceAccepted
                    IsHybridAzureADJoinedDeviceAccepted = $DefaultPolicy.InboundTrust.IsHybridAzureADJoinedDeviceAccepted
                    IsMfaAccepted                       = $DefaultPolicy.InboundTrust.IsMfaAccepted
                }
                B2BDirectConnect = @{
                    ApplicationsEnabled = $DefaultPolicy.B2BDirectConnect.Applications.IsEnabled
                    UsersEnabled        = $DefaultPolicy.B2BDirectConnect.Users.IsEnabled
                }
                B2BCollaboration = @{
                    ApplicationsEnabled = $DefaultPolicy.B2BCollaboration.Applications.IsEnabled
                    UsersEnabled        = $DefaultPolicy.B2BCollaboration.Users.IsEnabled
                }
                InboundAllowed   = $DefaultPolicy.IsInboundAllowed
                OutboundAllowed  = $DefaultPolicy.IsOutboundAllowed
            }
            TenantPolicies = [System.Collections.Generic.List[object]]::new()
        }

        foreach ($Policy in $TenantPolicies) {
            $Results.TenantPolicies.Add([PSCustomObject]@{
                    TenantId         = $Policy.TenantId
                    DisplayName      = $Policy.DisplayName
                    InboundTrust     = @{
                        IsCompliantDeviceAccepted           = $Policy.InboundTrust.IsCompliantDeviceAccepted
                        IsHybridAzureADJoinedDeviceAccepted = $Policy.InboundTrust.IsHybridAzureADJoinedDeviceAccepted
                        IsMfaAccepted                       = $Policy.InboundTrust.IsMfaAccepted
                    }
                    B2BDirectConnect = @{
                        ApplicationsEnabled = $Policy.B2BDirectConnect.Applications.IsEnabled
                        UsersEnabled        = $Policy.B2BDirectConnect.Users.IsEnabled
                    }
                    B2BCollaboration = @{
                        ApplicationsEnabled = $Policy.B2BCollaboration.Applications.IsEnabled
                        UsersEnabled        = $Policy.B2BCollaboration.Users.IsEnabled
                    }
                    InboundAllowed   = $Policy.IsInboundAllowed
                    OutboundAllowed  = $Policy.IsOutboundAllowed
                    CreatedDateTime  = $Policy.CreatedDateTime
                    ModifiedDateTime = $Policy.ModifiedDateTime
                })
        }

        $Results
    } catch {
        Write-Warning -Message "Get-MyCrossTenantAccess - Failed to get cross-tenant access policies. Error: $($_.Exception.Message)"
        return
    }
}