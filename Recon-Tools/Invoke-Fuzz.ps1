<#
.SYNOPSIS
    PowerShell-based Gobuster-style fuzzing tool for discovering hidden directories and files, with support for single or multiple target URLs.

.DESCRIPTION
    Scans one or more target URLs using a wordlist to identify accessible, forbidden, or interesting paths.
    Supports optional file extensions, rate limiting, status code filtering, HTTPS/HTTP-only filtering, and logging.
    You can provide a single target URL using -Url, or a list of URLs using -UrlFile.

.PARAMETER Url
    The base URL to fuzz (e.g., https://example.com). Use this for a single target scan.

.PARAMETER UrlFile
    Path to a file containing a list of URLs to scan (e.g., from live_domains.txt). Each line must be a valid HTTP/HTTPS URL.

.PARAMETER UseHTTPSOnly
    When scanning a list of URLs, use this switch to only scan HTTPS URLs.

.PARAMETER UseHTTPOnly
    When scanning a list of URLs, use this switch to only scan HTTP URLs.

.PARAMETER Wordlist
    Path to the wordlist file used for fuzzing.

.PARAMETER RateLimit
    Requests per second to send (default: 5). Set to 0 for no delay between requests.

.PARAMETER ShowCodes
    HTTP status codes to display in the output (default: 200,403).

.PARAMETER LogPath
    Optional path to save matching results (one entry per line in JSON format).

.PARAMETER Extensions
    Optional list of file extensions to append to each word in the wordlist (e.g., .php, .html).

.EXAMPLE
    Run a scan against a single URL with a basic wordlist:

    .\Invoke-Fuzz.ps1 -Url "https://example.com" -Wordlist ".\common.txt"

.EXAMPLE
    Scan a single URL with additional file extensions:

    .\Invoke-Fuzz.ps1 -Url "https://example.com" -Wordlist ".\common.txt" -Extensions ".php", ".html"

.EXAMPLE
    Scan a list of live domains (from subdomain discovery) using only HTTPS:

    .\Invoke-Fuzz.ps1 -UrlFile ".\live_domains.txt" -UseHTTPSOnly -Wordlist ".\common.txt"

.EXAMPLE
    Scan with increased speed (10 requests/sec), log matches to a file, and only show 200 and 403 responses:

    .\Invoke-Fuzz.ps1 -Url "http://testsite.local" -Wordlist ".\dirs.txt" -RateLimit 10 -ShowCodes 200,403 -LogPath ".\output\results.json"

.EXAMPLE
    Scan a list of HTTP-only targets with multiple extensions and save the output:

    .\Invoke-Fuzz.ps1 -UrlFile ".\live.txt" -UseHTTPOnly -Wordlist ".\web-words.txt" -Extensions ".asp", ".aspx" -LogPath ".\logs\fuzzlog.json"
#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = 'SingleUrl')]
    [string]$Url,

    [Parameter(Mandatory = $true, ParameterSetName = 'UrlList')]
    [string]$UrlFile,

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [switch]$UseHTTPSOnly,

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [switch]$UseHTTPOnly,

    [Parameter(Mandatory = $true)]
    [string]$Wordlist,

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [double]$RateLimit = 5,

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [int[]]$ShowCodes = @(200, 403),

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [string]$LogPath,

    [Parameter(ParameterSetName = 'SingleUrl')]
    [Parameter(ParameterSetName = 'UrlList')]
    [string[]]$Extensions
)

# Load wordlist
$words = Get-Content -Path $Wordlist
$totalWords = $words.Count
$totalRequests = $totalWords * (1 + ($Extensions.Count))
$count = 0
$found = @{}
$results = @()
$targetUrls = @()

if ($UrlFile) {
    $lines = Get-Content -Path $UrlFile | Where-Object { $_ -match '^https?://' }

    foreach ($line in $lines) {
        if ($UseHTTPSOnly -and $line -notmatch '^https://') { continue }
        if ($UseHTTPOnly -and $line -notmatch '^http://') { continue }
        $targetUrls += $line.TrimEnd('/')
    }
} else {
    $targetUrls = @($Url.TrimEnd('/'))
}

# Initialize tracking for each status code
foreach ($code in $ShowCodes) { $found[$code] = 0 }

# Timing and rate limiting
$startTime = Get-Date
$delay = if ($RateLimit -le 0) { 0 } else { [math]::Ceiling(1000 / $RateLimit) }
$estimatedSeconds = if ($RateLimit -le 0) { 0 } else { [math]::Ceiling($totalRequests / $RateLimit) }
$estimatedTimeSpan = [System.TimeSpan]::FromSeconds($estimatedSeconds)

# Prepare logging file
if ($LogPath) {
    if (Test-Path $LogPath) {
        Clear-Content $LogPath
    } else {
        New-Item -ItemType File -Path $LogPath -Force | Out-Null
    }
}

