# 📊 SCCM Performance Monitoring System

Solution de monitoring horaire pour suivre l'évolution des performances SCCM pendant les phases de remédiation.

## 🎯 Objectifs

- **Capturer une baseline** avant remédiation (T0)
- **Collecter des métriques horaires** pour observer les patterns de charge
- **Démontrer le ROI** via tendances historiques
- **Alerter** sur les dépassements de seuils critiques
- **Visualiser** l'amélioration dans Power BI

## 📁 Structure

```
C:\SCCM_Monitoring\
├── Data\
│   ├── SCCM_Metrics_History.csv      # Historique complet des métriques
│   └── SCCM_Baseline_Initial.json    # Snapshot initial (T0)
├── Scripts\
│   ├── Initialize-Monitoring.ps1     # Setup initial + baseline
│   ├── Collect-SCCMMetrics.ps1       # Collecte horaire
│   └── Export-PowerBIReport.ps1      # Export et rapports
├── Config\
│   └── thresholds.json               # Seuils configurables
├── Logs\
│   └── Collection_YYYYMMDD.log       # Logs quotidiens
└── Reports\
    └── SCCM_Report_*.html            # Rapports HTML
```

## 🚀 Installation

### Prérequis

- Windows Server avec SCCM installé
- PowerShell 5.1+
- Module ConfigurationManager
- Droits administrateur SCCM
- (Optionnel) SQL Server Management Tools pour métriques avancées

### Étape 1 : Copier les fichiers

```powershell
# Copier le dossier SCCM_Monitoring vers C:\
Copy-Item -Path "\\source\SCCM_Monitoring" -Destination "C:\" -Recurse
```

### Étape 2 : Ajuster les seuils

Éditer `C:\SCCM_Monitoring\Config\thresholds.json` selon votre contexte :

```json
{
  "Collections": {
    "TotalCount": {
      "warning": 450,      # ← Ajuster selon votre environnement
      "critical": 500,
      "target": 300
    }
  }
}
```

### Étape 3 : Initialiser le monitoring

```powershell
cd C:\SCCM_Monitoring\Scripts

# Initialisation + capture baseline
.\Initialize-Monitoring.ps1 -SiteCode "PS1"

# Configurer la tâche planifiée horaire
.\Initialize-Monitoring.ps1 -SiteCode "PS1" -SetupScheduledTask
```

### Étape 4 : Vérifier la collecte

```powershell
# Test manuel de collecte
.\Collect-SCCMMetrics.ps1 -SiteCode "PS1"

# Vérifier les données
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | Out-GridView
```

## 📊 Métriques Collectées

### Collections (9 métriques)

| Métrique | Description | Seuil par défaut |
|----------|-------------|------------------|
| **TotalCount** | Nombre total de collections | W:450 / C:500 |
| **IncrementalCount** | Collections avec refresh incrémental | W:180 / **C:200 (limite Microsoft)** |
| **EmptyCollections** | Collections vides > 30 jours | W:30 / C:50 |
| **UnusedCollections** | Sans déploiements ni utilisation | W:50 / C:100 |
| **OrphanedCollections** | Isolées sans relations | W:20 / C:40 |
| **MaxDepth** | Profondeur max arborescence | W:5 / C:7 |
| **AvgDepth** | Profondeur moyenne | W:2.5 / C:3.5 |
| **ComplexQueryCount** | Requêtes WQL complexes | W:30 / C:50 |
| **CircularDependencies** | Dépendances circulaires | W:1 / C:5 |

### Performance (6 métriques)

| Métrique | Description | Seuil par défaut |
|----------|-------------|------------------|
| **AvgEvalTime** | Temps moyen évaluation collections | W:120s / C:300s |
| **MaxEvalTime** | Temps maximum d'évaluation | W:300s / C:600s |
| **CollEvalBacklog** | File d'attente évaluations | W:50 / C:100 |
| **SlowCollections** | Collections > 300s | W:10 / C:20 |
| **EvalFailures** | Échecs d'évaluation (24h) | W:5 / C:15 |
| **ConsoleLaunchTime** | Temps chargement console | W:5s / C:10s |

### System (4 métriques)

