<#
.SYNOPSIS
    Retrieves subdomains from crt.sh for a given domain.

.DESCRIPTION
    This script queries crt.sh for SSL certificate records and extracts unique subdomains.
    The results are sorted and displayed, and optionally saved to a file.

.PARAMETER Domain
    The target domain to search for subdomains.

.PARAMETER File
    (Optional) The path to an output file where subdomains will be saved.

.EXAMPLE
    .\Get-CertSubdomains.ps1 -Domain temphack.org
    .\Get-CertSubdomains.ps1 -Domain temphack.org -File subdomains.txt
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the target domain (e.g., example.com)")]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "Optional output file to save subdomains")]
    [string]$File
)

# Encode the domain for crt.sh query
$encodedDomain = "%25." + $Domain

# Construct the URL
$url = "https://crt.sh/?q=$encodedDomain&output=json"

Write-Host "`n[+] Fetching subdomains for: $Domain" -ForegroundColor Green

try {
    # Send request to crt.sh
    $crtshData = Invoke-RestMethod -Uri $url -ErrorAction Stop

    # Extract and sort unique subdomains
    $subdomains = $crtshData | ForEach-Object { $_.name_value } | Sort-Object -Unique

    # Display results
    if ($subdomains) {
        Write-Host "[+] Found subdomains:" -ForegroundColor Cyan
        $subdomains | ForEach-Object { Write-Host $_ }

        # Save to file if specified
        if ($File) {
            $subdomains | Out-File -FilePath $File -Encoding UTF8
            Write-Host "[+] Subdomains saved to $File" -ForegroundColor Green
        }
    } else {
        Write-Host "[!] No subdomains found." -ForegroundColor Yellow
    }

} catch {
    Write-Host "[X] Error: Could not retrieve data. crt.sh may be down or unreachable." -ForegroundColor Red
}
