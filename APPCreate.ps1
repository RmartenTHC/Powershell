# Login to Azure AD PowerShell With Admin Account
Connect-AzureAD

# Create the self signed cert
$currentDate = Get-Date
$endDate  = $currentDate.AddYears(1)
$notAfter  = $endDate.AddYears(1)
$pwd  = "Sears123"
$thumb = (New-SelfSignedCertificate -CertStoreLocation cert:\localmachine\my -DnsName "transformco.com" -KeyExportPolicy Exportable  -NotAfter $notAfter ).Thumbprint
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
Export-PfxCertificate -cert "cert:\localmachine\my\$thumb" -FilePath C:\temp2 -Password $pwd

# Load the certificate
$cert  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate("YOUR_PFX_PATH.pfx", $pwd)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

# Create the Azure Active Directory Application
$application = New-AzureADApplication -DisplayName "YOUR_APP_NAME" -IdentifierUris "https://YOUR_APP_NAME"
New-AzureADApplicationKeyCredential -ObjectId $application.ObjectId -CustomKeyIdentifier "YOUR_PASSWORD" -StartDate $currentDate -EndDate $endDate -Type AsymmetricX509Cert -Usage Verify -Value $keyValue

# Create the Service Principal and connect it to the Application
$sp = New-AzureADServicePrincipal -AppId $application.AppId

# Give the Service Principal Reader access to the current tenant (Get-AzureADDirectoryRole)
Add-AzureADDirectoryRoleMember -ObjectId 72f988bf-86f1-41af-91ab-2d7cd011db47 -RefObjectId $sp.ObjectId

# Get Tenant Detail
$tenant = Get-AzureADTenantDetail

# Now you can login to Azure PowerShell with your Service Principal and Certificate
Connect-AzureAD -TenantId $tenant.ObjectId -ApplicationId  $sp.AppId -CertificateThumbprint $thumb

# Output TenantId, AppId and Thumbprint to use in azure function's script
Write-Host "TenantId: "$tenant.ObjectId
Write-Host "AppId: "$sp.AppId
Write-Host "Thumbprint: "$thumb