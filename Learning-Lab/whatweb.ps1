# whatweb.ps1
param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

# Correct path to the real script
$whatwebPath = "C:\Tools\WhatWeb\whatweb"

# Use ruby to run the actual WhatWeb script
ruby $whatwebPath @Args