| Métrique | Description | Seuil par défaut |
|----------|-------------|------------------|
| **SiteServerCPU** | Utilisation CPU serveur site | W:75% / C:85% |
| **SQLServerCPU** | Utilisation CPU SQL | W:75% / C:85% |
| **SQLDatabaseSize** | Taille base de données | W:100GB / C:150GB |
| **ProviderLoad** | Charge SMS Provider | W:1000 / C:2000 req/h |

### Deployments (4 métriques)

| Métrique | Description | Seuil par défaut |
|----------|-------------|------------------|
| **ActiveDeployments** | Déploiements actifs | W:700 / C:800 |
| **ObsoleteDeployments** | Déploiements > 1 an | W:100 / C:200 |
| **AvgSuccessRate** | Taux de succès moyen | W:95% / C:90% |
| **FailedDeployments** | Avec taux échec > 20% | W:10 / C:20 |

## 📈 Analyse et Reporting

### Génération rapport HTML

```powershell
# Rapport complet avec graphiques
.\Export-PowerBIReport.ps1 -GenerateHTML -OpenReport

# Rapport sur période spécifique
.\Export-PowerBIReport.ps1 -DateFrom "2025-01-15" -DateTo "2025-02-15" -GenerateHTML
```

### Import Power BI

1. Ouvrir **Power BI Desktop**
2. **Obtenir les données** > Texte/CSV
3. Sélectionner `C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv`
4. Créer les visuels :

#### Graphique en courbes - Évolution Collections
- **Axe X** : Timestamp
- **Axe Y** : MetricValue
- **Légende** : MetricName
- **Filtrer** : MetricCategory = "Collections"

#### Carte - Valeur actuelle
- **Champs** : MetricValue (dernière valeur)
- **Filtrer** : MetricName = "TotalCount"

#### Jauge - Avec seuils
- **Valeur** : MetricValue (dernière)
- **Min** : 0
- **Max** : Threshold (Critical)
- **Cible** : Threshold (Warning)

#### Tableau - Status Overview
- **Colonnes** : MetricCategory, MetricName, MetricValue, Status
- **Mise en forme conditionnelle** :
  - Status = "OK" → Vert
  - Status = "WARNING" → Orange
  - Status = "CRITICAL" → Rouge

## 🔧 Configuration Avancée

### Modifier la fréquence de collecte

```powershell
# Voir la tâche planifiée
Get-ScheduledTask -TaskName "SCCM-Monitoring-Hourly"

# Modifier pour collecte toutes les 30 minutes
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
Set-ScheduledTask -TaskName "SCCM-Monitoring-Hourly" -Trigger $trigger
```

### Ajuster les seuils dynamiquement

Éditer `Config\thresholds.json` - les changements seront pris en compte à la prochaine collecte.

### Rotation des logs

```powershell
# Ajouter à une tâche planifiée mensuelle
Get-ChildItem C:\SCCM_Monitoring\Logs -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddMonths(-2) } |
    Remove-Item -Force
```

## 📊 Cas d'Usage

### 1. Démonstration ROI Management

**Objectif** : Prouver l'amélioration après remédiation

```powershell
# T0 - Avant remédiation
.\Initialize-Monitoring.ps1 -SiteCode "PS1"
# Baseline capturée : 5234 collections, 312 incrémentales

# T0+4 semaines - Après remédiation phase 1
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv |
    Where-Object { $_.MetricName -eq "TotalCount" } |
    Sort-Object Timestamp |
    Select-Object Timestamp, MetricValue
```

**Résultat attendu** :
```
Timestamp                MetricValue
---------                -----------
2025-01-15 10:00         5234        # Baseline
2025-01-22 10:00         4876        # -358 (-7%)
2025-01-29 10:00         4521        # -713 (-14%)
2025-02-05 10:00         3987        # -1247 (-24%)
```

### 2. Surveillance pendant migration

**Objectif** : Observer l'impact des changements en temps réel

```powershell
# Pendant la migration, surveiller toutes les heures
Get-Content C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv -Tail 50 |
    ConvertFrom-Csv |
    Where-Object { $_.Status -eq "CRITICAL" }
```

