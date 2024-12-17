function Get-TenantId {
    param (
        [string[]]$users
    )

    # Initialize the domain cache if it doesn't exist yet
    if (-not $global:domainCache) {
        $global:domainCache = @{}
    }

    # Extract unique domains from the user list
    $uniqueDomains = $users | ForEach-Object {
        ($_ -split '@')[1]  # Extract the domain from the email
    } | Sort-Object -Unique

    # Hash table to track valid domains
    $validDomains = @{}

    # Check each unique domain
    foreach ($domain in $uniqueDomains) {
        # If the domain is already cached, skip the retrieval process
        if ($global:domainCache.ContainsKey($domain)) {
            Write-Host "Domain $domain already cached."
            $validDomains[$domain] = $global:domainCache[$domain]  # Add cached domain to valid list
            continue
        }

        # Initialize variables for tenant information
        $tenantId = $null
        $tenantName = $domain.Split('.')[0] + ".onmicrosoft.com"

        # Microsoft OpenID Configuration Endpoint to retrieve the Tenant ID
        $metadataUrl = "https://login.microsoftonline.com/$domain/.well-known/openid-configuration"
        $response = $null
        $ErrorActionPreference = 'silentlycontinue'

        try {
            $response = Invoke-RestMethod -Uri $metadataUrl -TimeoutSec 10 -ErrorAction Stop -ErrorVariable err
            $errString = $err | Out-String
        } catch {
            Write-Warning "Failed to retrieve metadata for $domain. Skipping domain and associated users."
            continue  # Skip to the next domain if the lookup fails
        }

        # Process the response if valid
        if ($response -and $response.issuer) {
            try {
                # Extract Tenant ID
                $tenantId = ($response.issuer -split '/')[3]
                Write-Host "Caching domain $domain with Tenant ID: $tenantId."
                $global:domainCache[$domain] = @{
                    "tenant ID" = $tenantId
                    "tenant name" = $tenantName
                }
                $validDomains[$domain] = $global:domainCache[$domain]  # Mark as valid
            } catch {
                Write-Warning "Failed to extract Tenant ID from issuer for $domain."
            }
        } else {
            Write-Warning "Invalid or missing tenant information for $domain. Skipping."
        }
    }

    # Filter users by valid domains
    $validUsers = $users | Where-Object {
        $domain = ($_ -split '@')[1]
        $validDomains.ContainsKey($domain)
    }

    # Export valid users to a text file without headers and quotes
    $validUsers | Out-File -FilePath ".\validated_users.txt" -Force

    # Return the final output with domains at the top level
    return $validDomains
}
