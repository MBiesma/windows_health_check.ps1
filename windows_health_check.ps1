<#
.SYNOPSIS
    Windows Server Health Check Script

.DESCRIPTION
    Voert een uitgebreide Windows Server Health Check uit en genereert een logbestand.
    De controle omvat systeemstatus, IP-configuratie, CPU-belasting, event logs,
    disk- en geheugeninformatie, services, updates, licenties, firewallstatus,
    geplande taken, VSS, en meer.

.VERSION
    1.2

.AUTHOR
    Mark Biesma

.LINK
    https://github.com/MBiesma/windows_health_check.ps1

.DATE
    2025-06-30

.NOTES
    De HTML-logbestanden worden automatisch aangemaakt in:
    C:\HealthCheck\<datum>_<hostname>.log

    Handig voor dagelijks, wekelijks of ad-hoc systeembeheer en audits.
#>

# =============================================
# Windows Server Health Check Script
# =============================================

$folderPath = "C:\HealthCheck"
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath | Out-Null
}

$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMddHHmm"
$logFile = Join-Path $folderPath "$timestamp`_$hostname.log"

function Add-Section {
    param ([string]$Title, [string]$Content)
    Add-Content -Path $logFile -Value "`n===== $Title ====="
    Add-Content -Path $logFile -Value $Content
}

Add-Content -Path $logFile -Value "===== Windows Server Health Check ====="
Add-Content -Path $logFile -Value "Servernaam: $hostname"
Add-Content -Path $logFile -Value "Datum/Tijd: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# 1. Systeem Informatie
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
$sysInfo = @"
Hostname       : $hostname
Datum/Tijd     : $(Get-Date)
Uptime         : {0:dd\.hh\:mm\:ss} dagen
"@ -f $uptime
Add-Section "Systeem Informatie" $sysInfo

# 2. IP-configuratie met subnet, gateway, DNS
$netAdapters = Get-NetIPConfiguration | Where-Object { $_.IPv4Address }
$ipDetails = foreach ($adapter in $netAdapters) {
    @"
Interface       : $($adapter.InterfaceAlias)
IP Address      : $($adapter.IPv4Address.IPAddress)
Subnet Mask     : $($adapter.IPv4Address.PrefixLength)
Default Gateway : $($adapter.IPv4DefaultGateway.NextHop)
DNS Servers     : $($adapter.DNSServer.ServerAddresses -join ", ")
"@
}
Add-Section "IP-configuratie (inclusief Subnet/Gateway/DNS)" ($ipDetails -join "`n")

# 3. Processorbelasting
$cpu = Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage | Out-String
Add-Section "Processorbelasting" $cpu

# 4. NTP Status
$ntp = w32tm /query /status 2>&1 | Out-String
Add-Section "NTP Status" $ntp

# 5. DNS Test
try {
    $dns = Resolve-DnsName google.com -ErrorAction Stop | Select-Object Name, IPAddress | Out-String
} catch {
    $dns = "DNS-resolutie mislukt: $($_.Exception.Message)"
}
Add-Section "DNS Resolutie Test" $dns

# 6. Event Logs
$events = Get-WinEvent -LogName System -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -eq "Error" } |
    Select-Object TimeCreated, Id, Message -First 10 | Out-String
Add-Section "Event Logs (System Errors - recent)" $events

# 7. Disk Capaciteit
$disk = Get-PSDrive -PSProvider 'FileSystem' |
    Select-Object Name,
        @{Name="Used(GB)";Expression={[math]::Round(($_.Used/1GB),2)}},
        @{Name="Free(GB)";Expression={[math]::Round(($_.Free/1GB),2)}},
        @{Name="Total(GB)";Expression={[math]::Round(($_.Used + $_.Free)/1GB,2)}} | Out-String
Add-Section "Disk Capaciteit" $disk

