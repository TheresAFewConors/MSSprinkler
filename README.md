




<div align="center">

  <a href="">[![Made with - PowerShell](https://img.shields.io/badge/Made_with-PowerShell-blue)](https://github.com/theresafewconors/mssprinkler)</a>
  <a href="">[![License - MIT](https://img.shields.io/badge/License-MIT-yellow)](https://github.com/theresafewconors/mssprinkler)</a>
  <a href="">[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Ftheresafewconors%2Fmssprinkler&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)</a>
  <a href="">[![Current Version](https://img.shields.io/badge/Current_Version-0.12-lightblue)](https://github.com/theresafewconors/mssprinkler)</a>

</div>


<p align="center"><a href="https://www.cybermaxx.com/?utm_source=github&utm_medium=githublink&utm_campaign=mssprinkler&utm_id=github"><img src="images/cybermaxx_logo.png"></img></a></p>
MSSprinkler is sponsored by CyberMaxx.



# Overview

MSSprinkler is a password spraying utility for organizations to test their M365 accounts from an external perspective. It employs a 'low-and-slow' approach to avoid locking out accounts, and provides verbose information related to accounts and tenant information. 

## Contents
- [Description](#description)
- [Current Feature](#current-features)
- [Installation](#install-and-usage)
- [Help](#help)
- [Disclaimer](#disclaimer)

## Description
MSSprinkler is written in PowerShell and can be imported directly as a module. It has no other dependencies. MSSprinkler relies on the verbose error messaging provided by Microsoft to identify additional information beyond standard password spray success or failed authentication attempts, which allows for the gathering of additional information related to the user account. MSSprinkler also allows for a configurable threshold to prevent locking out accounts by mistake. By default, this is set to 8 (n-2 under Microsoft's default) however this can be adjusted based on the organizations lockout policy. Additionally, successful sign-in to an account with MFA enabled will not produce an MFA push to the user, allowing for covert information gathering.

![](/images/Animation.gif)

## Current Features
- Automatically spray a list of M365 accounts with a password list.
- Low-and-slow approach to avoid locking out accounts.
- Smart detect accounts that do not exist or are locked out, skipping over these to reduce unnecessary traffic and speed up testing.
- Ability to override the default threshold to better match the organizations policy, if required.
- Verbose output, revealing additional information about accounts:
  - Detect if an account is locked out.
  - Detect if a user exists in the tenant or not.
  - Detect if MFA is in use for a given user without triggering the MFA push.
- Output and store results into a file 	

## Install and Usage
```PowerShell
# Import the module
Import-Module MSSprinkler.ps1

# Use the module
Invoke-MSSprinkler 

# EXAMPLE USAGE
# Spray using a provided userlist and password list, default URL and threshold
Invoke-MSSprinkler -user userlist.txt -pass passwordlist.txt

# Spray using a provided userlist and password list, increase threshold to 12 attempts per min and output results to output.csv
Invoke-MSSprinkler -user userlist.txt -pass passwordlist.txt -threshold 12 -output .\output.csv
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

Timestamps in the output file are in UTC timezone with the applicable offset for the local user, eg for 2:11pm local time:
```
09/17/2024 13:11 +01
```

## Reporting An Issue

If you encounter an issue with an unhandled error MSSprinkler will provide you with the error code. Please open an issue and reference this error code so that it can be added and handled correctly.

## Disclaimer
This tool is to be used only against accounts that you either own or have permission to test during legitimate penetration tests or internal assessments. The author accepts no liability for actions taken by its users.  
