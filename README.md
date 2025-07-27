Powershell script (made using ChatGPT) that pings routers on differents subnets to check connectivity by setting IP on their respective subnets.

The list of Router names, IPs can be copied from a spreadsheet simply into the script and the script parses from it the required information.

Steps to run the script:

1. Run PowerShell as Administrator
 
2. Check: Get-ExecutionPolicy, if Restricted allow by using command: Set-ExecutionPolicy RemoteSigned
  
3. Run command: cd "location-of-script"

4. Run command: ./script-name.ps1

Note: Internet availability will be effected during the operation of the script.
Note: If Internet doesn't work after running the script or after exiting before completion, make sure to set the IP for the interface to DHCP.
Note: Update proper IP addresses from excel, copy 4 columns from there and paste in the script

Suggested upgrade: Deploy on Raspberry pie to update when a router goes down.


Use the following PowerShell command to generate 18 Random 12-digit password for the monthly Access Point credentials' rotation.

1..18 | ForEach-Object {-join ((0..10) | Get-Random -Count 12)}


Ahmed AbdulKarim
ak.ahmed@live.com



