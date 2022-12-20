Import-Module .\KnaufAzure.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All, Mail.Send

# email information
$EmailFrom = 'przemyslaw.klys@evotec.pl'
$EmailTo = 'przemyslaw.klys@evotec.pl'

## app names
$AppNames = @(
    #@{ ApplicationName = '1sp-ct-knaufnow-prod'; Description = 'Management SP Knauf Now - Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-knaufnow-non-prod' ; Description = 'Management SP Knauf Now - Non Production'; ServicePrincipal = $true }
    #@{ ApplicationName = '1sp-ct-sandbox'; Description = 'Management SP for sandbox subscription'; ServicePrincipal = $true }
    'ServiceNow Intune Integration1'
)

Send-MyApp -EmailFrom $EmailFrom -EmailTo $EmailTo -ApplicationName $AppNames -Domain 'knauf.com'