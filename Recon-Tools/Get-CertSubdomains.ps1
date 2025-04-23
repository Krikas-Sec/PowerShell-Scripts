<#
.SYNOPSIS
    Retrieves subdomains from crt.sh for a given domain.

.DESCRIPTION
    This script queries crt.sh for SSL certificate records and extracts unique subdomains.
    The results are cleaned, deduplicated, sorted, and optionally saved to a file.

.PARAMETER Domain
    The target domain to search for subdomains.

.PARAMETER File
    (Optional) The path to an output file where subdomains will be saved.

.EXAMPLE
    .\Get-CertSubdomains.ps1 -Domain example.com
    .\Get-CertSubdomains.ps1 -Domain example.com -Output subdomains.txt
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the target domain (e.g., example.com)")]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "Optional output file to save subdomains")]
    [string]$Output
)

# Encode the domain for crt.sh query
$encodedDomain = "%25." + $Domain
$url = "https://crt.sh/?q=$encodedDomain&output=json"

Write-Host "`n[+] Fetching subdomains for: $Domain" -ForegroundColor Green

try {
    $crtshData = Invoke-RestMethod -Uri $url -ErrorAction Stop

    $subdomains = $crtshData |
        ForEach-Object { $_.name_value -split "`n" } |
        ForEach-Object { $_.Trim().ToLower() } |
        Where-Object {
            $_ -and
            ($_ -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') -and    # exclude email addresses
            ($_ -like "*.$Domain" -or $_ -eq $Domain -or $_ -like "*.*.$Domain" -or $_ -like "*$Domain") -and
            ($_ -match '^[*a-z0-9.-]+$')                        # basic domain pattern
        } |
        Sort-Object -Unique

    if ($subdomains) {
        Write-Host "[+] Found subdomains:" -ForegroundColor Cyan
        $subdomains | ForEach-Object { Write-Host $_ }

        if ($Output) {
            $subdomains | Out-File -FilePath $Output -Encoding UTF8
            Write-Host "[+] Subdomains saved to $Output" -ForegroundColor Green
        }
    } else {
        Write-Host "[!] No subdomains found." -ForegroundColor Yellow
    }

} catch {
    Write-Host "[X] Error: Could not retrieve data. crt.sh may be down or unreachable." -ForegroundColor Red
}
