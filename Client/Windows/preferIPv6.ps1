#Requires -RunAsAdministrator
#Applies registry key to prefer IPv4 over IPv6: https://docs.microsoft.com/en-US/troubleshoot/windows-server/networking/configure-ipv6-in-windows#use-registry-key-to-configure-ipv6
#
#Can be ran as a one-liner with the below command in powershell ran as administrator:
#$preferIPv4 = Invoke-WebRequest https://raw.githubusercontent.com/Twingate-Labs/tg-scripts/main/Client/Windows/preferIPv4.ps1; Invoke-Expression $($preferIPv4.Content)

function Set-PreferIPv6 () {
    try {
      if ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' | Select-Object -ExpandProperty 'DisabledComponents' -ErrorAction SilentlyContinue) -eq 0) {
          Write-Host "IPv6 is already preferred over IPv4. No further actions necessary." -ForegroundColor Green
      }
      elseif (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' | Select-Object -ExpandProperty 'DisabledComponents' -ErrorAction SilentlyContinue) {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x00 -ErrorAction Stop
        Write-Host "Setting IPv6 preference over IPv4."  -ForegroundColor Green
        Write-Host "Reboot required for changes to take effect." -ForegroundColor Red
      }
      else {
        try {
          New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x00 -PropertyType "DWord" -ErrorAction Stop
          Write-Host "Setting IPv6 preference over IPv4." -ForegroundColor Green
          Write-Host "Reboot required for changes to take effect." -ForegroundColor Red
        }
        catch {
            if ($($PSItem.ToString()) -eq "Requested registry access is not allowed.") {
                Write-Output "Error: $($PSItem.ToString()) Powershell must be ran as administrator to run this script."
              } 
              else {
                Write-Output "Error: $($PSItem.ToString())"
              }
        }
      }
    }
    catch {
      if ($($PSItem.ToString()) -eq "Requested registry access is not allowed.") {
        Write-Output "Error: $($PSItem.ToString()) Powershell must be ran as administrator to run this script."  
      } 
      else {
        Write-Output "Error: $($PSItem.ToString())"
      }
    }
}
Set-PreferIPv6
