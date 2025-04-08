# 🚁 Recon-Tools

This directory contains PowerShell scripts designed to assist in reconnaissance and subdomain analysis. These tools are useful for bug bounty hunters, penetration testers, and anyone working with domain and infrastructure mapping.

---

## 📜 Included Scripts

### 🔹 `Get-CertSubdomains.ps1`
Retrieves subdomains by querying the **Certificate Transparency logs** via `crt.sh`.

- **Input**: A root domain (e.g., `example.com`)
- **Output**: A list of discovered subdomains.
- **Usage**:
  ```powershell
  .\Get-CertSubdomains.ps1 -Domain "example.com" -Output "subdomains.txt"
  ```

---

### 🔹 `Test-LiveSubdomains.ps1`
Tests which subdomains are alive over HTTP/HTTPS, logs fingerprints and HTTP headers.

- **Input**: Subdomain list.
- **Output**:
  - `live_domains.txt`
  - `unreachable_domains.txt`
  - `fingerprints.json`
- **Usage**:
  ```powershell
  .\Test-LiveSubdomains.ps1 -Path "subdomains.txt" -File "live_domains.txt" -RateLimit 5
  ```

---

### 🔹 `Resolve-ValidSubdomains.ps1`
Checks DNS resolution of live domains using `Resolve-DnsName`, logs A/CNAME/MX records to JSON.

- **Input**: `live_domains.txt`
- **Output**: `dns_records.json`
- **Usage**:
  ```powershell
  .\Resolve-ValidSubdomains.ps1 -Path "live_domains.txt" -Output "dns_records.json" -RateLimit 5
  ```

---

### 🔹 `Invoke-Fuzz.ps1`
PowerShell-based **Gobuster-style** directory and file brute-forcing script using `Invoke-WebRequest`.

- **Input**:
  - `-Url`: Target base URL
  - `-Wordlist`: Path to wordlist
- **Optional Parameters**:
  - `-RateLimit`: Requests/sec (default 5)
  - `-ShowCodes`: Which HTTP status codes to report (default 200,403)
  - `-LogPath`: Save matching URLs and metadata to log file
- **Usage**:
  ```powershell
  .\Invoke-Fuzz.ps1 -Url "https://example.com" -Wordlist "wordlist.txt" -RateLimit 10 -LogPath "findings.txt"
  ```

---

### 🔹 `Generate-HTMLReport.ps1`
Generates a complete dark-themed recon HTML report from all above outputs. Includes sortable tables, filtering, and tabbed views.

- **Input**:
  - `fingerprints.json`
  - `live_domains.txt`
  - `unreachable_domains.txt`
  - `dns_records.json`
  - `findings.txt` (optional)
- **Output**: `report.html`
- **Usage**:
  ```powershell
  .\Generate-HTMLReport.ps1 -FingerprintPath fingerprints.json -LivePath live_domains.txt -UnreachablePath unreachable_domains.txt -DnsPath dns_records.json -FuzzingPath findings.txt -Output report.html
  ```

---

Stay sharp — automate your recon with **PowerShell & PowerHack** ✨

