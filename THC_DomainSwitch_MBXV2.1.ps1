param([parameter(Position=0,ValueFromPipeline = $true, Valuefrompipelinebypropertyname =$true, mandatory=$true)][string]$PrimarySMTPAddress)
begin
{
################Set VARIABLES############
$targetdomain="transformco.com"
$Domain1="searshc.com"
$Domain2="searskmart.com"
$Domain3="htstores.com"
$Domain4="kdcbrands.com"
$Domain5="aefactoryservice.com"
$Domain6="servicelive.com"
$Domain7="innovelsolutions.com"
$Domain8="evoke-productions.com"
$curDateTime = (Get-Date -UFormat "%Y-%m-%d_%I:%M:%S %p").tostring()
$mailboxCounter = 0
$KMARTSERVER="trprad001"
$Sears2Server="hfprsads201.sears2.ds.sears.com"
$ExchangeServer = "trprx4excas2.kih.kmart.com"
$AlternateLogin="shcskypelogin"
$EXATT14="extensionattribute14"
$MSDS="mS-DS-ConsistencyGuid"
$ObjectGUID="ObjectGUID"
$OnPremCreds=Get-Credential -Message "Kmart Domain Admin"
$OnlineCreds=Get-Credential -Message "Online Tenant Admin"
$SearsCreds=Get-Credential -Message "Sears Domain Admin"
$Onlinecred=New-object System.Management.Automation.PSCredential $OnlineCreds.UserName,$OnlineCreds.Password
$OnPremCred=New-object System.Management.Automation.PSCredential $OnPremCreds.UserName,$OnPremCreds.Password
$searsadmin=New-Object System.Management.Automation.PSCredential $SearsCreds.UserName,$SearsCreds.Password
$Original = @()
$Modified = @()
$SearsUsers= @()
$ChangeDomain=@($Domain1,$Domain2,$Domain3,$Domain4,$Domain5,$Domain6,$Domain7,$Domain8)###Only Changing SearsKmart   SearsHC
$sears=@('Sears1','Sears2')
#############################
$ld = (get-date -UFormat "%Y%m%d").tostring()
$logPrefix = (Get-Date -UFormat "%Y%m%d_%H%M").tostring()
$path = "D:\Source\DomainNameChange"####Make work for Script server
$logDirectory = $path + "\" + $ld
New-Item -ItemType directory -Path $logDirectory -Force | Out-Null
$transcriptPath = $logDirectory + ".\"+ $logPrefix + "-PowerShellTranscript.txt"
$errorLog           = $logDirectory + ".\"+ $logPrefix + "-Errors.log"
$PreEmailChangelog = $logDirectory + ".\"+ $logPrefix + "Before_Email_Change.csv"
$PostEmailChangelog = $logDirectory + ".\"+ $logPrefix + "After_Email_Change.csv"
$SearsUsersEmail = $logDirectory + ".\"+ $logPrefix + "Sears_Users_Email_Change.csv"
if((Test-Path $logDirectory) -eq $false) 
{exit}
######All Functions###
#-------------------------------------------------------------------------------------------------------------------------------------------------------
Function Connect-ExchangeOnline 
#-------------------------------------------------------------------------------------------------------------------------------------------------------
{ 
    [CmdletBinding()] 
     param 
( 
[Parameter(Mandatory = $False)] 
[System.Management.Automation.CredentialAttribute()]$O365Creds =$($onlinecred), 
[Parameter(Mandatory = $False)] 
[System.Uri]$Urir = "https://ps.outlook.com/powershell/" 
) 


 Write-Host -ForegroundColor Green "Connecting to Office 365 ..."
 $global:session365 = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $Urir -Credential $O365Creds -Authentication "Basic" -AllowRedirection #-SessionOption $proxySettings 
 Import-PSSession $global:session365 -Prefix 365 -DisableNameChecking -AllowClobber | Out-Null 
 Return $global:session365 
 } 
#-------------------------------------------------------------------------------------------------------------------------------------------------------
Function Connect-ExchangeOnPrem
#-------------------------------------------------------------------------------------------------------------------------------------------------------
{ 
    [CmdletBinding()] 
     param 
( 
[Parameter(Mandatory = $True)] 
[string]$ExServername, 
[Parameter(Mandatory = $False)] 
[System.Management.Automation.CredentialAttribute()]$OPCreds = $($onpremcred), 
[Parameter(Mandatory = $False)] 
[System.Uri]$Uri = "http://" + $ExServername + "/powershell/" 
) 
 Write-Host -ForegroundColor Green "Connecting to Exchange ..."
 $global:OPsession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $Uri -Credential $OPCreds -Authentication "Kerberos" -AllowRedirection
 Import-PSSession $global:OPsession -AllowClobber 
 Return $global:OPsession 
 } 
Function LogWrite
#-------------------------------------------------------------------------------------------------------------------------------------------------------
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}
#-------------------------------------------------------------------------------------------------------------------------------------------------------
Function LogErrors
#-------------------------------------------------------------------------------------------------------------------------------------------------------
{
   Param ([string]$logstring)

   Add-content $Errorfile -value $logstring
}
##################Start PowerShell Transcript####
Try {
     Start-Transcript -Path $transcriptPath | Out-Null
}
Catch {

     Stop-Transcript | Out-Null

     Start-Transcript -Path $transcriptPath | Out-Null
}
###################Pull All Modules needed and will install if necessary (Except for AD,Exchnage)
Import-Module ActiveDirectory
###################Get credentials from a file rather than store Locally in text or Users########
<#
##################Pull XML file instaed of entering or storing
#>

