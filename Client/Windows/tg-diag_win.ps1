param(
    [parameter(Mandatory,ValueFromPipeline)][string[]]$tenant
)
###Check for EDR/AV installed and state
####Script sourced from: https://www.nextofwindows.com/how-to-tell-what-antivirus-software-installed-on-a-remote-windows-computer
# define bit flags
 function Get-AVStatus {
[Flags()] enum ProductState 
{
      Off         = 0x0000
      On          = 0x1000
      Snoozed     = 0x2000
      Expired     = 0x3000
}
 
[Flags()] enum SignatureStatus
{
      UpToDate     = 0x00
      OutOfDate    = 0x10
}
 
[Flags()] enum ProductOwner
{
      NonMs        = 0x000
      Windows      = 0x100
}
 
# define bit masks
 
[Flags()] enum ProductFlags
{
      SignatureStatus = 0x00F0
      ProductOwner    = 0x0F00
      ProductState    = 0xF000
}
# get bits
$AV = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct
    [UInt32]$state = $AV.productState
 
    # decode bit flags by masking the relevant bits, then converting
    [PSCustomObject]@{
          ProductName = $AV.DisplayName
          ProductState = [tripeltProductState]($state -band [ProductFlags]::ProductState)
          SignatureStatus = [SignatureStatus]($state -band [ProductFlags]::SignatureStatus)
          Owner = [ProductOwner]($state -band [ProductFlags]::ProductOwner)
    } 
}

###detect unsupported services
function Get-KnownIncompatibilities {
    Get-Service * | Select-String
}

#output what TLS items are enabled, otherwise systemdefault will be returned
function Get-SecurityInfo {
    try {
        if ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' | Select-Object -ExpandPropert 'DisabledByDefault') -eq 0) {
            Write-Host "SCHANNEL TLS 1.2 Client is enabled as required."  -ForegroundColor Green
        }
        else {
            Write-Host "SCHANNEL TLS 1.2 Client is not enabled as required. Reference https://docs.twingate.com/docs/faq#what-protocol-does-twingate-use-for-encrypted-data-transport"  -ForegroundColor Red
        }
    }
    catch {
            Write-Host "Issue verifying HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\DisabledByDefault is set to 0 by default."  -ForegroundColor Red
        }
    #Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework might need to check something here
    #[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319]
        #"SystemDefaultTlsVersions"=dword:00000001
        #"SchUseStrongCrypto"=dword:00000001
    
    $SecProto = [Net.ServicePointManager]::SecurityProtocol
    try {
        If ( $SecProto -ieq "Tls12" -or $SecProto -ieq "SystemDefault") {
            Write-Host "TLS1.2 is available as required." -ForegroundColor Green
        }
        Else {
            Write-Host "Command '[Net.ServicePointManager]::SecurityProtocol' returned TLS1.2 is not available for use as required. Available security protocols: $SecProto" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Unexpected Error" -ForegroundColor Red
    }
}

###Obtain tenant from conf

###test connectivity to twingate networks
function Test-OutConnectivity {
    Write-Output "Testing connection via TLS 1.2:"
    [Net.ServicePointManager]::SecurityProtocol = "Tls12"
    $testTenant = Test-NetConnection -ComputerName "$tenant.twingate.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    $testRelays = Test-NetConnection -ComputerName "relays.twingate.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    try {
      if ($testTenant) {
        Write-Host "Test to $tenant.twingate.com:443 successful" -ForegroundColor Green 
      }
      Else {
        Write-Host "Test to $tenant.twingate.com:443 unsuccessful" -ForegroundColor Red
      }
    }
    Catch {
        Write-Host "Unable to test connectivity $tenant.twingate.com:443" -ForegroundColor Red
    }
    try {
        if ($testRelays) {
          Write-Host "Test to relays.twingate.com:443 successful" -ForegroundColor Green 
        }
        Else {
          Write-Host "Test to relays.twingate.com:443 unsuccessful" -ForegroundColor Red
        }
      }
      Catch {
          Write-Host "Unable to test connectivity relays.twingate.com:443" -ForegroundColor Red
      }
    }