# 8. Memory Usage
$mem = Get-CimInstance -ClassName Win32_OperatingSystem |
    Select-Object @{Name="TotalMemory(GB)";Expression={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}},
                  @{Name="FreeMemory(GB)";Expression={[math]::Round($_.FreePhysicalMemory/1MB,2)}} | Out-String
Add-Section "Memory Usage" $mem

# 9. Services - Alleen automatische services die NIET running zijn
$services = Get-Service |
    Where-Object { $_.StartType -eq "Automatic" -and $_.Status -ne "Running" } |
    Select-Object Name, DisplayName, Status | Out-String
Add-Section "Services (Auto Start - Not Running)" $services

# 10. Anti-virus Status
$avStatus = ""
try {
    # Probeer Defender
    $defender = Get-MpComputerStatus -ErrorAction Stop
    $avStatus = $defender | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, SignatureUpdateTime | Out-String
} catch {
    try {
        # Fallback naar SecurityCenter2 (alleen op clients)
        $av = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction Stop
        if ($av) {
            $avStatus = $av | Select-Object displayName, productState, pathToSignedProductExe | Out-String
        } else {
            $avStatus = "Geen antivirus gevonden in SecurityCenter2."
        }
    } catch {
        $avStatus = "Geen antivirus gevonden of toegang geweigerd. Fout: $($_.Exception.Message)"
    }
}
Add-Section "Anti-virus Status" $avStatus

# 11. Windows Updates
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $pendingUpdates = $searcher.Search("IsInstalled=0").Updates

    $updateInfo = if ($pendingUpdates.Count -gt 0) {
        "Beschikbare updates: $($pendingUpdates.Count)`n" + ($pendingUpdates | ForEach-Object { " - $($_.Title)" }) -join "`n"
    } else {
        "Geen updates in behandeling."
    }

    $lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    $updateInfo += "`nLaatste geïnstalleerde update:`n$($lastUpdate | Out-String)"
} catch {
    $updateInfo = "Windows Update controle mislukt: $($_.Exception.Message)"
}
Add-Section "Windows Updates (N-1)" $updateInfo

# 12. Licentie Status
$lic = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" |
    Where-Object { $_.PartialProductKey } |
    Select-Object Description, LicenseStatus | Out-String
Add-Section "Licentie Status" $lic

# 13. OS Versie
$osver = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer | Out-String
Add-Section "OS Versie" $osver

# 14. Firewall Status
$fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
$fwReport = foreach ($fw in $fwProfiles) {
    "$($fw.Name): Inbound=$($fw.DefaultInboundAction), Outbound=$($fw.DefaultOutboundAction), Actief=$($fw.Enabled)"
}
Add-Section "Firewall Status (per profiel)" ($fwReport -join "`n")

# 15. Scheduled Tasks (enkel root van Task Scheduler Library)
$tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -eq "\" } |
    Select-Object TaskName, State, Description | Format-List | Out-String
Add-Section "Scheduled Tasks (root only)" $tasks

# 16. VSS Writers
$vss = vssadmin list writers | Out-String
Add-Section "VSS Writers" $vss

# 17. DISM Check (read-only)
$dism = DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
Add-Section "DISM Statuscontrole (read-only)" $dism

# 18. SFC Scan (read-only)
$sfc = sfc /verifyonly 2>&1 | Out-String
Add-Section "SFC Scan (read-only)" $sfc

# 19. Chkdsk Analyse (read-only)
$chk = Get-Volume | ForEach-Object {
    if ($_.DriveLetter) {
        "Volume: $($_.DriveLetter)`n" + (cmd /c "chkdsk $($_.DriveLetter):") + "`n"
    }
} | Out-String
Add-Section "Chkdsk Analyse (read-only)" $chk

# Einde
Write-Host "`nHealth check voltooid. Logbestand opgeslagen als:`n$logFile"

Add-Content -Path $logFile -Value "`nHealth check succesvol voltooid op $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
