# Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, Mail.Send

$GraphData = Invoke-MyGraphEssentials -Type Apps, AppsCredentials -PassThru
$ExpiringAplications = foreach ($Application in $GraphData.Apps.Data) {
    if ($Application.KeysExpired -ne 'Not available' -and $Application.DaysToExpireNewest -lt 7) {
        $Application
    }
}
$CachedCredentials = [ordered] @{}
foreach ($Credentials in $GraphData.AppsCredentials.Data) {
    $CachedCredentials[$Credentials.ObjectId] = $Credentials
}

foreach ($App in $ExpiringAplications) {
    $AppCredentials = $CachedCredentials[$App.ApplicationObjectId]
    $EmailBody = EmailBody {
        EmailText -Text "Hello Service Desk," -LineBreak
        EmailText -LineBreak
        EmailText -Text @(
            "Application ", $App.ApplicationName, " has credentials that are expiring or already expired. "
        ) -Color None, BlueDiamond, None -TextDecoration none, underline, none -FontWeight normal, bold, normal

        EmailList {
            EmailListItem -Text "Application Name: ", $App.ApplicationName -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            EmailListItem -Text "Client ID: ", $App.ClientID -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            EmailListItem -Text "Owner mail: ", $App.OwnerDisplayName -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            EmailListItem -Text "Owner mail: ", $App.OwnerMail -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            EmailListItem -Text "Owner UPN: ", $App.OwnerUserPrincipal -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            EmailListItem -Text "Notes: ", $App.Notes -Color None, BlueDiamond, None -FontWeight normal, bold, normal
        }

        EmailText -Text "Following credentials are available for this application:"
        foreach ($Credentials in $AppCredentials) {
            EmailList {
                EmailListItem -Text "Key ID: ", $Credentials.KeyId -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Key Name: ", $Credentials.KeyDisplayName -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Type: ", $Credentials.Type -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Key Hint: ", $Credentials.Hint -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Days to expire: ", $Credentials.DaysToExpire -Color None, BlueDiamond, None -FontWeight normal, bold, normal
                EmailListItem -Text "Valid from: ", $Credentials.StartDateTime, " to ", $Credentials.EndDateTime -Color None, BlueDiamond, None, BlueDiamond -FontWeight normal, bold, normal, bold
                EmailListItem -Text "Is expired: ", $Credentials.Expired -Color None, BlueDiamond, None -FontWeight normal, bold, normal
            }
        }

        EmailText -Text @(
            "Please update the application credentials as soon as possible, and remove the expired ones. "
        ) -FontWeight normal, normal, bold, normal, normal -Color None, None, Salmon, None, None -LineBreak

        EmailText -Text "Thank you"
    }
    Send-EmailMessage -MgGraphRequest -From 'przemyslaw.klys@evotec.pl' -To 'przemyslaw.klys@evotec.pl' -Subject "Application $($App.ApplicationName) has expiring credentials" -Body $EmailBody
    break
}
