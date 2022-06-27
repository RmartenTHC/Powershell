$report=[System.Collections.ArrayList] @()
$kmartmigrationpath="OU=Users,OU=Searshomeservices,OU=Locations,DC=kih,DC=Kmart,DC=com"
$all=Get-ADUser -Filter * -SearchBase $kmartmigrationpath 
foreach($a in $all){
$mb=Get-LocalRemoteMailbox -Identity $a.SamAccountName|select *legacy*,*rem*
$exo=Get-EXOMailbox -Identity $a.SamAccountName -PropertySets Minimum,StatisticsSeed,Archive -Properties LegacyExchangeDN
$mbObj = New-Object PSObject
$mbObj| Add-Member -MemberType NoteProperty -Name "Samaccountname" -Value $a.SamAccountName -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "alias" -Value $exo.Alias -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "Target" -Value $mb.RemoteRoutingAddress -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "OnlineLDN" -Value $exo.LegacyExchangeDN -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "localldn" -Value $mb.LegacyExchangeDN -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "mail" -Value $exo.PrimarySmtpAddress -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "ExchangGuid" -Value $exo.ExchangeGuid.Guid -Force
$mbObj| Add-Member -MemberType NoteProperty -Name "ArchiveGuid" -Value $exo.ArchiveGuid.Guid -Force
[VOID]$report.Add($mbObj)
}
$report|Export-Csv -NoTypeInformation  shspilot.csv