###TwingateService check and repair
function Get-TwingateServiceStatus {
If (Get-Service Twingate.service -ErrorAction SilentlyContinue) {
    If ((Get-Service Twingate.service).Status -eq 'Running') {
        Write-Host "Twingate.Service running"
    }
    Else
    {
        Write-Host "Twingate.service found, but it is not running."
        ### Prompt to start y/n
        #Start-Service Twingate.service

    }
    }
Else{
    Write-Host "Twingate.service not found"
}
}
###Check tap status and availability
function Get-TwingateTAPAdapterStatus {
  If (Get-NetAdapter -InterfaceDescription "Twingate TAP-Windows Adapter V9" -ErrorAction SilentlyContinue) {
      If ((Get-NetAdapter -InterfaceDescription "Twingate TAP-Windows Adapter V9").Status -eq 'Up') {
        Write-Host "Twingate TAP Adapter is connected." -ForegroundColor Green
      }
      elseif ((Get-NetAdapter -InterfaceDescription "Twingate TAP-Windows Adapter V9").Status -eq 'Disconnected') {
            Write-Host "Twingate TAP Tunnel is disconnected. Is Twingate connected?" -ForegroundColor Yellow
      }
      elseif ((Get-NetAdapter -InterfaceDescription "Twingate TAP-Windows Adapter V9").Status -eq 'Disabled') {
                Write-Host "Twingate TAP Tunnel is disabled, check if adapter is enabled in Network Connections." -ForegroundColor Red
      }
      Else { Write-Host "Twingate TAP Adapter status is not normal. Further investigation needed." -ForegroundColor Red }
  }
  Else { Write-Host "Twingate TAP Adapter is not found. Please verify Twingate is installed." -ForegroundColor Red }
}

function Get-IntStats {
    Write-Host "Interfaces..." -ForegroundColor Gray
    Get-NetIPInterface * | Sort-Object -Property InterfaceMetric | ft InterfaceAlias,AutomaticMetric,InterfaceMetric,ConnectionState
    Write-Host "Twingate Interface details..." -ForegroundColor Gray
    Get-NetConnectionProfile -InterfaceAlias "Twingate" | ft InterfaceAlias,IPv4Connectivity,IPv6Connectivity,NetworkCategory
}

###Add Windows Firewall exceptions
#--toggle flag to perform
function Set-TwingateWindowsFirewallRules {
  Write-Host "Adding exceptions for Twingate in Windows Firewall for outbound connectivity"
  New-NetFirewallRule -Program "C:\Program Files (x86)\Twingate\Twingate.exe" -Action Allow -Direction Outbound -Profile Domain, Private -DisplayName "Allow TwingateApp" -Description "Allow TwingateApp"
  New-NetFirewallRule -Program "C:\Program Files (x86)\Twingate\tap-windows-twingate-*.exe" -Action Allow -Direction Outbound -Profile Domain, Private -DisplayName "Allow TwingateTap" -Description "Allow TwingateTap" ##need to dynamically find version
  New-NetFirewallRule -Program "C:\Program Files (x86)\Twingate\Twingate.Service.exe" -Action Allow -Direction Outbound -Profile Domain, Private -DisplayName "Allow TwingateService" -Description "Allow TwingateService"
  New-NetFirewallRule -Program "C:\Program Files (x86)\Twingate\Twingate.Service.exe" -Action Allow -Direction Outbound -Profile Domain, Private -DisplayName "Allow TwingateService" -Description "Allow TwingateService"
}

###Add Windows Defender exclusions
#-- toggle flag to perform

###Log scraper
#tbd

Get-SecurityInfo
Test-OutConnectivity
Get-TwingateServiceStatus
Get-TwingateTapAdapterStatus
Get-IntStats
