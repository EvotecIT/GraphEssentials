function Register-FIDO2KeyInEntraID {
    <#
    .SYNOPSIS
    Registers a FIDO2 key in Entra ID for a user.

    .DESCRIPTION
    This function registers a FIDO2 key in Microsoft Entra ID by making a Graph API call.
    It processes the attestation data from a FIDO2 key and registers it for the specified user.

    .PARAMETER UPN
    The User Principal Name of the user for whom to register the FIDO2 key.

    .PARAMETER DisplayName
    The friendly display name for the FIDO2 key that will appear in the user's authentication methods.

    .PARAMETER FIDO2
    The FIDO2 key registration data object containing attestation information.
    #>
    param (
        [string]$UPN,
        [string]$DisplayName,
        [PSCustomObject]$FIDO2
    )
    try {
        $URI = "https://graph.microsoft.com/beta/users/$UPN/authentication/fido2Methods"
        $FIDO2JSON = $FIDO2 | ConvertFrom-Json
        $AttestationObject = $FIDO2JSON.publicKeyCredential.response.attestationObject
        $ClientDataJson = $FIDO2JSON.publicKeyCredential.response.clientDataJSON
        $Id = $FIDO2JSON.publicKeyCredential.id
        $Body = @{
            displayName         = $DisplayName
            publicKeyCredential = @{
                id       = $Id
                response = @{
                    clientDataJSON    = $ClientDataJson
                    attestationObject = $AttestationObject
                }
            }
        }
        Invoke-MgGraphRequest -Method 'POST' -Body $Body -OutputType 'Json' -ContentType 'application/json' -Uri $URI
    } catch {
        if ($_.ErrorDetails.Message) {
            try {
                # Extract just the JSON part from the error message
                $errorMessage = $_.ErrorDetails.Message

                # Find where the JSON begins (look for first '{')
                $jsonStartIndex = $errorMessage.IndexOf('{"error')
                if ($jsonStartIndex -ge 0) {
                    $jsonPart = $errorMessage.Substring($jsonStartIndex)

                    # Parse the JSON
                    $errorObject = ConvertFrom-Json $jsonPart -ErrorAction Stop

                    # Extract the actual error details
                    $errorCode = $errorObject.error.code
                    $detailedMessage = $null
                    $subCode = $null

                    # Try to parse the nested JSON in message property if it exists
                    if ($errorObject.error.message -and $errorObject.error.message -match '^\{.*\}$') {
                        try {
                            $innerError = ConvertFrom-Json $errorObject.error.message -ErrorAction Stop

                            if ($innerError.'odata.error'.message.value) {
                                $detailedMessage = $innerError.'odata.error'.message.value
                            }

                            # Extract subCode if available
                            $values = $innerError.'odata.error'.values
                            if ($values) {
                                $subCodeItem = $values | Where-Object { $_.item -eq "subCode" } | Select-Object -First 1
                                if ($subCodeItem) {
                                    $subCode = $subCodeItem.value
                                }
                            }
                        } catch {
                            # If inner parsing fails, use message as is
                            $detailedMessage = $errorObject.error.message
                        }
                    } else {
                        $detailedMessage = $errorObject.error.message
                    }

                    # Output structured error information
                    Write-Warning -Message "FIDO2 Registration Error: $detailedMessage (Code: $errorCode, SubCode: $subCode)"

                    # Special handling for policy-related errors
                    if ($subCode -eq "error_feature_disallowed_by_policy") {
                        Write-Warning -Message "The FIDO credential policy is disabled in your tenant. An administrator must enable this policy in Entra ID."
                    }
                } else {
                    # No JSON found, output raw error
                    Write-Warning -Message "Failed to register the FIDO2 key: $errorMessage"
                }
            } catch {
                # Fallback for parsing errors
                Write-Warning -Message "Failed to parse error details. Original error: $($_.ErrorDetails.Message)"
            }
        } else {
            # Standard error handling if no ErrorDetails.Message
            Write-Warning -Message "Failed to register the FIDO2 key in Entra ID: $_"
        }
    }
}