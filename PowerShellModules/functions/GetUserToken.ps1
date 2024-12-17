function Get-UserToken {
    param (
        [string]$tenantId,  # The ID of the tenant the user belongs to
        [string]$clientId,  # ClientID of MSSPrinkler, this is preset
        [string]$userKey,   # Username to retrieve tokens for
        [string]$passValue, # Password for user
        [string]$scope = "openid profile email offline_access",  # Default scope
        [string]$tokenFile = 'tokenCache.json'  # File to save refresh token
    )

    # Vars to store tokens
    $folderPath = ".\jsonModules"
    $fullTokenPath = Join-Path -Path $folderPath -ChildPath $tokenFile
    $url = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Check if the token file exists and load existing tokens
    $tokens = @{}
    if (Test-Path -Path $fullTokenPath) {
        $tokens = Get-Content -Path $fullTokenPath | ConvertFrom-Json
        Write-Host "Loading existing tokens from $tokenFile..."
    } else {
        Write-Host "Token file does not exist. Initializing a new one..."
        $tokens = @{}
    }

    # Check if the user exists in the token file
    if (-not ($tokens.$userKey)) {
        $tokens.$userKey = @{ refresh_token = $null; access_token = $null; id_token = $null }
    }

    # Request new tokens
    $body = @{
        grant_type = "password"
        client_id  = $clientId
        scope      = $scope
        username   = $userKey
        password   = $passValue
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body

        if ($response.access_token -and $response.refresh_token) {
            # Update the user's tokens
            $tokens.$userKey.access_token = $response.access_token
            $tokens.$userKey.refresh_token = $response.refresh_token
            $tokens.$userKey.id_token = $response.id_token  # Optional

            # Save updated tokens
            $tokens | ConvertTo-Json -Depth 10 | Set-Content -Path $fullTokenPath
            Write-Host "Updated access and refresh tokens, saved to $tokenFile."

        } else {
            Write-Output "Tokens received for $($userKey), but refresh token may be missing:"
            $response | Format-List
        }
    } catch {
        Write-Output "Error encountered for $($userKey):"
        Write-Output $_.Exception.Message
    }
}
