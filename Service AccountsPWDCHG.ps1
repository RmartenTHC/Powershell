<# 
Created by Rob Martens 
2014/11/21 
Change Service Account Passwords 
this script will take input from a csv with Header as Server and fqdn of servers...

#> 
param([parameter(Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, mandatory=$true)][string]$server) 

begin{
#Prompts for user input for the username and password for the service account you are changing the account 
$Credential = get-credential -Message "Enter credentials with new Password" -UserName "Kmart\SqlProd"
 
#Converts the password to clear text to pass it through correctly as passing through a secure string does not work. 
$Password = $credential.GetNetworkCredential().password 
}
process
{
#Gets every server within Active Directory 
$servers = Get-ADComputer -Identity $server
$Account = $credential.UserName 

$Services = Get-WmiObject win32_service -computer $Server | where-object StartName -EQ $Account 
foreach ($Service in $Services) 
    { 
    #Following line output will be supressed. Remove 'out-null' to see results 
    $Service.stopservice() | Out-Null 
            $Value = $Service.stopservice() | select-object ReturnValue 
            if ($Value.ReturnValue -eq '5')  
            {Write-Host "$Service.name is already stopped on $Server"  -BackgroundColor Black -ForegroundColor Yellow} 
            if ($Value.ReturnValue -eq '0')  
            {Write-Host "$Service.name has been successfully stopped on $Server"  -BackgroundColor Black -ForegroundColor Green} 
            if ($Value.ReturnValue -eq '2')  
            {Write-Host "Access has been denied to $Service.name on $Server - Try running the command as administrator"  -BackgroundColor Black -ForegroundColor Red} 
    #Following line output will be supressed. Remove 'out-null' to see results 
    $Service.Change($Null,$Null,$Null,$Null,$Null,$Null,$Null,"$Password") | Out-Null 
            Write-Host "Changing password for $Service.name on $Server"  -BackgroundColor Black -ForegroundColor Yellow 
    #Following line output will be supressed. Remove 'out-null' to see results 
    $Service.StartService() | Out-Null 
            $Value = $Service.startservice() | select-object ReturnValue 
            if ($Value.ReturnValue -eq '0')  
            {Write-Host "$Service.name started successfully on $Server" -BackgroundColor Black -ForegroundColor Green} 
            if ($Value.ReturnValue -eq '10') 
            {Write-Host "$Service.name is already started successfully on $Server" -BackgroundColor Black -ForegroundColor Green} 
            else {Write-Host "$Service.name cannot start on $Server probably due to a logon failure, check the password again." -BackgroundColor Black -ForegroundColor Red} 
    }


    }

    end {


    }
