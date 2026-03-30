# Checking SPO Stale Users includes Subsites - 2.1
# SPOStaleUsersCheck.ps1 - 20260330_10

## Variables
$TenantId    = "PUT-TENANTID-HERE"
$ClientId    = "PUT-CLIENTID-HERE"
$CertPath    = ".\PnpCert.pfx"
$AdminUrl    = "https://SPOTENANTNAMEHERE-admin.sharepoint.com"
$OutputCSV   = ".\StaleSharePointUsers.csv"

## Load certificate and connect
$SecureInput = Read-Host "Enter certificate password" -AsSecureString
$RawPass     = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureInput))
$SecurePass  = ConvertTo-SecureString $RawPass -AsPlainText -Force
Connect-PnPOnline -Url $AdminUrl -ClientId $ClientId -Tenant $TenantId -CertificatePath $CertPath -CertificatePassword $SecurePass

## Fetch All users from Entra ID via paginated Graph calls
Write-Host "Loading all Entra ID users..." -ForegroundColor Yellow
$EntraUsers = @{}
$NextUrl    = "v1.0/users?`$select=userPrincipalName&`$top=999"

do {
    $Response = Invoke-PnPGraphMethod -Url $NextUrl -Method Get
    $Response.value | ForEach-Object {
        if ($_.userPrincipalName) {
            $EntraUsers[$_.userPrincipalName.ToLower()] = $true
        }
    }
    $NextUrl = $Response.'@odata.nextLink' -replace "https://graph.microsoft.com/", ""
} while ($NextUrl)

Write-Host "Loaded $($EntraUsers.Count) users from Entra ID." -ForegroundColor Green

## Reusable function to scan a single web (site or subsite) 
function Scan-Web {
    param(
        [string]$WebUrl,
        [string]$WebTitle,
        [string]$SiteUrl,    
        [string]$SiteTitle,
        [bool]$IsSubsite = $false
    )

    $WebResults = @()
    $Label      = if ($IsSubsite) { "  [Subsite]" } else { "" }
    Write-Host "$Label Scanning: $WebUrl" -ForegroundColor $(if ($IsSubsite) { "Gray" } else { "Cyan" })

    try {
        Connect-PnPOnline -Url $WebUrl -ClientId $ClientId -Tenant $TenantId -CertificatePath $CertPath -CertificatePassword $SecurePass

        ## Site Collection Admins (top-level site only) 
        if (-not $IsSubsite) {
            $Admins = Get-PnPSiteCollectionAdmin
            foreach ($User in $Admins) {
                $UPN = ($User.LoginName -replace "i:0#\.f\|membership\|", "").ToLower()
                if ($UPN -notmatch "@") { continue }
                if (-not $EntraUsers.ContainsKey($UPN)) {
                    $WebResults += [PSCustomObject]@{
                        SiteUrl         = $SiteUrl
                        SiteTitle       = $SiteTitle
                        WebUrl          = $WebUrl
                        WebTitle        = $WebTitle
                        IsSubsite       = $IsSubsite
                        DisplayName     = $User.Title
                        Email           = $UPN
                        PermissionLevel = "Site Admin"
                        Group           = "Site Collection Administrators"
                    }
                }
            }
        }

        ## All SharePoint Groups
        $Groups = Get-PnPGroup
        foreach ($Group in $Groups) {

            $PermLabel = switch -Wildcard ($Group.Title) {
                "*Owners*"   { "Site Owner" }
                "*Members*"  { "Site Member" }
                "*Visitors*" { "Site Visitor" }
                default      { "Custom Group" }
            }

            $Members = Get-PnPGroupMember -Group $Group -ErrorAction SilentlyContinue
            foreach ($User in $Members) {
                $UPN = ($User.LoginName -replace "i:0#\.f\|membership\|", "").ToLower()
                if ($UPN -notmatch "@") { continue }
                if (-not $EntraUsers.ContainsKey($UPN)) {
                    $WebResults += [PSCustomObject]@{
                        SiteUrl         = $SiteUrl
                        SiteTitle       = $SiteTitle
                        WebUrl          = $WebUrl
                        WebTitle        = $WebTitle
                        IsSubsite       = $IsSubsite
                        DisplayName     = $User.Title
                        Email           = $UPN
                        PermissionLevel = $PermLabel
                        Group           = $Group.Title
                    }
                }
            }
        }

        ## Get all subsites recursively 
        $Subsites = Get-PnPSubWeb -Recurse -ErrorAction SilentlyContinue
        Disconnect-PnPOnline

        foreach ($Subsite in $Subsites) {
            $WebResults += Scan-Web -WebUrl $Subsite.Url -WebTitle $Subsite.Title `
                -SiteUrl $SiteUrl -SiteTitle $SiteTitle -IsSubsite $true
        }

    } catch {
        Write-Host "  Failed: $_" -ForegroundColor Red
    }

    return $WebResults
}

## Main scan
$Sites   = Get-PnPTenantSite | Where-Object { $_.Url -notlike "*-my.sharepoint.com*" }
$Results = @()
$Count   = 0

foreach ($Site in $Sites) {
    $Count++
    Write-Host "[$Count/$($Sites.Count)] $($Site.Url)" -ForegroundColor Cyan
    $Results += Scan-Web -WebUrl $Site.Url -WebTitle $Site.Title `
        -SiteUrl $Site.Url -SiteTitle $Site.Title -IsSubsite $false
}

## Export to CSV
$Results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Done! $($Results.Count) stale user(s) found across all sites and subsites." -ForegroundColor Green
Write-Host "Report saved to: $OutputCSV" -ForegroundColor Green