$lastUpdate = Get-Date
$updateIntervalSec = 1

# Function to render dashboard
function Show-Dashboard {
    Clear-Host
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "                  PowerHack Fuzzing Stats" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan

    if ($targetUrls.Count -eq 1) {
        Write-Host " Target              : $($targetUrls[0])"
    } else {
        Write-Host " Targets             : $($targetUrls.Count) domains from file"
    }

    Write-Host " Wordlist            : $Wordlist ($totalWords words)"
    if ($Extensions) {
        Write-Host " Extensions          : $($Extensions -join ', ')"
    }
    Write-Host " Total Requests      : $totalRequests"
    Write-Host " Estimated scan time : $($estimatedTimeSpan.ToString())"
    Write-Host " Progress            : $count / $totalRequests"

    foreach ($code in ($found.Keys | Sort-Object)) {
        Write-Host (" Status {0}          : {1} found" -f $code, $found[$code])
    }

    $elapsed = (Get-Date) - $startTime
    Write-Host " Elapsed Time        : $($elapsed.ToString())"
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "                 ONGOING SCAN - STAY SHARP!" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan

    if ($results.Count -gt 0) {
        Write-Host " Findings:" -ForegroundColor Green
        foreach ($res in $results[-10..-1]) {
            $color = if ($res.Status -eq 403) { 'Yellow' } elseif ($res.Status -eq 200) { 'Green' } else { 'Gray' }
            Write-Host " [$($res.Index)/$totalRequests] $($res.Path) (Status: $($res.Status), Size: $($res.Size))" -ForegroundColor $color
        }
        Write-Host "=============================================================" -ForegroundColor Cyan
    }
}





# Begin fuzzing
foreach ($baseUrl in $targetUrls) {
    foreach ($word in $words) {
        $targets = @([PSCustomObject]@{ Url = "$baseUrl/$word"; Path = "/$word" })
        if ($Extensions) {
            $targets += $Extensions | ForEach-Object {
                [PSCustomObject]@{ Url = "$baseUrl/$word$_"; Path = "/$word$_" }
            }
        }

        foreach ($target in $targets) {
            $count++
            try {
                $response = Invoke-WebRequest -Uri $target.Url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                $status = $response.StatusCode
                $size = $response.RawContentLength

                if ($ShowCodes -contains $status) {
                    if (-not $found.ContainsKey($status)) { $found[$status] = 0 }
                    $found[$status]++
                    $results += [PSCustomObject]@{
                        Index  = $count
                        Path   = $target.Path
                        Status = $status
                        Size   = $size
                    }
                    Write-Host "[$count/$totalRequests] $($target.Path) (Status: $status, Size: $size)" -ForegroundColor Green

                    if ($LogPath) {
                        $entry = [PSCustomObject]@{
                            URL    = $target.Url
                            Status = $status
                            Length = $size
                        }
                        $entry | ConvertTo-Json -Compress | Add-Content -Path $LogPath
                    }
                }
            } catch {
                if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                    $errCode = $_.Exception.Response.StatusCode

                    if ($ShowCodes -contains $errCode) {
                        if (-not $found.ContainsKey($errCode)) { $found[$errCode] = 0 }
                        $found[$errCode]++
                        $results += [PSCustomObject]@{
                            Index  = $count
                            Path   = $target.Path
                            Status = $errCode
                            Size   = 0
                        }
                        $color = if ($errCode -eq 403) { 'Yellow' } elseif ($errCode -eq 200) { 'Green' } else { 'Gray' }
                        Write-Host "[$count/$totalRequests] $($target.Path) (Status: $errCode)" -ForegroundColor $color

                        if ($LogPath) {
                            $entry = [PSCustomObject]@{
                                URL    = $target.Url
                                Status = $errCode
                                Length = 0
                            }
                            $entry | ConvertTo-Json -Compress | Add-Content -Path $LogPath
                        }
                    }
                }
            }

            if (((Get-Date) - $lastUpdate).TotalSeconds -ge $updateIntervalSec) {
                Show-Dashboard
                $lastUpdate = Get-Date
            }

            if ($delay -gt 0) {
                Start-Sleep -Milliseconds $delay
            }
        }
    }
}

# Final report
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Progress -Activity "Fuzzing..." -Completed
Write-Host "[*] Fuzzing complete." -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "       Scan session closed. Results summary:" -ForegroundColor DarkCyan
foreach ($code in ($found.Keys | Sort-Object)) {
    Write-Host "       HTTP ${code}: $($found[$code]) found"
}
Write-Host "       Total time: $($duration.ToString())"
if ($LogPath) {
    Write-Host "       Log saved to: $LogPath"
}
Write-Host "=============================================================" -ForegroundColor DarkCyan

<#

#>
