# SPOStaleUsersCheck
Scans all SharePoint Online site collections (including subsites) and identifies stale users — accounts that exist in SharePoint groups but no longer exist in Entra ID (Azure AD).

---

## Configuration

Open the script and update the **Variables** section at the top:

| Variable | Description |
|---|---|
| `$TenantId` | Your Entra ID Tenant ID |
| `$ClientId` | App registration Client ID |
| `$CertPath` | Full path to your `.pfx` certificate file |
| `$AdminUrl` | SharePoint Admin Center URL |
| `$OutputCSV` | Full path where the output CSV report will be saved |

---

## Usage

Run the script in PowerShell:

```powershell
.\SPOStaleUsersCheck.ps1
```

When prompted, enter the password for your `.pfx` certificate. The input will be masked.

---

## Output

A CSV file saved to the path defined in `$OutputCSV`, containing the following columns:

| Column | Description |
|---|---|
| SiteUrl | URL of the site collection |
| SiteTitle | Title of the site collection |
| WebUrl | URL of the web (site or subsite) |
| WebTitle | Title of the web |
| IsSubsite | True if the entry is from a subsite |
| DisplayName | Display name of the stale user |
| Email | UPN (email) of the stale user |
| PermissionLevel | Site Admin / Site Owner / Site Member / Site Visitor / Custom Group |
| Group | SharePoint group name the user belongs to |

---

## Notes
- This script is **read-only**. It makes no changes to SharePoint or Entra ID.
- OneDrive personal sites (`-my.sharepoint.com`) are excluded from the scan.
- Subsites are scanned recursively under each site collection.
