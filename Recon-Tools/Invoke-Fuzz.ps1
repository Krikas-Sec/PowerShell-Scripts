<#
.SYNOPSIS
    PowerShell-based Gobuster-style fuzzing for hidden files and directories.

.PARAMETER Url
    The base URL to fuzz (e.g., https://example.com)

.PARAMETER Wordlist
    Path to a wordlist file.

.PARAMETER RateLimit
    Requests per second (default: 5)

.PARAMETER ShowCodes
    HTTP status codes to show (default: 200,403)

.PARAMETER LogPath
    Optional path to save matching results (full URLs). If not set, results will not be logged.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [string]$Wordlist,

    [double]$RateLimit = 5,

    [int[]]$ShowCodes = @(200, 403),

    [string]$LogPath
)

# Load the wordlist
$words = Get-Content -Path $Wordlist
$total = $words.Count
$count = 0
$found = @{}
foreach ($code in $ShowCodes) { $found[$code] = 0 }

# Track time
$startTime = Get-Date

# Determine rate limiting delay
$delay = if ($RateLimit -le 0) { 0 } else { [math]::Ceiling(1000 / $RateLimit) }

# Prepare log file if specified
if ($LogPath) {
    if (Test-Path $LogPath) {
        Clear-Content $LogPath
    } else {
        New-Item -ItemType File -Path $LogPath -Force | Out-Null
    }
}

# Cool scanning banner
Write-Host @"
=========================================================
   ____   ____   ____   ____   ____   ____   ____   ____  
  / ___| / ___| / ___| / ___| / ___| / ___| / ___| / ___| 
 | |    | |    | |    | |    | |    | |    | |    | |     
 | |___ | |___ | |___ | |___ | |___ | |___ | |___ | |___  
  \____| \____| \____| \____| \____| \____| \____| \____| 
  
             ONGOING SCAN - STAY SHARP!
                     PowerHack
=========================================================
"@ -ForegroundColor Cyan

# Initial info
Write-Host "[*] Target: $Url"
Write-Host "[*] Wordlist: $Wordlist - $total entries"
Write-Host "====================================================="

# Move progress bar output area down
Write-Progress -Activity "Fuzzing..." -Status "Initializing..." -PercentComplete 0

# Fuzz each word
foreach ($word in $words) {
    $count++
    $path = "/$word"
    $fullUrl = "$Url$path"

    try {
        $response = Invoke-WebRequest -Uri $fullUrl -UseBasicParsing -ErrorAction Stop
        $status = $response.StatusCode
        $size = $response.RawContentLength

        if ($ShowCodes -contains $status) {
            $found[$status]++
            Write-Host "[$count/$total] $path (Status: $status, Size: $size)" -ForegroundColor Green
            if ($LogPath) {
                $entry = [PSCustomObject]@{
                    URL    = $fullUrl
                    Status = $status
                    Length = $size
                }
                $entry | ConvertTo-Json -Compress | Add-Content -Path $LogPath
            }
        }
    } catch {
        if ($_.Exception.Response -and ($ShowCodes -contains $_.Exception.Response.StatusCode)) {
            $errCode = $_.Exception.Response.StatusCode
            $found[$errCode]++
            Write-Host "[$count/$total] $path (Status: $errCode)" -ForegroundColor Yellow
            if ($LogPath) {
                $entry = [PSCustomObject]@{
                    URL    = $fullUrl
                    Status = $errCode
                    Length = 0
                }
                $entry | ConvertTo-Json -Compress | Add-Content -Path $LogPath
            }
        }
    }

    Write-Progress -Activity "Fuzzing..." -Status "Progress" -PercentComplete (($count / $total) * 100)

    if ($delay -gt 0) {
        Start-Sleep -Milliseconds $delay
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Progress -Activity "Fuzzing..." -Completed
Write-Host ""
Write-Host "[*] Fuzzing complete." -ForegroundColor Cyan

# Detailed footer
Write-Host @"
=========================================================
       Scan session closed. Results summary:
"@ -ForegroundColor DarkCyan
foreach ($code in $ShowCodes) {
    Write-Host "       HTTP ${code}: $($found[$code]) found"
}
Write-Host "       Total time: $($duration.ToString())"
if ($LogPath) {
    Write-Host "       Log saved to: $LogPath"
}
Write-Host "=========================================================" -ForegroundColor DarkCyan
