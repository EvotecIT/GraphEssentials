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

    # Define ScriptBlocks for Invoke-MyGraphBatchResponse actions
    $ScriptBlockSuccessSummary = {
        param($responseBody, $currentUserId)
        $methods = $responseBody.value # Assuming the structure is { value: [...] }
        $allAuthMethods[$currentUserId] = if ($methods) { $methods } else { @() }
    }
    $ScriptBlockFailureSummary = {
        param($response, $currentUserId)
        $allAuthMethods[$currentUserId] = $null # Mark as failed/null
    }
    $ScriptBlockSuccessDetail = {
        param($responseBody, $originalRequestItem)
        $fetchedDetails[$originalRequestItem.RequestId] = $responseBody # Store the raw body
        $originalRequestItem.Processed = $true # Mark as processed
    }
    $ScriptBlockFailureDetail = {
         param($response, $originalRequestItem)
         # Leave Processed as $false or store an error object? For now, just don't store details.
         Write-Warning "FailureAction: Failed to get details for RequestId $($originalRequestItem.RequestId) (User: $($originalRequestItem.UserId), Method: $($originalRequestItem.MethodId))"
         $fetchedDetails[$originalRequestItem.RequestId] = $null # Indicate failure explicitly
    }

    try {
        Write-Verbose "Get-MyUserAuthentication - Getting users..."

        # 1. Get Users
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
        if ($Users.Count -eq 0) {
            Write-Verbose "No users found matching the criteria."
            return @()
        }

        # 2. Batch-fetch Authentication Method summaries (including IDs)
        $allAuthMethods = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new() # Store summary methods per UserId
        $userIds = @($Users.Id) # Ensure $userIds is always an array
        Write-Verbose "Starting batch fetch for authentication method summaries for $($userIds.Count) users..."

        for ($i = 0; $i -lt $userIds.Count; $i += $BatchSize) {
            $batchUserIds = $userIds[$i..([math]::Min($i + $BatchSize - 1, $userIds.Count - 1))]
            $batchRequests = @()
            $idMap = @{} # Map request ID to UserId for this batch
            $userCounterInBatch = 0

            foreach ($userId in $batchUserIds) {
                if (-not $userId) { continue } # Should not happen with @() wrapping but safe check
                $userCounterInBatch++
                $requestId = "summary_$($i)_$($userCounterInBatch)" # Unique ID for summary requests
                $batchRequests += @{
                    id     = $requestId
                    method = "GET"
                    url    = "/users/$userId/authentication/methods"
                }
                $idMap[$requestId] = $userId
            }

            if ($batchRequests.Count -eq 0) { continue }

            # Invoke the batch request using the private helper
            $batchResponses = Invoke-MyGraphBatchRequest -BatchRequests $batchRequests -DataType "Auth Methods Summary (Batch $i)"

            # Process responses for this batch using the private helper
            if ($batchResponses) {
                Invoke-MyGraphBatchResponse -BatchResponses $batchResponses -IdMap $idMap -DataType "Auth Methods Summary (Batch $i)" `
                    -SuccessAction $ScriptBlockSuccessSummary -FailureAction $ScriptBlockFailureSummary
            } else {
                 # Mark all users in this failed batch as failed
                foreach ($reqId in $idMap.Keys) {
                    Invoke-Command -ScriptBlock $ScriptBlockFailureSummary -ArgumentList $null, $idMap[$reqId]
                }
            }
        }
        Write-Verbose "Finished fetching authentication method summaries."


        # 3. Process summaries and prepare detail requests
        $detailRequestsList = [System.Collections.Generic.List[object]]::new() # List of request items for details
        $intermediateResults = @{} # Store intermediate data keyed by UserId
        Write-Verbose "Processing summaries and preparing detail requests..."

        foreach ($User in $Users) {
            $UserId = $User.Id
            if (-not $allAuthMethods.ContainsKey($UserId)) {
                 Write-Warning "Authentication methods summary data not found for $($User.UserPrincipalName) (User ID: $UserId). Skipping."
                 continue
            }
            $AuthMethods = $allAuthMethods[$UserId]
            if ($null -eq $AuthMethods) {
                 Write-Warning "Authentication methods summary fetch failed for $($User.UserPrincipalName) (User ID: $UserId). Skipping."
                 continue
            }

            $MethodTypes = $AuthMethods | ForEach-Object { $_.'@odata.type' -replace '#microsoft.graph.', '' }

            # Prepare requests for details needed for the second batch call
            foreach ($Method in $AuthMethods) {
                $methodType = $Method.'@odata.type'
                $methodId = $Method.id
                if (-not $methodId) { continue } # Skip if method has no ID
                $requestId = "detail_$(($detailRequestsList.Count).ToString('X8'))" # Unique ID for detail requests
                $requestItem = @{ UserId = $UserId; MethodId = $methodId; RequestId = $requestId; MethodODataType = $methodType; BatchUrl = $null; Processed = $false }

                # Determine if a detail request is needed and construct the URL
                $needsDetail = $false
                $detailUrl = $null
                switch ($methodType) {
                    "#microsoft.graph.fido2AuthenticationMethod" {
                        if ($IncludeDeviceDetails) { $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/fido2Methods/$($methodId)" }
                    }
                    "#microsoft.graph.phoneAuthenticationMethod" {
                         $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/phoneMethods/$($methodId)"
                    }
                    "#microsoft.graph.emailAuthenticationMethod" {
                         $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/emailMethods/$($methodId)"
                    }
                    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                         $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/microsoftAuthenticatorMethods/$($methodId)?`$expand=device" # Always expand device for this one
                    }
                    "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                         $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/temporaryAccessPassMethods/$($methodId)"
                    }
                    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                        if ($IncludeDeviceDetails) { $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/windowsHelloForBusinessMethods/$($methodId)?`$expand=device" }
                    }
                    "#microsoft.graph.softwareOathAuthenticationMethod" {
                         $needsDetail = $true; $detailUrl = "/users/$($UserId)/authentication/softwareOathMethods/$($methodId)"
                    }
                }
                # Add to list if detail needed
                if ($needsDetail -and $detailUrl) {
                    $requestItem.BatchUrl = $detailUrl
                    $detailRequestsList.Add($requestItem)
                }
            } # End foreach ($Method in $AuthMethods)

             # Store intermediate data needed for final object construction
            $intermediateResults[$UserId] = @{
                User        = $User
                AuthMethods = $AuthMethods # Store the summary methods
                MethodTypes = $MethodTypes
            }
        } # End foreach ($User in $Users) - Intermediate Processing
        Write-Verbose "Finished processing summaries. Need to fetch $($detailRequestsList.Count) method details."

        # 4. Batch-fetch detailed method information
        $fetchedDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new() # Store fetched details keyed by RequestId
        Write-Verbose "Starting batch fetch for method details..."

        for ($i = 0; $i -lt $detailRequestsList.Count; $i += $BatchSize) {
            $batchDetailItems = $detailRequestsList.GetRange($i, [math]::Min($BatchSize, $detailRequestsList.Count - $i))
            $batchDetailRequests = @()
            $detailIdMap = @{} # Map request ID to the original request item

            foreach ($item in $batchDetailItems) {
                if (-not $item -or -not $item.BatchUrl) { continue }
                $batchDetailRequests += @{
                    id     = $item.RequestId
                    method = "GET"
                    url    = $item.BatchUrl
                }
                $detailIdMap[$item.RequestId] = $item
            }

            if ($batchDetailRequests.Count -eq 0) { continue }

            # Invoke the batch request using the private helper
            $batchDetailResponses = Invoke-MyGraphBatchRequest -BatchRequests $batchDetailRequests -DataType "Method Details (Batch $i)"

            # Process detail responses for this batch using the private helper
             if ($batchDetailResponses) {
                 Invoke-MyGraphBatchResponse -BatchResponses $batchDetailResponses -IdMap $detailIdMap -DataType "Method Details (Batch $i)" `
                    -SuccessAction $ScriptBlockSuccessDetail -FailureAction $ScriptBlockFailureDetail
             } else {
                  # Mark all items in this failed detail batch as failed
                 foreach ($reqId in $detailIdMap.Keys) {
                     Invoke-Command -ScriptBlock $ScriptBlockFailureDetail -ArgumentList $null, $detailIdMap[$reqId]
                 }
             }
        }
        Write-Verbose "Finished fetching method details."


        # 5. Assemble final results
        Write-Verbose "Assembling final results..."
        $FinalResults = [System.Collections.Generic.List[object]]::new()

        foreach ($UserId in $intermediateResults.Keys) {
             $intermediate = $intermediateResults[$UserId]
             $User = $intermediate.User
             $AuthMethods = $intermediate.AuthMethods
             $MethodTypes = $intermediate.MethodTypes

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

             # Populate details from the fetched details dictionary
            $userRequests = $detailRequestsList | Where-Object { $_.UserId -eq $UserId }
            foreach ($requestItem in $userRequests) {
                # Check if detail was successfully fetched and processed
                if ($requestItem.Processed -and $fetchedDetails.ContainsKey($requestItem.RequestId)) {
                    $methodDetail = $fetchedDetails[$requestItem.RequestId]
                    if ($null -eq $methodDetail) { continue } # Skip if fetch failed explicitly for this detail

                    # Populate the $Details hashtable based on the method type
                    switch ($requestItem.MethodODataType) {
                        "#microsoft.graph.fido2AuthenticationMethod" {
                             # Already checked IncludeDeviceDetails when adding to list
                             $Details.Fido2Keys.Add(@{
                                Model           = $methodDetail.Model
                                DisplayName     = $methodDetail.DisplayName
                                CreatedDateTime = $methodDetail.CreatedDateTime
                                AAGuid          = $methodDetail.AaGuid
                            })
                        }
                        "#microsoft.graph.phoneAuthenticationMethod" {
                            $Details.PhoneMethods.Add(@{
                                PhoneNumber    = $methodDetail.PhoneNumber
                                PhoneType      = $methodDetail.PhoneType
                                SmsSignInState = $methodDetail.SmsSignInState
                            })
                        }
                        "#microsoft.graph.emailAuthenticationMethod" {
                             $Details.EmailMethods.Add(@{
                                EmailAddress = $methodDetail.EmailAddress
                            })
                        }
                         "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                             $Details.MicrosoftAuthenticator.Add(@{
                                DisplayName     = $methodDetail.DisplayName
                                DeviceTag       = if ($methodDetail.device) { $methodDetail.device.deviceTag } else { $null } # PS 5.1 Compat
                                PhoneAppVersion = if ($methodDetail.device) { $methodDetail.device.clientVersion } else { $null } # PS 5.1 Compat
                            })
                        }
                        "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                            $Details.TemporaryAccessPass.Add(@{
                                LifetimeInMinutes     = $methodDetail.LifetimeInMinutes
                                IsUsable              = $methodDetail.IsUsable
                                MethodUsabilityReason = $methodDetail.MethodUsabilityReason
                            })
                        }
                        "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                            # Already checked IncludeDeviceDetails when adding to list
                            $Details.WindowsHelloMethods.Add(@{
                                DisplayName     = $methodDetail.DisplayName
                                CreatedDateTime = $methodDetail.CreatedDateTime
                                KeyStrength     = $methodDetail.KeyStrength
                                Device          = if ($methodDetail.Device) { $methodDetail.Device.DisplayName } else { $null } # PS 5.1 Compat
                            })
                        }
                        "#microsoft.graph.softwareOathAuthenticationMethod" {
                            $Details.SoftwareOath.Add(@{
                                DisplayName = $methodDetail.DisplayName # Assuming property exists
                            })
                        }
                    }
                } elseif ($requestItem.MethodODataType -eq "#microsoft.graph.fido2AuthenticationMethod" -and (-not $IncludeDeviceDetails)) {
                    # If device details NOT included, find the original summary object to get display name
                    $summaryMethod = $AuthMethods | Where-Object { $_.id -eq $requestItem.MethodId -and $_.'@odata.type' -eq $requestItem.MethodODataType } | Select-Object -First 1
                    if ($summaryMethod) {
                        $Details.Fido2Keys.Add($summaryMethod.displayName)
                    }
                } elseif ($requestItem.MethodODataType -eq "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" -and (-not $IncludeDeviceDetails)) {
                     # If device details NOT included, find the original summary object to get display name
                    $summaryMethod = $AuthMethods | Where-Object { $_.id -eq $requestItem.MethodId -and $_.'@odata.type' -eq $requestItem.MethodODataType } | Select-Object -First 1
                    if ($summaryMethod) {
                         $Details.WindowsHelloMethods.Add($summaryMethod.displayName)
                    }
                }
            }

            # Create the final result object using the private helper
            $resultObject = New-MyUserAuthenticationObject -User $User -AuthMethods $AuthMethods -MethodTypes $MethodTypes -Details $Details -Today $Today
            $FinalResults.Add($resultObject)

        } # End foreach ($UserId in $intermediateResults.Keys)

        # Return results
        Write-Verbose "Finished assembling results. Returning $($FinalResults.Count) objects."
        return $FinalResults

    } catch {
        Write-Error -Message "Get-MyUserAuthentication - An error occurred: $($_.Exception.Message)"
        # Consider more specific error handling or returning partial results if appropriate
    } finally {
        # Restore original progress preference
        $global:ProgressPreference = $originalProgressPreference
    }
}
