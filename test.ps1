$baseUrl = "https://lab.temphack.org"
$wordlist = Get-Content "C:\Temp\wordlists\common.txt"

foreach ($word in $wordlist) {
    $url = "$baseUrl/$word"
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        Write-Host "[+] Found: $url ($($response.StatusCode))" -ForegroundColor Green
    } catch {
        # Optional: handle 403s or log others
        if ($_.Exception.Response.StatusCode -eq 403) {
            Write-Host "[*] Forbidden: $url" -ForegroundColor Yellow
        }
    }
    #Start-Sleep -Milliseconds 250  # Respect 5/sec
}