<#################
##################Open ALL Needed Connections  (AD,LocalEXCH,OnlineEXCH,MSOL,SHAREPOINT)
##################>
Connect-ExchangeOnPrem -ExServername $ExchangeServer -OPCreds $OnPremCred|Out-Null
try{
    Get-OrganizationConfig |Out-Null
    }
Catch{
    Write-Host "Failed to Connect to Your Local Exchange Session" -ForegroundColor Red
    Stop-Transcript|Out-Null
    Exit
    }
Connect-ExchangeOnline|Out-Null
try{
    Get-365OrganizationConfig |Out-Null
    }
catch{
    Write-Host "Failed to Connect to Exchange Online" -ForegroundColor Red
    Stop-Transcript|Out-Null
    Exit
    }
}
Process
{
$EXO=$null
$RM=$null
$NewPrimary=$null
$NewAlias=$null 
$OLDATTR=$null
$ADUser=$null
$EmailDomain=$null
$LoginDomain=$null
$searsuser=$null
Write-Host "Processing " $PrimarySMTPAddress -ForegroundColor Cyan
$EXO=Get-365Mailbox $PrimarySMTPAddress |select * ####Add $ENTID Change to remote
$RM=Get-RemoteMailbox $EXO.PrimarySMTPAddress -DomainController $KMARTSERVER |select *
if($EXO -eq $null -or $RM -eq $null)
{
$msg = "$curDateTime : ERROR: User Not Found on Exchange Online [" + $PrimarySMTPAddress + "]`r"
Write-Host $msg -foregroundcolor red
Add-Content $errorLog -Value $msg
}
$EmailDomain=$EXO.PrimarySmtpAddress  -split "@"
$LoginDomain=$EXO.MicrosoftOnlineServicesID  -split "@"
$NewPrimary=$EXO.PrimarySmtpAddress -replace $EmailDomain[1],$targetdomain
$NewAlias=$EXO.Alias +"@"+ $targetdomain
$OLDATTR=Get-ADUser $RM.SamAccountName -Properties * -Server $KMARTSERVER
$ADUser=$OLDATTR
$OldObj=New-Object PSObject
$OldObj| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $OLDATTR.SamAccountName -Force
$OldObj| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $EXO.PrimarySmtpAddress-Force
$OldObj| Add-Member -MemberType NoteProperty -Name "Old 365 Login" -Value $EXO.MicrosoftOnlineServicesID -Force
$OldObj| Add-Member -MemberType NoteProperty -Name "Display name" -Value $EXO.DisplayName -Force
$OldObj| Add-Member -MemberType NoteProperty -Name "Proposed 365 Login" -Value $NewPrimary -Force
$OldObj| Add-Member -MemberType NoteProperty -Name "SHCSkypeLogin" -Value $OLDATTR.shcSkypeLogin -Force
$Original +=$OldObj
if($ChangeDomain -contains $EmailDomain[1] )
{
    if($sears -contains $RM.CustomAttribute12)
    {
    Write-Host "Take Precaution Sears User" -ForegroundColor Red
    $searsuser=Get-ADUser $RM.SamAccountName -Properties * -Server $Sears2Server
    if($ADUser.Enabled -eq $false -and $searsuser.Enabled -eq $true)
        {
        Write-Host "Sears User: Changing a user $($EXO.MicrosoftOnlineServicesID) to New $($NewPrimary)  " -ForegroundColor Red
        $mbObj2=New-Object PSObject
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $ADUser.SamAccountName -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $RM.PrimarySmtpAddress-Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "SHCSKYPELOGIN(SEARS)" -Value $searsuser.shcSkypeLogin -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Projected Email" -Value $NewPrimary -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Display name" -Value $RM.DisplayName -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Sears UPN" -Value $searsuser.UserPrincipalName -Force
        Set-RemoteMailbox $RM.SamAccountName -EmailAddressPolicyEnabled:$false -DomainController $KMARTSERVER -Confirm:$false
        Set-RemoteMailbox $RM.SamAccountName -EmailAddresses @{add=$NewAlias} -DomainController $KMARTSERVER -Confirm:$false
        Set-RemoteMailbox $RM.SamAccountName -PrimarySmtpAddress $NewPrimary -CustomAttribute14 $NewPrimary -DomainController $KMARTSERVER -Confirm:$false 
        Set-ADUser $RM.SamAccountName -Replace @{$alternatelogin=$NewPrimary} -Server $Sears2Server -Credential $Searsadmin
        Set-ADUser $RM.SamAccountName -Replace @{"mail"=$NewPrimary} -Server $KMARTSERVER -Credential $OnPremCred
        Set-ADUser $RM.SamAccountName -Replace @{"mail"=$NewPrimary} -Server $Sears2Server -Credential $Searsadmin
        Set-ADUser $RM.SamAccountName -UserPrincipalName $NewPrimary -Server $Sears2Server -Credential $Searsadmin
        $ADUser=Get-ADUser $RM.SamAccountName -Properties * -Server $KMARTSERVER
        $searsuser=Get-ADUser $RM.SamAccountName -Properties * -Server $Sears2Server
        $mbObj=New-Object PSObject
        $mbObj| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $ADUser.SamAccountName -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $RM.PrimarySmtpAddress-Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Old 365 Login" -Value $searsuser.shcSkypeLogin -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "New Primary Email" -Value $ADUser.mail-Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Display name" -Value $RM.DisplayName -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Proposed 365 Login" -Value $NewPrimary -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Actual 365 Login" -Value $searsuser.shcSkypeLogin -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "UPN" -Value $searsuser.UserPrincipalName -Force
        $SearsUsers +=$mbObj2
        $Modified +=$mbObj
        }
    else
        {
        Write-Host "SEARS USER: Please validate Sears Account" -ForegroundColor Red
        $mbObj2=New-Object PSObject
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $ADUser.SamAccountName -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $RM.PrimarySmtpAddress-Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "SHCSKYPELOGIN(SEARS)" -Value $searsuser.shcSkypeLogin -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Projected Email" -Value $NewPrimary -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Display name" -Value $RM.DisplayName -Force
        $mbObj2| Add-Member -MemberType NoteProperty -Name "Sears UPN" -Value $searsuser.UserPrincipalName -Force
        $SearsUsers +=$mbObj2
        }
    }
    elseif($sears -notcontains $RM.CustomAttribute12)
    {
        Write-Host "KMART User:Changing user Attributes $($EXO.PrimarySmtpAddress) to  $($NewPrimary)" -ForegroundColor Cyan
        Set-RemoteMailbox $RM.SamAccountName -EmailAddressPolicyEnabled:$false -DomainController $KMARTSERVER -Confirm:$false
        Set-RemoteMailbox $RM.SamAccountName -EmailAddresses @{add=$NewAlias} -DomainController $KMARTSERVER -Confirm:$false
        Set-RemoteMailbox $RM.SamAccountName -PrimarySmtpAddress $NewPrimary -CustomAttribute14 $NewPrimary -DomainController $KMARTSERVER -Confirm:$false 
        Set-ADUser $RM.SamAccountName -Replace @{$alternatelogin=$NewPrimary} -UserPrincipalName $NewPrimary -Server $KMARTSERVER -Credential $OnPremCred
        Set-ADUser $RM.SamAccountName -Replace @{"mail"=$NewPrimary} -Server $KMARTSERVER -Credential $OnPremCred
        $ADUser=Get-ADUser $RM.SamAccountName -Properties * -Server $KMARTSERVER
        $mbObj=New-Object PSObject
        $mbObj| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $ADUser.SamAccountName -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $EXO.PrimarySmtpAddress-Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Old 365 Login" -Value $ADUser.shcSkypeLogin -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "New Primary Email" -Value $ADUser.mail-Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Display name" -Value $EXO.DisplayName -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Proposed 365 Login" -Value $NewPrimary -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Actual 365 Login" -Value $ADUser.shcSkypeLogin -Force
        $mbObj| Add-Member -MemberType NoteProperty -Name "Kmart UPN" -Value $ADUser.UserPrincipalName -Force
        $Modified +=$mbObj

    }
}
elseif($EmailDomain[1] -like $targetdomain){
    if($EXO.PrimarySmtpAddress -ne $OLDATTR.shcSkypeLogin){
    Write-Host "Set Values to match" -ForegroundColor Red
    Write-Host "KMART User:Changing user Attributes $($EXO.PrimarySmtpAddress) to  $($NewPrimary)" -ForegroundColor Cyan
    Set-RemoteMailbox $RM.SamAccountName -EmailAddressPolicyEnabled:$false -DomainController $KMARTSERVER -Confirm:$false
    Set-RemoteMailbox $RM.SamAccountName -EmailAddresses @{add=$NewAlias} -DomainController $KMARTSERVER -Confirm:$false
    Set-RemoteMailbox $RM.SamAccountName -PrimarySmtpAddress $NewPrimary -CustomAttribute14 $NewPrimary -DomainController $KMARTSERVER -Confirm:$false 
    Set-ADUser $RM.SamAccountName -Replace @{$alternatelogin=$NewPrimary} -UserPrincipalName $NewPrimary -Server $KMARTSERVER -Credential $OnPremCred
    Set-ADUser $RM.SamAccountName -Replace @{"mail"=$NewPrimary} -Server $KMARTSERVER -Credential $OnPremCred
    $ADUser=Get-ADUser $RM.SamAccountName -Properties * -Server $KMARTSERVER
    $mbObj=New-Object PSObject
    $mbObj| Add-Member -MemberType NoteProperty -Name "Enterprise ID" -Value $ADUser.SamAccountName -Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Primary Email Before" -Value $EXO.PrimarySmtpAddress-Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Old 365 Login" -Value $ADUser.shcSkypeLogin -Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "New Primary Email" -Value $ADUser.mail-Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Display name" -Value $EXO.DisplayName -Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Proposed 365 Login" -Value $NewPrimary -Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Actual 365 Login" -Value $ADUser.shcSkypeLogin -Force
    $mbObj| Add-Member -MemberType NoteProperty -Name "Kmart UPN" -Value $ADUser.UserPrincipalName -Force
    $Modified +=$mbObj
    }
    else{
    Write-Host "Values match" -ForegroundColor Cyan
    }
}
else{
    Write-Host "Need to Add Proxy Addresses for User in Domain $($EmailDomain[1]) " -ForegroundColor Red
    Set-RemoteMailbox $RM.SamAccountName -EmailAddresses @{add=$NewAlias,$NewPrimary} -DomainController $KMARTSERVER -Confirm:$false
    }
}


End
{
$Original|Export-Csv -Path $PreEmailChangelog -NoTypeInformation
$Modified|Export-Csv -Path $PostEmailChangelog -NoTypeInformation
$SearsUsers|Export-Csv -Path $SearsUsersEmail -NoTypeInformation
Stop-Transcript|Out-Null
Get-PSSession|Remove-PSSession
Exit
}



