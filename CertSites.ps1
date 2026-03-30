# Self-sign certificate generator - 2.1
# CertSites.ps1 - 20260330_10

# Variable
$CertPath       = ".\PnPCert.pfx"                             
$CertHours      = Read-Host "Expiration? (In hours)" 
$CertCN         = Read-Host "Cert CN?" 
# Cert Password Secure-Plain-Secure
$SecureInput = Read-Host "Enter certificate password" -AsSecureString
$RawPass     = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureInput))
$SecurePass  = ConvertTo-SecureString $RawPass -AsPlainText -Force

# Generate self-signed certificate
$Cert = New-SelfSignedCertificate `
    -Subject "CN=$CertCN" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -NotAfter (Get-Date).AddHours($CertHours)

# Export PFX (for use in script)
Export-PfxCertificate -Cert $Cert -FilePath $CertPath -Password $SecurePass

# Export CER (to upload to Entra ID App Registration)
Export-Certificate -Cert $Cert -FilePath ".\PnPCert.cer"

Write-Host "Certificate created!" -ForegroundColor Green
Write-Host "Next: Upload PnPCert.cer to your App Registration > Certificates & Secrets > Certificates" -ForegroundColor Yellow