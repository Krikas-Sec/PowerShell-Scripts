<#
.SYNOPSIS
    PowerShell-based Gobuster-style fuzzing tool for discovering hidden directories and files.

.DESCRIPTION
    Scans a target URL using a wordlist to identify accessible and forbidden paths.
    Supports optional file extensions, rate limiting, status code filtering, and logging.

.PARAMETER Url
    The base URL to fuzz (e.g., https://example.com)

.PARAMETER Wordlist
    Path to the wordlist file used for fuzzing

.PARAMETER RateLimit
    Requests per second (default: 5)

.PARAMETER ShowCodes
    HTTP status codes to show (default: 200,403)

.PARAMETER LogPath
    Optional path to save matching results (full URLs)

.PARAMETER Extensions
    Optional file extensions to append to each word (e.g., .php, .html)
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [string]$Wordlist,

    [double]$RateLimit = 5,

    [int[]]$ShowCodes = @(200, 403),

    [string]$LogPath,

    [string[]]$Extensions
)

# Load wordlist
$words = Get-Content -Path $Wordlist
$totalWords = $words.Count
$totalRequests = $totalWords * (1 + ($Extensions.Count))
$count = 0
$found = @{}
$results = @()

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
    Write-Host " Target              : $Url"
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
foreach ($word in $words) {
    $targets = @([PSCustomObject]@{ Url = "$Url/$word"; Path = "/$word" })
    if ($Extensions) {
        $targets += $Extensions | ForEach-Object {
            [PSCustomObject]@{ Url = "$Url/$word$_"; Path = "/$word$_" }
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