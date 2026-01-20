$inputFile  = "ips.txt"
$outputFile = "results.txt"

# Clear old results
if (Test-Path $outputFile) {
    Clear-Content $outputFile
}

# Regex to match IPv4 address
$ipRegex = '\b\d{1,3}(\.\d{1,3}){3}\b'

foreach ($line in Get-Content $inputFile) {

    if ($line -match $ipRegex) {
        $ip = $matches[0]

        "====================================" | Out-File $outputFile -Append
        "Pinging $ip"                          | Out-File $outputFile -Append
        "Source line: $line"                  | Out-File $outputFile -Append
        "====================================" | Out-File $outputFile -Append
        ""                                     | Out-File $outputFile -Append

        ping $ip -n 4 | Out-File $outputFile -Append

        "" | Out-File $outputFile -Append
    }
}
