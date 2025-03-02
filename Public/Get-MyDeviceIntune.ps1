function Get-MyDeviceIntune {
    <#
    .SYNOPSIS
    Retrieves Intune device information from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed information about devices managed by Intune from the Microsoft Graph API.
    Provides data about device compliance, management state, and other device-specific properties.

    .EXAMPLE
    Get-MyDeviceIntune
    Returns all Intune managed devices with their properties.

    .NOTES
    This function requires the Microsoft.Graph.Authentication module and appropriate permissions to access Intune data.
    #>
    [cmdletBinding()]
    param(

    )
    $Today = Get-Date
    try {
        $DevicesIntune = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyDeviceIntune - Failed to get intune devices. Error: $($_.Exception.Message)"
        return
    }
    foreach ($DeviceI in $DevicesIntune) {
        if ($DeviceI.LastSyncDateTime) {
            $LastSynchronizedDays = $( - $($DeviceI.LastSyncDateTime - $Today).Days)
        } else {
            $LastSynchronizedDays = $null
        }

        $DeviceInformation = [ordered] @{
            Name                                    = $DeviceI.DeviceName                                # : EVOMONSTER
            Id                                      = $DeviceI.Id                                        # : 83fe122f-c51c-49dc-a0f3-cc11d9e7d045
            ComplianceState                         = $DeviceI.ComplianceState                           # : compliant
            OperatingSystem                         = $DeviceI.OperatingSystem                           # : Windows
            OperatingSystemVersion                  = $DeviceI.OSVersion                                 # : 10.0.22621.1555
            FirstSeen                               = $DeviceI.EnrolledDateTime                          # : 2023-01-28 10:34:18
            LastSeen                                = $DeviceI.LastSyncDateTime                          # : 2023-04-14 04:52:42
            LastSeenDays                            = $LastSynchronizedDays
            UserDisplayName                         = $DeviceI.UserDisplayName                           # : Przemysław Kłys
            UserId                                  = $DeviceI.UserId                                    # : e6a8f1cf-0874-4323-a12f-2bf51bb6dfdd
            UserPrincipalName                       = $DeviceI.UserPrincipalName                         # : przemyslaw.klys@evotec.pl
            EmailAddress                            = $DeviceI.EmailAddress                              # : przemyslaw.klys@evotec.pl

            ManagedDeviceName                       = $DeviceI.ManagedDeviceName                         # : przemyslaw.klys_Windows_1/28/2023_10:34 AM
            ManagedDeviceOwnerType                  = $DeviceI.ManagedDeviceOwnerType                    # : company
            ManagementAgent                         = $DeviceI.ManagementAgent                           # : mdm
            ManagementCertificateExpirationDate     = $DeviceI.ManagementCertificateExpirationDate       # : 2024-01-27 17:58:15

            ActivationLockBypassCode                = $DeviceI.ActivationLockBypassCode                  # :
            AndroidSecurityPatchLevel               = $DeviceI.AndroidSecurityPatchLevel                 # :
            AzureAdDeviceId                         = $DeviceI.AzureAdDeviceId                           # : aee87706-674b-40be-8120-74e7c469329b
            AzureAdRegistered                       = $DeviceI.AzureAdRegistered                         # : True
            ComplianceGracePeriodExpirationDateTime = $DeviceI.ComplianceGracePeriodExpirationDateTime   # : 9999-12-31 23:59:59

            #ConfigurationManagerClientEnabledFeatures = $DeviceI.ConfigurationManagerClientEnabledFeatures # : Microsoft.Graph.PowerShell.Models.MicrosoftGraphConfigurationManagerClientEnabledFeatures
            DeviceActionResults                     = $DeviceI.DeviceActionResults                       # : {}
            #DeviceCategory                            = $DeviceI.DeviceCategory                            # : Microsoft.Graph.PowerShell.Models.MicrosoftGraphDeviceCategory
            DeviceCategoryName                      = $DeviceI.DeviceCategoryDisplayName                 # : Unknown
            DeviceCompliancePolicyStates            = $DeviceI.DeviceCompliancePolicyStates              # :
            DeviceConfigurationStates               = $DeviceI.DeviceConfigurationStates                 # :
            DeviceEnrollmentType                    = $DeviceI.DeviceEnrollmentType                      # : windowsCoManagement
            #DeviceHealthAttestationState              = $DeviceI.DeviceHealthAttestationState              # : Microsoft.Graph.PowerShell.Models.MicrosoftGraphDeviceHealthAttestationState
            DeviceRegistrationState                 = $DeviceI.DeviceRegistrationState                   # : registered
            EasActivated                            = $DeviceI.EasActivated                              # : True
            EasActivationDateTime                   = $DeviceI.EasActivationDateTime                     # : 0001-01-01 00:00:00
            EasDeviceId                             = $DeviceI.EasDeviceId                               # : E88398D87BD859566D129F86E2FD722C
            EthernetMacAddress                      = $DeviceI.EthernetMacAddress                        # :
            ExchangeAccessState                     = $DeviceI.ExchangeAccessState                       # : none
            ExchangeAccessStateReason               = $DeviceI.ExchangeAccessStateReason                 # : none
            ExchangeLastSuccessfulSyncDateTime      = $DeviceI.ExchangeLastSuccessfulSyncDateTime        # : 0001-01-01 00:00:00
            FreeStorageSpaceInBytes                 = $DeviceI.FreeStorageSpaceInBytes                   # : 1392111517696
            Iccid                                   = $DeviceI.Iccid                                     # :
            Imei                                    = $DeviceI.Imei                                      # :
            IsEncrypted                             = $DeviceI.IsEncrypted                               # : True
            IsSupervised                            = $DeviceI.IsSupervised                              # : False
            IsJailBroken                            = $DeviceI.JailBroken                                # : Unknown
            Manufacturer                            = $DeviceI.Manufacturer                              # : ASUS
            Meid                                    = $DeviceI.Meid                                      # :
            Model                                   = $DeviceI.Model                                     # : System Product Name
            Notes                                   = $DeviceI.Notes                                     # :
            PartnerReportedThreatState              = $DeviceI.PartnerReportedThreatState                # : unknown
            PhoneNumber                             = $DeviceI.PhoneNumber                               # :
            PhysicalMemoryInBytes                   = $DeviceI.PhysicalMemoryInBytes                     # : 0
            SerialNumber                            = $DeviceI.SerialNumber                              # : SystemSerialNumber
            SubscriberCarrier                       = $DeviceI.SubscriberCarrier                         # :
            TotalStorageSpaceInBytes                = $DeviceI.TotalStorageSpaceInBytes                  # : 1999609266176
            Udid                                    = $DeviceI.Udid                                      # :
            Users                                   = $DeviceI.Users                                     # :
            WiFiMacAddress                          = $DeviceI.WiFiMacAddress                            # : 8C1D96F0937B
            RemoteAssistanceSessionErrorDetails     = $DeviceI.RemoteAssistanceSessionErrorDetails       # :
            RemoteAssistanceSessionUrl              = $DeviceI.RemoteAssistanceSessionUrl                # :
            RequireUserEnrollmentApproval           = $DeviceI.RequireUserEnrollmentApproval             # :
            #AdditionalProperties                      = $DeviceI.AdditionalProperties                      # : {}
        }
        foreach ($D in $DeviceI.ConfigurationManagerClientEnabledFeatures.PSObject.Properties) {
            if ($D.Name -notin 'AdditionalProperties') {
                $DeviceInformation.Add("ConfigurationManagerClientEnabledFeatures$($D.Name)", $D.Value)
            }
        }
        foreach ($D in $DeviceI.DeviceCategory.PSObject.Properties) {
            if ($D.Name -notin 'AdditionalProperties') {
                $DeviceInformation.Add("DeviceCategory$($D.Name)", $D.Value)
            }
        }
        foreach ($D in $DeviceI.DeviceHealthAttestationState.PSObject.Properties) {
            if ($D.Name -notin 'AdditionalProperties') {
                $DeviceInformation.Add("DeviceHealthAttestationState$($D.Name)", $D.Value)
            }
        }
        [PSCustomObject] $DeviceInformation
    }
}
