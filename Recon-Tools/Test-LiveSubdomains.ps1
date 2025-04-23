<#
.SYNOPSIS
    Tests subdomains for live HTTP/HTTPS services, logs response headers as JSON, and enforces request rate limits.

.PARAMETER Path
    Input file with subdomains.

.PARAMETER File
    Output file for live domains (status 200).

.PARAMETER TimeoutSec
    Timeout in seconds per request.

.PARAMETER RateLimit
    Max requests per second (default 5 total across all schemes).
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Output,

    [int]$TimeoutSec = 5,

    [double]$RateLimit = 5
)

# Output files
$liveOut = $Output
$unreachableOut = [System.IO.Path]::Combine((Split-Path $Output), "unreachable_domains.txt")
$jsonOut = [System.IO.Path]::Combine((Split-Path $Output), "fingerprints.json")
$fingerprintList = @()
$headers = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }

# Smart logic: If both http & https are used per subdomain, warn user
$requestsPerSubdomain = 2
if ($RateLimit -gt 0 -and $RateLimit -lt ($requestsPerSubdomain * 5)) {
    Write-Host "[*] Smart Rate Limiter: You are sending $requestsPerSubdomain requests per subdomain." -ForegroundColor Yellow
    Write-Host "[*] Adjusting delay to respect $RateLimit req/sec TOTAL..." -ForegroundColor Yellow
}

# Delay in ms per request
$delay = [math]::Ceiling(1000 / $RateLimit)

# Setup output files
@($liveOut, $unreachableOut, $jsonOut) | ForEach-Object {
    if (Test-Path $_) {
        Clear-Content $_
    } else {
        New-Item -ItemType File -Path $_ -Force | Out-Null
    }
}

# Load subdomains
$subdomains = Get-Content -Path $Path

foreach ($sub in $subdomains) {
    foreach ($scheme in @("https", "http")) {
        $url = "${scheme}://${sub}"
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers $headers

            # Collect fingerprint info
            $info = [PSCustomObject]@{
                URL            = $url
                Status         = $response.StatusCode
                Server         = $response.Headers["Server"]
                XPoweredBy     = $response.Headers["X-Powered-By"]
                ContentType    = $response.Headers["Content-Type"]
                ContentLength  = $response.Headers["Content-Length"]
                SetCookie      = $response.Headers["Set-Cookie"]
                Timestamp      = (Get-Date).ToString("s")
            }

            if ($info.Status -eq 200) {
                Write-Host "$url is LIVE (200)" -ForegroundColor Green
                Add-Content -Path $liveOut -Value $url
            } else {
                Write-Host "$url responded with $($info.Status)" -ForegroundColor Yellow
            }

            $fingerprintList += $info
        } catch {
            Write-Host "$url is not reachable." -ForegroundColor Red
            Add-Content -Path $unreachableOut -Value $url
        }

        Start-Sleep -Milliseconds $delay
    }
    
}
# Final JSON write
$fingerprintList | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonOut -Encoding UTF8