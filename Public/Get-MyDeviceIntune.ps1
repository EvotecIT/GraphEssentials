function Get-MyDeviceIntune {
    <#
    .SYNOPSIS
    Retrieves Intune device information from Microsoft Graph API.

    .DESCRIPTION
    Gets detailed information about devices managed by Intune from the Microsoft Graph API.
    Provides data about device compliance, management state, and other device-specific properties.

    .PARAMETER Type
    Filters devices by type. Valid values are 'Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', and 'Not available'.

    .PARAMETER Synchronized
    When specified, returns only synchronized devices (devices with OnPremisesSyncEnabled set to true).

    .PARAMETER Force
    Forces the function to retrieve Azure devices even if they are already cached by using Get-MyDevice cmdlet.

    .EXAMPLE
    Get-MyDeviceIntune
    Returns all Intune managed devices with their properties.

    .NOTES
    This function requires the Microsoft.Graph.Authentication module and appropriate permissions to access Intune data.

    When you use Type parameter or Synchronized parameter, the function will retrieve Azure devices to match them with Intune devices.
    This operation may take some time, especially if you have a large number of devices.
    That's why the function tries to use cached Azure devices if they were already retrieved by Get-MyDevice cmdlet.
    If you want to force the function to retrieve Azure devices again, use the Force switch.
    The cache is valid for 30 minutes by default.
    #>
    [cmdletBinding()]
    param(
        [ValidateSet('Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', 'Not available')][string[]] $Type,
        [switch] $Synchronized,
        [int] $CacheMinutes = 30,
        [switch] $Force
    )
    $CachedAzure = [ordered] @{}
    $Today = Get-Date
    try {
        $DevicesIntune = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
    } catch {
        Write-Warning -Message "Get-MyDeviceIntune - Failed to get intune devices. Error: $($_.Exception.Message)"
        return
    }

    if ($Type -or $Synchronized) {
        # We only need to get Azure devices if we are filtering by type
        try {
            if (-not $Script:Devices -or $Force -or $Script:DevicesDate -lt (Get-Date).AddMinutes(-$CacheMinutes)) {
                $DevicesAzure = Get-MgDevice -All -ErrorAction Stop
            } else {
                $DevicesAzure = $Script:Devices
            }
        } catch {
            Write-Warning -Message "Get-MyDeviceIntune - Failed to get Azure devices. Error: $($_.Exception.Message)"
            return
        }
        foreach ($DeviceA in $DevicesAzure) {
            $CachedAzure[$DeviceA.DeviceId] = $DeviceA
        }
    }

    $TrustTypes = @{
        'ServerAD'  = 'Hybrid AzureAD'
        'AzureAD'   = 'AzureAD joined'
        'Workplace' = 'AzureAD registered'
    }

    foreach ($DeviceI in $DevicesIntune) {
        if ($DeviceI.LastSyncDateTime) {
            $LastSynchronizedDays = $( - $($DeviceI.LastSyncDateTime - $Today).Days)
        } else {
            $LastSynchronizedDays = $null
        }

        # Get the Azure device information for the current Intune device
        if ($CachedAzure[$DeviceI.AzureAdDeviceId]) {
            $DeviceA = $CachedAzure[$DeviceI.AzureAdDeviceId]
            if ($DeviceA.TrustType) {
                $TrustType = $TrustTypes[$DeviceA.TrustType]
            } else {
                $TrustType = 'Not available'
            }
            $SynchronizedDevice = $DeviceA.OnPremisesSyncEnabled
        } else {
            $DeviceA = $null
            $TrustType = 'Not available'
            $SynchronizedDevice = $null
        }

        if ($Type) {
            # Only return devices of the specified type
            if ($Type -notcontains $TrustType) {
                continue
            }
        }
        if ($Synchronized) {
            # Only return synchronized devices
            if (-not $SynchronizedDevice) {
                continue
            }
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
        if ($Type -or $Synchronized) {
            $DeviceInformation['TrustType'] = $TrustType
            $DeviceInformation['IsSynchronized'] = $SynchronizedDevice
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
