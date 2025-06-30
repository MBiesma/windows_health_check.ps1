
# Windows Server Health Check Script

## 📝 Beschrijving
Dit PowerShell-script voert een **uitgebreide health check** uit op een Windows Server. Het resultaat wordt opgeslagen in een `.log` bestand op basis van datum/tijd en hostname. Ideaal voor dagelijks, wekelijks of ad-hoc gebruik in professionele serveromgevingen.

De controle is **read-only** en wijzigt niets aan het systeem. Het script is geschikt voor:
- Windows Server 2016, 2019, 2022
- Geautomatiseerde monitoring
- Handmatige controles voorafgaand aan updates of migraties

## ✅ Inhoud van de check

| Onderdeel                | Beschrijving |
|--------------------------|--------------|
| Systeeminformatie        | Hostnaam, datum/tijd, uptime |
| IP-configuratie          | IP, subnet, gateway, DNS |
| Processorbelasting       | CPU gebruik (%) |
| NTP Status               | NTP synchronisatie-informatie |
| DNS Test                 | Resolutie van `google.com` |
| Event Logs               | Laatste systeemfouten |
| Diskruimte               | Gebruikt, vrij en totaal |
| Geheugenstatus           | Totaal en vrij fysiek geheugen |
| Services                 | Alleen services met Auto Start die niet draaien |
| Antivirus Status         | AV-product en status |
| Windows Updates          | Beschikbare updates en laatst geïnstalleerde update |
| Licentie                 | Windows activatiestatus |
| OS Versie                | Naam, versie en HAL |
| Firewall Status          | Status per profiel (In/Outbound, Actief) |
| Scheduled Tasks          | Alleen root-taken van Task Scheduler Library |
| VSS Writers              | Status van VSS-schrijvers |
| DISM (CheckHealth)       | Read-only controle op componentstore-integriteit |
| SFC Scan                 | Systeembestandscontrole (verify-only) |
| Chkdsk                   | Read-only volumecontrole |

## 📁 Output
Het script maakt automatisch de map `C:\HealthCheck` aan (indien niet aanwezig) en slaat daarin een `.log` bestand op, bijvoorbeeld:

```
C:\HealthCheck\202506301015_SERVER01.log
```

## ▶️ Uitvoeren

Sla het script op als `.ps1` bestand, bijvoorbeeld:

```
C:\Scripts\WindowsHealthCheck.ps1
```

Start PowerShell als Administrator en voer uit:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Scripts\WindowsHealthCheck.ps1"
```

## 📅 Automatisch uitvoeren (optioneel)
Gebruik Windows Taakplanner (Task Scheduler):

1. Kies **"Nieuwe taak maken"**
2. Stel in: Uitvoeren als hoogste rechten
3. Programma/script: `powershell.exe`
4. Argumenten:  
   ```
   -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Scripts\WindowsHealthCheck.ps1"
   ```

---

## 👤 Auteur

- **Mark Biesma**  
- GitHub: [https://github.com/MBiesma](https://github.com/MBiesma)

---
