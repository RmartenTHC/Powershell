#####Target

# Enable customization if tenant is dehydrated
$dehydrated=Get-OrganizationConfig | select isdehydrated
if ($dehydrated.isdehydrated -eq $true) {Enable-OrganizationCustomization}
$AppId = "45c580b1-2951-4318-8926-39e2c0362ec0"
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppId, (ConvertTo-SecureString -String "AeE8Q~XWBCpJaDIRhYtjan0dZcbstqTdNL0yhaWd" -AsPlainText -Force)
New-MigrationEndpoint -RemoteServer outlook.office.com -RemoteTenant "searshc.onmicrosoft.com" -Credentials $Credential -ExchangeRemoteMove:$true -Name "THC-SHS" -ApplicationId $AppId
#############
###ORG for Mailboxmove
$sourceTenantId="searshc.onmicrosoft.com"
$orgrels=Get-OrganizationRelationship
$existingOrgRel = $orgrels | ?{$_.DomainNames -like $sourceTenantId}
If ($null -ne $existingOrgRel)
{
    Set-OrganizationRelationship $existingOrgRel.Name -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability Inbound
}
If ($null -eq $existingOrgRel)
{
    New-OrganizationRelationship "[name of the new organization relationship]" -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability Inbound -DomainNames $sourceTenantId
}








###Source
###Consent from Source
https://login.microsoftonline.com/searshc.onmicrosoft.com/adminconsent?client_id=45c580b1-2951-4318-8926-39e2c0362ec0&redirect_uri=https://office.com
$targetTenantId="TransformHomePro.onmicrosoft.com"
$appId="45c580b1-2951-4318-8926-39e2c0362ec0"
$scope="SHS_TENANT_ALLOW_MIGRATION"
$orgrels=Get-OrganizationRelationship
$existingOrgRel = $orgrels | ?{$_.DomainNames -like $targetTenantId}
If ($null -ne $existingOrgRel)
{
    Write-Host "changing $existingOrgRel" -ForegroundColor Yellow
     Set-OrganizationRelationship "SHIPS|HOMEPRO|SHS" -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability RemoteOutbound -OAuthApplicationId $appId -MailboxMovePublishedScopes $scope -Force
}
If ($null -eq $existingOrgRel)
{
    Write-Host "New" -ForegroundColor Red
    New-OrganizationRelationship  -Enabled:$true -MailboxMoveEnabled:$true -MailboxMoveCapability RemoteOutbound -DomainNames $targetTenantId -OAuthApplicationId $appId -MailboxMovePublishedScopes $scope
}

###Target tenant:
Test-MigrationServerAvailability -Endpoint "THC-SHS"

Get-OrganizationRelationship "SHIPS|HOMEPRO|SHS" | fl name, DomainNames, MailboxMoveEnabled, MailboxMoveCapability

####Source tenant:
Get-OrganizationRelationship "SHIPS|HOMEPRO|SHS" | fl name, DomainNames, MailboxMoveEnabled, MailboxMoveCapability



###lh
Set-MailUser -Identity <MailUserIdentity> -EnableLitigationHoldForMigration
$ELCValue = 0
if ($source.LitigationHoldEnabled) {$ELCValue = $ELCValue + 8} if ($source.SingleItemRecoveryEnabled) {$ELCValue = $ELCValue + 16} if ($ELCValue -gt 0) {Set-ADUser -Server $domainController -Identity $destination.SamAccountName -Replace @{msExchELCMailboxFlags=$ELCValue}}

######User SETUP
###Get Source Account
$sourceuser=Get-ADUser -Identity shsmigrate1 -Server kih.kmart.com -Properties *
$sourceMBX=Get-EXOMailbox shsmigrate1 -PropertySets All ##Source Tenant

###Set Target Account for mail migration####
$targetuser=Get-ADUser -Identity -Server searshomeservices.com -Properties *

$X500=("X500:"+$sourceMBX.legacyExchangeDN)
##Enable Mail user
Set-ADUser -Identity $targetuser.samaccountname -Replace @{targetaddress=$sourceuser.targetAddress;mailnickname=$sourceuser.mailNickname;mail="TARGETDOMAINSUFFIX";msExchRecipientTypeDetails="2147483648";msExchRecipientDisplayType="-1073741818"} -Server searshomeservices.com
Set-ADUser -Identity $targetuser.samaccountname -Add @{proxyAddresses=$X500} -Server searshomeservices.com
Get-MailUser -Identity $targetuser.mail
Set-MailUser -Identity $targetuser.mail -ExchangeGuid $sourceMBX.ExchangeGuid.Guid -ArchiveGuid $sourceMBX.ArchiveGuid.Guid
$sourceuser.legacyExchangeDN
$sourceMBX.LegacyExchangeDN