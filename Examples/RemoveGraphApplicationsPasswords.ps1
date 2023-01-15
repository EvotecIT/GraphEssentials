Import-Module .\GraphEssentials.psd1 -Force

Connect-MgGraph -Scopes Application.ReadWrite.All

Remove-MyAppCredentials -Expired -Verbose -WhatIf -ApplicationName 'TeamsAppDelegation'
Remove-MyAppCredentials -Verbose -WhatIf -DisplayNameCredentials "O:*" -ApplicationName "Emails Graph"
Remove-MyAppCredentials -Verbose -WhatIf -Expired
Remove-MyAppCredentials -Verbose -DisplayNameCredentials "przemyslaw.klys*" -ApplicationName "sp-gy-ufi-dd" -WhatIf
