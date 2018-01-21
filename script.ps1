<#
  .SYNOPSIS
    This script obtains the network's external IP and triggers an email
    when a change is detected.
  .DESCRIPTION
    On first run the script executes the following tasks:

    • Creates C:\Get-MyIP folder
    • Gets IP and outputs an "old" TXT file
    • Gets IP and outputs a "new" TXT file
    • Copies itself to the new folder
    • Creates a scheduled task to run daily
    • Completes script (see next entry)

    On subsequent runs the script:

    • Gets the lastest IP    
    • Compares the old and new text files
    • Triggers email if there is a difference
    • (Optional) Registers new IP with NameCheap.com

  .EXAMPLE
  This script does not have any examples.  It just runs and works.

  .NOTES
    • No changes are made to the computer except adding the scheduled task.
    • You can remove all the "Write-Host" lines do it please ya.  That's just for testing.
    • I have no idea what I'm doing.  Send suggestions to scott@hurricanecoast.online.
  #>


# Wrap the whole mess up into a function and call it at the end

Function Get-MyIP {

# Setup another, nested function so we're not repeating the "send mail" code more than             
once.  Because we're not diptsticks.

Function Send-Email {
$emailSmtpServer = "smtp-mail.outlook.com"
$emailSmtpServerPort = "587"
$emailSmtpUser = "you@hotmail.com"
$emailSmtpPass = "password"
# NOTE!  Some spam filters mark you for having identical TO and FROM emails.  Make         
them different if possible and preferably in the same domain. 
$emailFrom = "you@HotMail.com"
$emailTo = "you@HotMail.com"
$emailMessage = New-Object System.Net.Mail.MailMessage( $emailFrom , $emailTo )
$emailMessage.Subject = "New IP Info" + " " + $env:computername  # I can't use         
.PadLeft or .PadRight becasue dumb.
$emailMessage.Body = $env:computername + " "  + "changed to" + " " + $New
$SMTPClient = New-Object System.Net.Mail.SmtpClient( $emailSmtpServer ,         
$emailSmtpServerPort )
$SMTPClient.EnableSsl = $True
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $emailSmtpUser             
, $emailSmtpPass )
$SMTPClient.Send( $emailMessage ) 
# Additional parameters you can add:
# $emailcc="CC"
# $emailMessage.cc.add($emailcc)
# $emailMessage.IsBodyHtml = false (true or false depends)
}

# Go check if there's a folder into which to dump files. 

$IPInfoPath = Test-Path -Path "C:\Get-MyIP"

If ($IPInfoPath -eq $False) { New-Item -ItemType Directory -Path "C:\Get-MyIP" }

# Go see if the IP file exists, if it's not there, i.e. this is a first run, create it and call it         
"old"

$Exists = Test-Path -Path "C:\Get-MyIP\IP_old.txt"


If ( $Exists -eq $False ) { 
Write-Host `n"First run!  Creating new IP file and registering new Scheduled Task." `n

$OldIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp IP | Out-File "C:\Get-    
MyIP\IP_Old.txt" 

# Copy this script, from it's current location, to the C:\Get-MyIP\ directory so we can         
call it with a scheduled task

$OutputFile = $PSCommandPath

Copy-Item $OutputFile "C:\Get-MyIP" -Recurse

# Create a path for the new module and copy script 

New-Item -ItemType Directory -Path 
C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Get-MyIP

Copy-Item "C:\Get-MyIP\Get-MyIP.ps1" -Destination 
C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Get-MyIP\Get-MyIP.psm1

Import-Module Get-MyIP

# Create a scheduled task on first run and register it.

$Action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument {-                
ExecutionPolicy Bypass -File "C:\Get-MyIP\Get-MyIP.ps1"}

$Trigger = New-ScheduledTaskTrigger -Daily -At 7am

$Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType 
ServiceAccount -RunLevel Highest

$Set = New-ScheduledTaskSettingsSet

$Task = New-ScheduledTask -Action $Action -Principal $Principal -Trigger $Trigger -
Settings $Set -Description "Get external IP, compare to previous IP, trigger an email on 
changes."

Register-ScheduledTask Get-MyIP -InputObject $Task -Force }


Else { Write-Host `n"Old IP file exists.  Getting the latest IP." `n }

# In any case, go get the latest external IP, create a text file and call it "new".

$NewIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp IP | Out-File "C:\Get-
MyIP\IP_New.txt"

# If the contents of those files are not equal trigger an email.

$Old = Get-Content "C:\Get-MyIP\IP_Old.txt"
$New = Get-Content "C:\Get-MyIP\IP_New.txt"

Write-Host "Old IP:"  $Old `n
Write-Host "New IP:"  $New `n

# Send email on "first run".

If ($Exists -eq $False ) {

Write-Host "Sending email notification." `n

Invoke-RestMethod http://ipinfo.io/json | Select -exp IP | Out-File "C:\Get-
MyIP\IP_Old.txt"

Send-Email
}

If ($Old -ne $New ) {

Write-Host "IP has changed. Sending email notification." `n

Invoke-RestMethod http://ipinfo.io/json | Select -exp IP | Out-File "C:\Get-
MyIP\IP_Old.txt"

Send-Email
}

Get-MyIP
