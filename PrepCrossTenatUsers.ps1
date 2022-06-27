$shs=Import-Csv .\shspilot.csv
$setSize=$shs.Count
$counter=0
foreach($user in $shs)
{
    if($setSize -gt 0){
        $counter++
        Write-Progress -Activity "Migrating User $($user.Samaccountname)" -status "Users processed: $($counter) of $($setSize)" -percentComplete (($counter / $setSize)*100)
        }

$aduser=Get-ADUser -id $user.Samaccountname -Server searshomeservices.com -ErrorAction SilentlyContinue
if($aduser -ne $null)
{
$targetdomain="searshomeservices.com"
$target=("SMTP:"+$user.Alias+"@searshc.onmicrosoft.com")
$EmailDomain=$user.mail -split "@"
$mail=$user.mail -replace $EmailDomain[1],$targetdomain
$email=("SMTP:"+$mail)
$emailaddresses=[System.Collections.ArrayList] @()
$X500=("X500:"+$user.OnlineLDN)
$x501=("X500:"+$user.localldn)
[VOID]$emailaddresses.Add($X500)
[VOID]$emailaddresses.Add($X501)
[VOID]$emailaddresses.Add($email)
Set-ADUser -Identity $user.Alias -Replace @{mailnickname=$user.Alias;mail=$mail;msExchRecipientTypeDetails="2147483648";msExchRecipientDisplayType="-1073741818"} -Server searshomeservices.com -WhatIf
Set-ADUser -Identity $user.Alias -Add @{proxyaddresses=$X500} -Server searshomeservices.com -WhatIf
Set-ADUser -Identity $user.Alias -Add @{proxyaddresses=$X501} -Server searshomeservices.com -WhatIf
Set-ADUser -Identity $user.Alias -Add @{proxyaddresses=$email} -Server searshomeservices.com -WhatIf
Set-ADUser $user.alias -Replace @{msExchMailboxGuid=$([System.Guid]$user.ExchangGuid).ToByteArray()}  -Server searshomeservices.com -WhatIf
Set-ADUser $user.alias -Replace @{msExchArchiveGUID=$([System.Guid]$user.ArchiveGuid).ToByteArray()} -Server searshomeservices.com -WhatIf
}
else
{
Write-Host "User has not migrated yet"
}
}
