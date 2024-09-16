# Overview

MSSprinkler is a password spraying utility for organizations to test their M365 accounts from an external perspective. It employs a 'low-and-slow' approach to avoid locking out accounts, and provides verbose information related to accounts and tenant information. 

## Contents
- [Description](#description)
- [Current Feature](#current-features)
- [Installation](#install-and-usage)
- [Help](#help)

## Description
MSSprinkler is written in PowerShell and can be imported directly as a module. It has no other dependencies. It relies on the verbose error messaging provided by Microsoft to identify additional information beyond standard password spray success or failed attempts. MSSprinkler also allows for a configurable threshold to prevent locking out accounts by mistake. By default, this is set to 8 (n-2 under Microsoft's default) however this can be adjusted based on the organizations lockout policy. Additionally, successful sign-in to an account with MFA enabled will not produce an MFA push to the user.  

## Current Features
- Automatically spray a list of M365 accounts with a password list
- Low-and-slow approach to avoid locking out accounts
- Smart detect accounts that do not exist or are locked out, skipping over these to reduce unnecessary traffic and speed up testing
- Ability to override the default threshold to 'go loud'
- Verbose output, revealing additional information about accounts
  - Detect if an account is locked out
  - Detect if a user exists in the tenant or not
  - Detect if MFA is in use for a given user without triggering the MFA push

## Install and Usage
```PowerShell
# Import the module
Import-Module MSSprinkler.ps1

# Spray using a provided userlist and password list, default URL and threshold
Invoke-MSSprinkler -user userlist.txt -pass passwordlist.txt

# Spray using a provided userlist and password list, increase threshold to 12 attempts on an account per min
Invoke-MSSprinkler -user userlist.txt -pass passwordlist.txt -threshold 12
```

## Help
The userlist file should contain a list of users in the format `users@tenant.com`, one per line. Example below:
```
user1@tenant.com
user2@tenant.com
...
user43@tenant.com
```

The password list should follow the same format. One password per line:
```
password1
password2
...
password10
```

Additional help can be viewed within the tool via PowerShells built-in module:
```PowerShell
Get-Help .\mssprinkler.ps1 -detailed
```
