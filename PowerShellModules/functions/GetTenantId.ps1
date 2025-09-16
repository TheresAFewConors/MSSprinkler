function Get-TenantId {
    param (
        [string[]]$users
    )

    $cacheFile = ".\jsonModules\domainCache.json"
    $validatedUsersFile = ".\validated_users.txt"

    if (-not $global:domainCache) {
        if (Test-Path $cacheFile) {
            $global:domainCache = Get-Content $cacheFile | ConvertFrom-Json
        } else {
            $global:domainCache = @{}
        }
    }

    $alreadyValidated = @()
    if (Test-Path $validatedUsersFile) {
        $alreadyValidated = Get-Content $validatedUsersFile
    }

    $newUsers = $users | Where-Object { $_ -notin $alreadyValidated }

    $uniqueDomains = $newUsers | ForEach-Object {
        ($_ -split '@')[1]
    } | Sort-Object -Unique

    $validDomains = @{}

    foreach ($domain in $uniqueDomains) {
        if ($global:domainCache.ContainsKey($domain)) {
            $validDomains[$domain] = $global:domainCache[$domain]
            continue
        }

        $tenantId = $null
        $tenantName = $domain.Split('.')[0] + ".onmicrosoft.com"
        $metadataUrl = "https://login.microsoftonline.com/$domain/.well-known/openid-configuration"

        try {
            $response = Invoke-RestMethod -Uri $metadataUrl -TimeoutSec 10 -ErrorAction Stop
            if ($response.issuer) {
                $tenantId = ($response.issuer -split '/')[3]
                Write-Host "Caching domain $domain with Tenant ID: $tenantId."
                $global:domainCache[$domain] = @{
                    "tenant ID"   = $tenantId
                    "tenant name" = $tenantName
                }
                $validDomains[$domain] = $global:domainCache[$domain]
            }
        } catch {
            Write-Warning "Failed to retrieve metadata for $domain. Skipping domain and its users."
        }
    }

    $validUsers = $newUsers | Where-Object {
        $domain = ($_ -split '@')[1]
        $validDomains.ContainsKey($domain)
    }
    if ($validUsers.Count -gt 0) {
        Add-Content -Path $validatedUsersFile -Value $validUsers
    }

    $global:domainCache | ConvertTo-Json -Depth 10 | Out-File -FilePath $cacheFile -Force

    return $validDomains
}
