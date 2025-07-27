# Function to change the IP address of the network interface
function Set-StaticIP {
    param (
        [string]$interfaceName,
        [string]$newIP
    )
    try {
        # Check if the IP already exists on the interface
        $existingIP = Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv4 2>$null | Where-Object { $_.IPAddress -eq $newIP }

        if ($existingIP) {
            Write-Host "Warning: IP address $newIP already exists on interface $interfaceName." -ForegroundColor Yellow
        } else {
            if (-not $existingIP) {
                Write-Host "No existing IP address found on interface $interfaceName, setting new IP." -ForegroundColor Yellow
                # Set static IP without output if it doesn't exist
                New-NetIPAddress -InterfaceAlias $interfaceName -IPAddress $newIP -PrefixLength 24 | Out-Null
                Write-Host "Successfully set IP address $newIP on interface $interfaceName." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Error setting static IP: $_" -ForegroundColor Red
    }
}

# Function to revert back to DHCP
function Set-DHCP {
    param (
        [string]$interfaceName
    )
    # Check if interface exists
    $interface = Get-NetIPInterface -InterfaceAlias $interfaceName -ErrorAction SilentlyContinue
    if (-not $interface) {
        Write-Host "Interface $interfaceName not found. Skipping DHCP revert." -ForegroundColor Red
        return
    }

    # Set to DHCP without output
    Set-NetIPInterface -InterfaceAlias $interfaceName -Dhcp Enabled | Out-Null
    Write-Host "Reverted $interfaceName to DHCP." -ForegroundColor Cyan
}


# Function to retrieve the DHCP-assigned IP
function Get-DHCPIP {
    param (
        [string]$interfaceName
    )
    try {
        $dhcpIP = (Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv4 |
                   Where-Object { $_.PrefixOrigin -eq 'Dhcp' }).IPAddress
        return $dhcpIP
    } catch {
        Write-Host "Error retrieving DHCP IP: $_" -ForegroundColor Red
        return $null
    }
}


# Paste your 5-column data here (Tab-separated columns: WiFiName, Building, Floor, Side, RouterIP)
# Example line: MainRouter    MainBuilding    1    Left    192.168.1.1
$rawInput = @"
MainRouter	MainBuilding	1	Left	192.168.1.1
test	buildingname	4	Right	192.168.100.1
"@

# Network interface name (adjust if needed)
$interfaceName = "Wi-Fi"

# Parse the raw input into objects
$routers = @()
foreach ($line in $rawInput -split "`n") {
    if ($line.Trim() -eq "") { continue }

    # Split columns by tab or multiple spaces
    $columns = $line -split "`t"

    if ($columns.Count -lt 5) {
        Write-Host "Skipping malformed line: $line" -ForegroundColor Red
        continue
    }

    $wifiName = $columns[0].Trim()
    $building = $columns[1].Trim()
    $floor = $columns[2].Trim()
    $side = $columns[3].Trim()
    $routerIP = $columns[4].Trim()

    # Compose descriptive name
    $descriptiveName = "$wifiName - $building Floor $floor $side"

    # Compute local IP by taking routerIP and replacing last octet with 5
    $ipParts = $routerIP.Split(".")
    if ($ipParts.Count -ne 4) {
        Write-Host "Invalid Router IP format for ${descriptiveName}: $routerIP" -ForegroundColor Red
        continue
    }
    $localIP = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).5"

    # Build router object
    $routers += [PSCustomObject]@{
        DescriptiveName = $descriptiveName
        RouterIP       = $routerIP
        LocalIP        = $localIP
        IsMainRouter   = $wifiName -eq "MainRouter"  # Adjust if you want to detect main differently
    }
}

# Loop through each router and perform operations
foreach ($router in $routers) {
    $routerIP = $router.RouterIP
    $localIP = $router.LocalIP
    $descriptiveName = $router.DescriptiveName
    $isMain = $router.IsMainRouter

    if (![string]::IsNullOrEmpty($routerIP)) {
        if ($isMain) {
            # For Main router, get DHCP IP
            $dhcpIP = Get-DHCPIP -interfaceName $interfaceName
            if ($dhcpIP) {
                Write-Host "Obtained DHCP IP for this device: $dhcpIP (via Main router's DHCP)"
            } else {
                Write-Host "Could not retrieve DHCP IP for this device." -ForegroundColor Red
                continue
            }
        } else {
            # Set static IP to the computed local IP
            Set-StaticIP -interfaceName $interfaceName -newIP $localIP
            Start-Sleep -Seconds 5  # Wait for IP change to take effect
        }

        # Ping the router using Test-Connection and fallback to ping.exe
        try {
            Write-Host "Attempting to ping $descriptiveName at IP: $routerIP" -ForegroundColor Yellow
            $pingResult = Test-Connection -ComputerName $routerIP -Count 4 -Quiet

            if ($pingResult -eq $True) {
                Write-Host "$descriptiveName is reachable." -ForegroundColor Green
            } else {
                Write-Host "$descriptiveName is NOT reachable using Test-Connection, trying ping.exe." -ForegroundColor Red
                $pingExecResult = ping $routerIP

                if ($pingExecResult.Status -eq "Success") {
                    Write-Host "$descriptiveName is reachable with ping.exe." -ForegroundColor Green
                } else {
                    Write-Host "$descriptiveName is NOT reachable." -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Error during ping: $_" -ForegroundColor Red
        }

        # Revert back to DHCP if not the Main router
        if (-not $isMain) {
            Set-DHCP -interfaceName $interfaceName
            Start-Sleep -Seconds 5  # Wait for DHCP change to take effect
        }
    } else {
        Write-Host "No router IP defined for $descriptiveName." -ForegroundColor Red
    }
}
