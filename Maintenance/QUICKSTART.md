# 🚀 Guide de Démarrage Rapide - SCCM Monitoring

## ⏱️ Installation en 10 minutes

### 1️⃣ Prérequis (2 min)

Vérifiez que vous avez :
- [x] Accès administrateur sur le serveur SCCM
- [x] PowerShell 5.1+ (vérifier : `$PSVersionTable`)
- [x] Module ConfigurationManager installé

### 2️⃣ Copier les fichiers (2 min)

```powershell
# Copier le dossier vers C:\
Copy-Item -Path ".\SCCM_Monitoring" -Destination "C:\" -Recurse

# Vérifier la structure
Get-ChildItem C:\SCCM_Monitoring -Recurse
```

### 3️⃣ Première exécution (3 min)

```powershell
# Aller dans le dossier Scripts
cd C:\SCCM_Monitoring\Scripts

# Initialiser (remplacer PS1 par votre code de site)
.\Initialize-Monitoring.ps1 -SiteCode "PS1"
```

**✅ Résultat attendu** :
```
╔════════════════════════════════════════════════════════════════╗
║           INITIALISATION DU MONITORING SCCM                    ║
╚════════════════════════════════════════════════════════════════╝
✓ Module ConfigurationManager chargé
✓ Connecté au site : Mon Site SCCM (PS1)
✓ Baseline sauvegardée : C:\SCCM_Monitoring\Data\SCCM_Baseline_Initial.json

=== RÉSUMÉ DE LA BASELINE ===
Collections totales      : 5234
Collections incrémentales: 312
Collections vides        : 87
Déploiements actifs      : 2451

✅ INITIALISATION TERMINÉE
```

### 4️⃣ Test de collecte (2 min)

```powershell
# Collecter les premières métriques
.\Collect-SCCMMetrics.ps1 -SiteCode "PS1"

# Vérifier les données
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | Select-Object -First 10 | Format-Table
```

### 5️⃣ Activer la collecte horaire (1 min)

```powershell
# Créer la tâche planifiée
.\Initialize-Monitoring.ps1 -SiteCode "PS1" -SetupScheduledTask

# Vérifier qu'elle est active
Get-ScheduledTask -TaskName "SCCM-Monitoring-Hourly"
```

## 📊 Premiers Rapports

### Voir les données en temps réel

```powershell
# Vue graphique
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | Out-GridView

# Voir uniquement les métriques CRITICAL
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | 
    Where-Object { $_.Status -eq "CRITICAL" } | 
    Format-Table -AutoSize
```

### Générer un rapport HTML

```powershell
.\Export-PowerBIReport.ps1 -GenerateHTML -OpenReport
```

Un rapport HTML interactif s'ouvrira automatiquement dans votre navigateur ! 🎉

## 🎯 Prochaines Étapes

### Jour 1 - Configuration
- ✅ Initialisation complète
- [ ] Ajuster les seuils dans `Config\thresholds.json` selon votre contexte
- [ ] Vérifier que la tâche planifiée fonctionne

### Semaine 1 - Observation
- [ ] Observer les métriques pendant 7 jours
- [ ] Identifier les patterns de charge (heures de pointe)
- [ ] Noter les collections problématiques

### Semaine 2+ - Action
- [ ] Commencer la remédiation
- [ ] Comparer avec la baseline
- [ ] Générer des rapports hebdomadaires pour le management

## 💡 Astuces

### Voir l'évolution d'une métrique spécifique

```powershell
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | 
    Where-Object { $_.MetricName -eq "TotalCount" } | 
    Select-Object Timestamp, MetricValue | 
    Format-Table
```

### Calculer l'amélioration depuis la baseline

```powershell
# Charger la baseline
$baseline = Get-Content C:\SCCM_Monitoring\Data\SCCM_Baseline_Initial.json | ConvertFrom-Json

# Dernière valeur
$current = Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | 
    Where-Object { $_.MetricName -eq "TotalCount" } | 
    Sort-Object Timestamp -Descending | 
    Select-Object -First 1

# Calculer l'amélioration
$improvement = $baseline.Metrics.Collections.TotalCount - $current.MetricValue
$improvementPct = [math]::Round(($improvement / $baseline.Metrics.Collections.TotalCount) * 100, 1)

Write-Host "Collections baseline : $($baseline.Metrics.Collections.TotalCount)" -ForegroundColor Yellow
Write-Host "Collections actuelles: $($current.MetricValue)" -ForegroundColor Green
Write-Host "Amélioration         : $improvement collections ($improvementPct%)" -ForegroundColor Cyan
```

### Exporter pour Excel

```powershell
# Export pour analyse dans Excel
Import-Csv C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv | 
    Export-Excel -Path "C:\SCCM_Analysis.xlsx" -AutoSize -TableName "Metrics"
```

## 🆘 Problèmes Fréquents

### "Module ConfigurationManager not found"

```powershell
# Vérifier le chemin
$ENV:SMS_ADMIN_UI_PATH

# Importer manuellement
Import-Module "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1"
```

### "Access Denied"

➡️ Exécuter PowerShell en tant qu'Administrateur

### La tâche planifiée ne s'exécute pas

```powershell
# Vérifier le dernier résultat
Get-ScheduledTask -TaskName "SCCM-Monitoring-Hourly" | Get-ScheduledTaskInfo

# Voir les logs
Get-Content C:\SCCM_Monitoring\Logs\Collection_*.log -Tail 50
```

## 📚 Pour aller plus loin

- Consulter le **README.md** complet
- Personnaliser les **thresholds.json**
- Créer des **tableaux de bord Power BI**
- Intégrer à **Zabbix** ou autres outils de monitoring

---

**Besoin d'aide ?** Consultez le README.md ou contactez l'équipe Infrastructure ! 🚀
