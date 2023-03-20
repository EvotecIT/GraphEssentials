﻿Import-Module .\GraphEssentials.psd1 -Force

$ProgressPreference = 'SilentlyContinue'

Connect-MgGraph -Scopes Reports.Read.All

Get-MyUsageReports -Report 'EmailActivityCounts' -Period 7 | Format-Table *
Get-MyUsageReports -Report 'EmailActivityUserDetail' -DateTime ([DateTime]::Now.AddDays(-27)) | Format-Table *
Get-MyUsageReports -Report 'EmailActivityUserDetail' -Period 7 | Format-Table
Get-MyUsageReports -Report 'MailboxUsageDetail' -Period 7 | Format-Table
Get-MyUsageReports -Report 'MailboxUsageDetail' -DateTime ([DateTime]::Now.AddDays(-7)) | Format-Table
Get-MyUsageReports -Report 'Office365ActivationCounts' -Period 7 | Format-Table *
Get-MyUsageReports -Report 'Office365ActivationsUserCounts' -Period 7 | Format-Table *
Get-MyUsageReports -Report 'Office365ActivationsUserDetail' -Period 7 | Format-Table *
Get-MyUsageReports -Report 'EmailActivityUserDetail' -Period 7 -Verbose | Format-Table
Get-MyUsageReports -Report 'EmailActivityUserDetail' -DateTime ([DateTime]::Now.AddDays(-27)) -Verbose | Format-Table
Invoke-MyGraphUsageReports -Report 'All' -DateTime ([DateTime]::Now.AddDays(-27)) -DontSuppress