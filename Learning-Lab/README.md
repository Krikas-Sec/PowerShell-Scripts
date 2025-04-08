# Learning-Labs

This folder contains PowerShell scripts designed to support experimentation, testing, and learning. These tools are ideal for users who are exploring PowerShell scripting, penetration testing methodologies, or integrating external tools with PowerShell environments.

## Included Scripts

### `whatweb.ps1`
A PowerShell wrapper for the Ruby-based tool [WhatWeb](https://github.com/urbanadventurer/WhatWeb), used for identifying websites and fingerprinting technologies.

#### Usage
```powershell
# Basic example
./whatweb.ps1 https://example.com

# Pass any additional arguments supported by WhatWeb
./whatweb.ps1 -v https://example.com --color
```

#### Script Details
```powershell
param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$whatwebPath = "C:\Tools\WhatWeb\whatweb"

ruby $whatwebPath @Args
```

Make sure Ruby is installed and `whatweb` is cloned or downloaded to the specified path.

## Coming Soon
More scripts will be added to help you:
- Explore PowerShell scripting features
- Interact with third-party tools and APIs
- Build your own penetration testing lab environments

---

> **Note:** These scripts are for educational use. Be sure to only run tests on systems you own or have explicit permission to test.

---

Happy Hacking!

— The Krikas-Sec