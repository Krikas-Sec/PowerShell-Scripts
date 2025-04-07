<#
.SYNOPSIS
    Generates a styled HTML recon report including:
    - Live subdomains
    - Unreachable subdomains
    - HTTP response fingerprinting
    - DNS resolution results

.PARAMETER FingerprintPath
    Path to the fingerprints.json file.

.PARAMETER LivePath
    Path to the live_domains.txt file.

.PARAMETER UnreachablePath
    Path to the unreachable_domains.txt file.

.PARAMETER DnsPath
    Path to the dns_records.json file.

.PARAMETER Output
    Path to output HTML file (e.g., report.html).
#>


param (
    [Parameter(Mandatory = $true)]
    [string]$FingerprintPath,

    [Parameter(Mandatory = $true)]
    [string]$LivePath,

    [Parameter(Mandatory = $true)]
    [string]$UnreachablePath,

    [Parameter(Mandatory = $true)]
    [string]$DnsPath,

    [string]$Output = "report.html"
)


# Read data
$fingerprints = Get-Content $FingerprintPath -Raw | ConvertFrom-Json
$live = Get-Content $LivePath
$unreachable = Get-Content $UnreachablePath

# Build HTML
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Recon Report</title>
    <style>
    body {
        background-color: #1e1e1e;
        color: #d4d4d4;
        font-family: Consolas, monospace;
        margin: 20px;
    }

    h1, h2 {
        color: #66d9ef;
        border-bottom: 1px solid #333;
        padding-bottom: 5px;
    }

    table {
        border-collapse: collapse;
        width: 100%;
        margin-bottom: 40px;
    }

    th, td {
        border: 1px solid #333;
        padding: 8px;
    }

    th {
        background-color: #2d2d2d;
        color: #dcdcaa;
    }

    tr.status200 {
        background-color: #264f26;
    }

    tr:hover {
        background-color: #333;
    }

    ul {
        list-style: square;
        padding-left: 20px;
    }

    li.code {
        color: #9cdcfe;
    }

    .code {
        font-family: Consolas, monospace;
        font-size: 13px;
        color: #c586c0;
    }
        .tabs {
    margin-bottom: 20px;
}
.tab-button {
    padding: 10px 20px;
    margin-right: 5px;
    background-color: #333;
    border: 1px solid #444;
    color: #ccc;
    cursor: pointer;
}
.tab-button.active {
    background-color: #222;
    color: #66d9ef;
}
.tab-content {
    display: none;
}
.tab-content.active {
    display: block;
}

</style>
<script>
    // Sortable table columns
    document.addEventListener('DOMContentLoaded', () => {
        const getCellValue = (tr, idx) => tr.children[idx].innerText || tr.children[idx].textContent;

        const comparer = (idx, asc) => (a, b) => ((v1, v2) =>
            v1 !== '' && v2 !== '' && !isNaN(v1) && !isNaN(v2)
                ? v1 - v2
                : v1.toString().localeCompare(v2)
            )(getCellValue(asc ? a : b, idx), getCellValue(asc ? b : a, idx));

        document.querySelectorAll('th').forEach(th => th.addEventListener('click', (() => {
            const table = th.closest('table');
            Array.from(table.querySelectorAll('tr:nth-child(n+2)'))
                .sort(comparer(Array.from(th.parentNode.children).indexOf(th), this.asc = !this.asc))
                .forEach(tr => table.appendChild(tr));
        })));
    });

    // Quick filter
    function filterTable() {
        const input = document.getElementById("searchInput");
        const filter = input.value.toLowerCase();
        const rows = document.querySelectorAll("tbody tr");
        rows.forEach(row => {
            const text = row.innerText.toLowerCase();
            row.style.display = text.includes(filter) ? "" : "none";
        });
    }
</script>
<script>
function showTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.classList.remove('active');
    });
    document.getElementById(tabId).classList.add('active');
    event.target.classList.add('active');
}
</script>

</head>
<body>
    <h1>Bug Bounty Recon Report</h1>

    <div class="tabs">
        <button class="tab-button active" onclick="showTab('live')">Live Domains</button>
        <button class="tab-button" onclick="showTab('unreachable')">Unreachable Domains</button>
        <button class="tab-button" onclick="showTab('fingerprints')">Fingerprints</button>
        <button class="tab-button" onclick="showTab('dns')">DNS Records</button>
    </div>

    <div id="live" class="tab-content active">
        <h2>Live Domains</h2>
        <ul>
    <ul>
"@

foreach ($url in $live) {
    $html += "        <li class='code'>$url</li>`n"
}

$html += @"
    </ul>
    </div>

    <div id="unreachable" class="tab-content">
    <h2>Unreachable Domains</h2>
    <ul>
"@

foreach ($url in $unreachable) {
    $html += "        <li class='code'>$url</li>`n"
}

$html += @"
    </ul>
    </div>

    <div id="fingerprints" class="tab-content">
    <h2>Fingerprint Details</h2>
    <input type="text" id="searchInput" onkeyup="filterTable()" placeholder="Filter table..." style="padding: 8px; width: 100%; margin-bottom: 10px; background-color: #333; color: #fff; border: 1px solid #444;">
    <table>
        <thead>
            <tr>
                <th>URL</th>
                <th>Status</th>
                <th>Server</th>
                <th>X-Powered-By</th>
                <th>Content-Type</th>
                <th>Content-Length</th>
                <th>Set-Cookie</th>
                <th>Timestamp</th>
            </tr>
        </thead>
        <tbody>
"@

foreach ($fp in $fingerprints) {
    $rowClass = if ($fp.Status -eq 200) { "status200" } else { "" }
    $html += "            <tr class='$rowClass'>" + `
        "<td class='code'>$($fp.URL)</td>" + `
        "<td>$($fp.Status)</td>" + `
        "<td>$($fp.Server)</td>" + `
        "<td>$($fp.XPoweredBy)</td>" + `
        "<td>$($fp.ContentType)</td>" + `
        "<td>$($fp.ContentLength)</td>" + `
        "<td><div class='code'>$($fp.SetCookie)</div></td>" + `
        "<td>$($fp.Timestamp)</td>" + `
        "</tr>`n"
}


$html += @"
        </tbody>
    </table>
    </div>
    <div id="dns" class="tab-content">
    <h2>DNS Records</h2>
    <table>
        <thead>
            <tr>
                <th>Domain</th>
                <th>Type</th>
                <th>TTL</th>
                <th>Value (IP)</th>
                <th>Timestamp</th>
            </tr>
        </thead>
        <tbody>
"@
# Load and render DNS records
$dnsRecords = @()
if (Test-Path "dns_records.json") {
    $dnsRecords = Get-Content $DnsPath -Raw | ConvertFrom-Json
}

foreach ($entry in $dnsRecords) {
    $domain = $entry.Domain
    $timestamp = $entry.Timestamp
    foreach ($record in $entry.Records) {
        $value = $record.IPAddress
        if (-not $value) { $value = $record.NameHost }
        if (-not $value) { $value = $record.NameExchange }
        if (-not $value) { $value = "-" }

        $html += "            <tr>" + `
            "<td class='code'>$domain</td>" + `
            "<td>$($record.Type)</td>" + `
            "<td>$($record.TTL)</td>" + `
            "<td class='code'>$value</td>" + `
            "<td>$timestamp</td>" + `
            "</tr>`n"
    }
}

$html += @"
        </tbody>
    </table>
</div>
</body>
</html>
"@

# Save report
Set-Content -Path $Output -Value $html -Encoding UTF8
Write-Host "[*] HTML report generated: $Output" -ForegroundColor Cyan
# Open in default browser
Start-Process $Output