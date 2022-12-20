function Send-MyApp {
    [cmdletBinding()]
    param(
        [parameter(Mandatory)][Array] $ApplicationName,
        [parameter(Mandatory)][string] $EmailFrom,
        [parameter(Mandatory)][string[]] $EmailTo,
        [string] $EmailSubject = 'Service Principal for Applications',
        [parameter(Mandatory)][string] $Domain,
        [switch] $RemoveOldCredentials
    )

    $TenantID = Get-O365TenantID -Domain $Domain

    $Applications = foreach ($App in $ApplicationName) {
        if ($App -is [string]) {
            $DisplayNameCredentials = $EmailTo -join ";"
            New-MyApp -ApplicationName $App -DisplayNameCredentials $DisplayNameCredentials -Verbose -RemoveOldCredentials:$RemoveOldCredentials.IsPresent
        } else {
            if ($App.DisplayNameCredentials) {
                New-MyApp @App
            } else {
                $DisplayNameCredentials = $EmailTo -join ";"
                New-MyApp @App -DisplayNameCredentials $DisplayNameCredentials -Verbose -ServicePrincipal -RemoveOldCredentials:$RemoveOldCredentials.IsPresent
            }
        }
    }

    $EmailBody = EmailBody {
        EmailText -Text "Hello," -LineBreak
        EmailText -Text @(
            "As per your request we have created following Service Principal for you:"
        )
        EmailText -LineBreak

        foreach ($Application in $Applications) {
            EmailText -Text @(
                "Application ", $Application.ApplicationName, " credentials are: "
            ) -Color None, BlueDiamond, None -TextDecoration none, underline, none -FontWeight normal, bold, normal

            EmailList {
                EmailListItem -Text "Application Name: ", $Application.ApplicationName -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client ID: ", $Application.ClientID -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client SecretID: ", $Application.ClientSecretID -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Client Secret: ", $Application.ClientSecret -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Expires: ", $Application.EndDateTime, " (Valid days: $($Application.DaysToExpire))" -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            }
        }
        EmailText -LineBreak

        EmailText -Text @(
            "If required TenantID/DirectoryID is: ", $TenantID
        ) -LineBreak -Color None, LawnGreen -FontWeight normal, bold

        EmailText -Text @(
            "Please remove this email from your inbox once you have copied the credentials into secure place."
        ) -FontWeight normal, normal, bold, normal, normal -Color None, None, Salmon, None, None -LineBreak

        EmailText -Text "Thank you"
    }

    $EmailStatus = Send-EmailMessage -From $EmailFrom -To $EmailTo -HTML $EmailBody -Subject $EmailSubject -Verbose -Priority Normal -MgGraphRequest

    [ordered] @{
        EmailStatus  = $EmailStatus
        Applications = $Applications
    }
}