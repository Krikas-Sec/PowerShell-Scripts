<#
.SYNOPSIS
    Resolves subdomains from a URL list and outputs valid domains and full DNS records.

.PARAMETER Path
    Input file with full URLs (e.g., https://sub.domain.com).

.PARAMETER Output
    Output file with only resolved hostnames.

.PARAMETER Json
    Optional output file for full DNS record details (default: dns_records.json).

.PARAMETER RateLimit
    Max number of DNS queries per second (default: 5).
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Output,

    [string]$Json = "dns_records.json",

    [double]$RateLimit = 5
)

# Rate limiting
$delay = [math]::Ceiling(1000 / $RateLimit)

# Prepare outputs
if (Test-Path $Output) { Clear-Content $Output } else { New-Item $Output -ItemType File -Force | Out-Null }
if (Test-Path $Json)   { Clear-Content $Json   } else { New-Item $Json   -ItemType File -Force | Out-Null }

# DNS record storage
$dnsInfoList = @()

# Extract unique hostnames from URLs
$urls = Get-Content -Path $Path
$domains = $urls | ForEach-Object {
    try { ([System.Uri]$_).Host } catch { Write-Warning "Invalid URL: $_"; $null }
} | Where-Object { $_ } | Sort-Object -Unique

foreach ($domain in $domains) {
    try {
        $records = Resolve-DnsName -Name $domain -ErrorAction Stop

        # Save to resolved.txt
        Add-Content -Path $Output -Value $domain
        Write-Host "[+] $domain resolves" -ForegroundColor Green

        # Format DNS record data
        $recordInfo = [PSCustomObject]@{
            Domain  = $domain
            Records = $records | Select-Object Name, Type, TTL, IPAddress, NameHost, NameExchange
            Timestamp = (Get-Date).ToString("s")
        }

        $dnsInfoList += $recordInfo
    } catch {
        Write-Host "[-] $domain did not resolve." -ForegroundColor DarkGray
    }

    Start-Sleep -Milliseconds $delay
}

# Output full DNS records as JSON
$dnsInfoList | ConvertTo-Json -Depth 3 | Set-Content -Path $Json -Encoding UTF8
Write-Host "[*] DNS data saved to: $Json" -ForegroundColor Cyan
