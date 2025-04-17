function Get-MyUserAuthentication {
    <#
    .SYNOPSIS
    Retrieves detailed authentication method information for users from Microsoft Graph API using efficient batching.

    .DESCRIPTION
    Gets comprehensive authentication method information for users including MFA status,
    registered authentication methods (FIDO2, Phone, SMS, Email, etc.), and detailed
    configuration of each method. The function uses batched Graph API requests for significantly
    improved performance in large environments.

    Returns an array of objects with authentication details and status for each method type.

    .PARAMETER UserPrincipalName
    Optional. The UserPrincipalName of a specific user to retrieve authentication information for.
    If not specified, returns information for all users.

    .PARAMETER IncludeDeviceDetails
    When specified, includes detailed information about FIDO2 security keys, Windows Hello for Business,
    and other authentication device details via additional batched calls.

    .PARAMETER BatchSize
    Optional. Specifies the number of requests to include in each batch call. Defaults to 20 (the maximum allowed by Graph API).
    #>
    [CmdletBinding()]
    param(
        [string] $UserPrincipalName,
        [switch] $IncludeDeviceDetails,
        [int] $BatchSize = 20
    )

    $Today = Get-Date
    # Suppress Invoke-MgGraphRequest progress within the scope of this function
    $originalProgressPreference = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'

    try {
        # 1. Get Users
        Write-Verbose "Get-MyUserAuthentication - Getting users..."
        $Properties = @(
            'accountEnabled', 'displayName', 'id', 'userPrincipalName',
            'onPremisesSyncEnabled', 'createdDateTime', 'signInActivity'
        )
        if ($UserPrincipalName) {
            $Users = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -Property $Properties -ErrorAction Stop
        } else {
            Write-Verbose "Retrieving all users. This may take time for very large directories..."
            $Users = Get-MgUser -All -Property $Properties -ErrorAction Stop
        }
        Write-Verbose "Get-MyUserAuthentication - Retrieved $($Users.Count) users."
        if ($Users.Count -eq 0) { return @() }


        # 2. Get Authentication Method Summaries
        $allAuthMethods = Get-MyUserAuthSummaries -UserIds @($Users.Id) -BatchSize $BatchSize


        # 3. Prepare Detail Requests and Intermediate Data
        # Use splatting to conditionally pass the switch parameter
        $detailParams = @{
            Users          = $Users
            AllAuthMethods = $allAuthMethods
        }
        if ($IncludeDeviceDetails) {
            $detailParams['IncludeDeviceDetails'] = $true
        }
        $prepResult = New-MyAuthDetailRequests @detailParams
        $detailRequestsList = $prepResult.DetailRequestsList
        $intermediateResults = $prepResult.IntermediateResults


        # 4. Get Authentication Method Details (if any needed)
        $fetchedDetails = @{}
        if ($detailRequestsList.Count -gt 0) {
            $fetchedDetails = Get-MyUserAuthDetails -DetailRequestsList $detailRequestsList -BatchSize $BatchSize
        } else {
            Write-Verbose "Get-MyUserAuthentication - No method details needed to be fetched."
        }


        # 5. Assemble Final Results
        Write-Verbose "Get-MyUserAuthentication - Assembling final results..."
        $FinalResults = [System.Collections.Generic.List[object]]::new()

        foreach ($UserId in $intermediateResults.Keys) {
            $intermediate = $intermediateResults[$UserId]
            $User = $intermediate.User
            $AuthMethods = $intermediate.AuthMethods # Summaries
            $MethodTypes = $intermediate.MethodTypes

            # If summary fetch failed for this user, skip assembly
            if ($null -eq $AuthMethods) {
                Write-Warning "Get-MyUserAuthentication: Skipping result assembly for $($user.UserPrincipalName) as summary fetch failed."
                continue
            }

            # Initialize Details Hashtable for this user
            $Details = @{
                Fido2Keys              = [System.Collections.Generic.List[object]]::new()
                PhoneMethods           = [System.Collections.Generic.List[object]]::new()
                EmailMethods           = [System.Collections.Generic.List[object]]::new()
                MicrosoftAuthenticator = [System.Collections.Generic.List[object]]::new()
                TemporaryAccessPass    = [System.Collections.Generic.List[object]]::new()
                WindowsHelloMethods    = [System.Collections.Generic.List[object]]::new()
                SoftwareOath           = [System.Collections.Generic.List[object]]::new()
                PasswordMethods        = $MethodTypes -contains 'passwordAuthenticationMethod' # Populate PasswordMethods boolean
            }

            # Populate details from the fetched details dictionary or summary if details not requested/fetched
            $userRequests = $detailRequestsList | Where-Object { $_.UserId -eq $UserId }

            # Process methods that HAD detail requests attempted
            foreach ($requestItem in $userRequests) {
                $methodDetail = $null
                $detailFetchSuccess = $false
                if ($requestItem.Processed -and $fetchedDetails.ContainsKey($requestItem.RequestId)) {
                    $methodDetail = $fetchedDetails[$requestItem.RequestId]
                    if ($null -ne $methodDetail) {
                        $detailFetchSuccess = $true
                    }
                }

                # Populate the $Details hashtable based on the method type and fetch success
                switch ($requestItem.MethodODataType) {
                    "#microsoft.graph.fido2AuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.Fido2Keys.Add(@{
                                    Model           = $methodDetail.Model
                                    DisplayName     = $methodDetail.DisplayName
                                    CreatedDateTime = $methodDetail.CreatedDateTime
                                    AAGuid          = $methodDetail.AaGuid
                                })
                        } # If fetch failed, it remains empty - handled later if !$IncludeDeviceDetails
                    }
                    "#microsoft.graph.phoneAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.PhoneMethods.Add(@{
                                    PhoneNumber    = $methodDetail.PhoneNumber
                                    PhoneType      = $methodDetail.PhoneType
                                    SmsSignInState = $methodDetail.SmsSignInState
                                })
                        } # If fetch fails, PhoneMethods remains potentially incomplete
                    }
                    "#microsoft.graph.emailAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.EmailMethods.Add(@{
                                    EmailAddress = $methodDetail.EmailAddress
                                })
                        } # If fetch fails, EmailMethods remains potentially incomplete
                    }
                    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.MicrosoftAuthenticator.Add(@{
                                    DisplayName     = $methodDetail.DisplayName
                                    DeviceTag       = if ($methodDetail.device) { $methodDetail.device.deviceTag } else { $null }
                                    PhoneAppVersion = if ($methodDetail.device) { $methodDetail.device.clientVersion } else { $null }
                                })
                        } # If fetch fails, MicrosoftAuthenticator remains potentially incomplete
                    }
                    "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.TemporaryAccessPass.Add(@{
                                    LifetimeInMinutes     = $methodDetail.LifetimeInMinutes
                                    IsUsable              = $methodDetail.IsUsable
                                    MethodUsabilityReason = $methodDetail.MethodUsabilityReason
                                })
                        } # If fetch fails, TemporaryAccessPass remains potentially incomplete
                    }
                    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.WindowsHelloMethods.Add(@{
                                    DisplayName     = $methodDetail.DisplayName
                                    CreatedDateTime = $methodDetail.CreatedDateTime
                                    KeyStrength     = $methodDetail.KeyStrength
                                    Device          = if ($methodDetail.Device) { $methodDetail.Device.DisplayName } else { $null }
                                })
                        } # If fetch failed, it remains empty - handled later if !$IncludeDeviceDetails
                    }
                    "#microsoft.graph.softwareOathAuthenticationMethod" {
                        if ($detailFetchSuccess) {
                            $Details.SoftwareOath.Add(@{
                                    DisplayName = $methodDetail.DisplayName
                                })
                        } # If fetch fails, SoftwareOath remains potentially incomplete
                    }
                } # End Switch
            } # End Foreach ($requestItem)

            # If device details were NOT requested for FIDO/WHFB, populate from summary
            if (-not $IncludeDeviceDetails) {
                $fidoSummaries = $AuthMethods | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.fido2AuthenticationMethod' }
                $fidoSummaries | ForEach-Object { $Details.Fido2Keys.Add($_.displayName) }

                $whfbSummaries = $AuthMethods | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' }
                $whfbSummaries | ForEach-Object { $Details.WindowsHelloMethods.Add($_.displayName) }
            }


            # Create the final result object using the private helper
            $resultObject = New-MyUserAuthenticationObject -User $User -AuthMethods $AuthMethods -MethodTypes $MethodTypes -Details $Details -Today $Today
            $FinalResults.Add($resultObject)

        } # End foreach ($UserId in $intermediateResults.Keys)

        Write-Verbose "Get-MyUserAuthentication: Finished assembling results. Returning $($FinalResults.Count) objects."
        return $FinalResults

    } catch {
        Write-Error -Message "Get-MyUserAuthentication - An error occurred: $($_.Exception.Message) ErrorRecord: $($_.ToString()) StackTrace: $($_.ScriptStackTrace)"
    } finally {
        $global:ProgressPreference = $originalProgressPreference
    }
}