### 3. Analyse des patterns de charge

**Objectif** : Identifier les heures de pointe

```powershell
# Analyser les temps d'évaluation par heure de la journée
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv |
    Where-Object { $_.MetricName -eq "AvgEvalTime" } |
    ForEach-Object {
        [PSCustomObject]@{
            Hour = ([datetime]$_.Timestamp).Hour
            AvgTime = [double]$_.MetricValue
        }
    } |
    Group-Object Hour |
    ForEach-Object {
        [PSCustomObject]@{
            Hour = $_.Name
            AvgEvalTime = ($_.Group | Measure-Object -Property AvgTime -Average).Average
        }
    } |
    Sort-Object Hour
```

## 🚨 Alertes et Notifications

### Email sur métriques critiques

Ajouter à `Collect-SCCMMetrics.ps1` :

```powershell
# À la fin de la fonction Save-Metrics
if ($critical -gt 0) {
    $body = "Alerte SCCM : $critical métriques CRITIQUES détectées`n`n"
    $criticalMetrics = $script:CollectedMetrics | Where-Object { $_.Status -eq "CRITICAL" }
    $body += $criticalMetrics | Format-Table | Out-String
    
    Send-MailMessage `
        -To "admin@company.com" `
        -From "sccm-monitoring@company.com" `
        -Subject "⚠ Alerte SCCM - Métriques Critiques" `
        -Body $body `
        -SmtpServer "smtp.company.com"
}
```

### Intégration Zabbix (optionnel)

```powershell
# Script personnalisé pour Zabbix sender
$latestMetrics = Import-Csv $MetricsFile | Group-Object MetricName | 
    ForEach-Object { $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1 }

foreach ($metric in $latestMetrics) {
    & "C:\zabbix\bin\zabbix_sender.exe" `
        -z "zabbix.company.com" `
        -s "SCCM-Server" `
        -k "sccm.$($metric.MetricCategory).$($metric.MetricName)" `
        -o $metric.MetricValue
}
```

## 🐛 Dépannage

### La collecte ne fonctionne pas

```powershell
# Vérifier les prérequis
Test-Path "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"

# Tester la connexion SCCM
Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
Get-PSDrive -PSProvider CMSite

# Vérifier la tâche planifiée
Get-ScheduledTask -TaskName "SCCM-Monitoring-Hourly" | Get-ScheduledTaskInfo
```

### Métriques SQL manquantes

```powershell
# Vérifier l'accès SQL
$siteInfo = Get-CMSite -SiteCode "PS1"
Test-Connection $siteInfo.DatabaseServerName

# Tester requête SQL
Invoke-Sqlcmd -ServerInstance $siteInfo.DatabaseServerName `
    -Database "CM_PS1" `
    -Query "SELECT COUNT(*) FROM v_Collection"
```

### Fichier CSV corrompu

```powershell
# Vérifier l'intégrité
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv -ErrorAction Stop

# Recréer le header si nécessaire
"Timestamp,MetricCategory,MetricName,MetricValue,MetricUnit,Threshold,Status,Notes" |
    Out-File C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv -Encoding UTF8
```

## 📚 Ressources

- [Microsoft Learn - SCCM Collections Best Practices](https://learn.microsoft.com/en-us/mem/configmgr/core/clients/manage/collections/best-practices-for-collections)
- [Site Sizing Guidelines](https://learn.microsoft.com/en-us/mem/configmgr/core/plan-design/configs/size-and-scale-numbers)
- [Performance Tuning](https://learn.microsoft.com/en-us/mem/configmgr/core/servers/deploy/configure/site-server-performance-improvements)

## 🤝 Support

Pour toute question :
1. Consulter les logs : `C:\SCCM_Monitoring\Logs\`
2. Vérifier le README
3. Contacter l'équipe SCCM

## 📝 Changelog

### Version 1.0 (2025-01-15)
- ✅ Initialisation du monitoring
- ✅ Collecte horaire automatique
- ✅ 23 métriques configurées
- ✅ Export Power BI
- ✅ Rapports HTML

---

**Auteur** : Infrastructure Team  
**Date** : Janvier 2025  
**Version** : 1.0
