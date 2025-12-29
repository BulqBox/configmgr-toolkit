# 📦 Livrables - Solution SCCM Monitoring

## 📂 Contenu de la Solution

### 1. Scripts PowerShell (3 fichiers)

#### `Scripts/Initialize-Monitoring.ps1`
- **Rôle** : Setup initial + capture baseline
- **Exécution** : Une seule fois au début
- **Fonctionnalités** :
  - Vérification des prérequis
  - Création de la structure de dossiers
  - Capture de la baseline (T0)
  - Configuration de la tâche planifiée

#### `Scripts/Collect-SCCMMetrics.ps1`
- **Rôle** : Collecte horaire des métriques
- **Exécution** : Automatique (tâche planifiée) ou manuel
- **Fonctionnalités** :
  - Collecte 23 métriques SCCM
  - Calcul automatique des statuts (OK/WARNING/CRITICAL)
  - Enregistrement dans CSV historique
  - Logs détaillés

#### `Scripts/Export-PowerBIReport.ps1`
- **Rôle** : Génération de rapports et exports
- **Exécution** : À la demande
- **Fonctionnalités** :
  - Rapports HTML interactifs avec graphiques
  - Calcul des améliorations vs baseline
  - Instructions Power BI
  - Export pour Excel

### 2. Configuration

#### `Config/thresholds.json`
Configuration complète des seuils pour 23 métriques :
- **Collections** : 9 métriques (TotalCount, IncrementalCount, etc.)
- **Performance** : 6 métriques (AvgEvalTime, MaxEvalTime, etc.)
- **System** : 4 métriques (SiteServerCPU, SQLDatabaseSize, etc.)
- **Deployments** : 4 métriques (ActiveDeployments, ObsoleteDeployments, etc.)

Chaque métrique inclut :
- Seuil WARNING
- Seuil CRITICAL
- Cible (target)
- Source (Microsoft/Community/Best practice)
- Description

### 3. Documentation

#### `README.md` (Complet)
- Installation pas à pas
- Description détaillée des 23 métriques
- Guide d'analyse et reporting
- Configuration avancée
- Cas d'usage pratiques
- Dépannage

#### `QUICKSTART.md` (10 minutes)
- Installation express
- Premiers tests
- Génération des premiers rapports
- Astuces PowerShell
- Problèmes fréquents

### 4. Données

#### `Data/EXAMPLE_Metrics.csv`
Exemple de fichier CSV avec :
- Format de données
- Exemple de baseline (T0)
- Évolution sur 4 semaines
- Démonstration statuts OK/WARNING/CRITICAL

## 🎯 Objectifs Atteints

✅ **Capture baseline** : Snapshot initial avant remédiation  
✅ **Collecte horaire** : Automatique via tâche planifiée  
✅ **23 métriques** : Collections, Performance, System, Deployments  
✅ **Seuils configurables** : Fichier JSON modifiable  
✅ **Statuts automatiques** : OK/WARNING/CRITICAL calculés  
✅ **Export Power BI** : Import direct du CSV  
✅ **Rapports HTML** : Interactifs avec graphiques  
✅ **Démonstration ROI** : Comparaison baseline vs actuel  

## 📊 Métriques Clés Surveillées

### Collections (Objectif : -40% du total)
- Total collections : **5234 → 300** (cible)
- Collections incrémentales : **312 → 150** (limite Microsoft : 200)
- Collections vides : **87 → 10**
- Collections inutilisées : **134 → 20**

### Performance (Objectif : -70% temps évaluation)
- Temps moyen évaluation : **187s → 60s**
- Temps maximum évaluation : **543s → 180s**
- Collections lentes (>300s) : **45 → 5**

### Deployments (Objectif : -60% du total)
- Déploiements actifs : **2451 → 400**
- Déploiements obsolètes : **543 → 30**

## 🚀 Workflow Complet

### Phase 1 : Setup (Jour 1)
```
Initialize-Monitoring.ps1
    ↓
Capture baseline T0
    ↓
Configure scheduled task
    ↓
First collection test
```

### Phase 2 : Observation (Semaine 1)
```
Collecte horaire automatique
    ↓
Accumulation historique
    ↓
Identification patterns
```

### Phase 3 : Remédiation (Semaines 2-6)
```
Actions de nettoyage
    ↓
Surveillance impact temps réel
    ↓
Ajustements continus
```

### Phase 4 : Reporting (Hebdomadaire)
```
Export-PowerBIReport.ps1
    ↓
Rapports HTML + Power BI
    ↓
Démonstration ROI Management
```

## 📈 Format CSV - Structure de Données

```csv
Timestamp,MetricCategory,MetricName,MetricValue,MetricUnit,Threshold,Status,Notes
2025-01-15 10:00:00,Collections,TotalCount,5234,count,W:450/C:500,CRITICAL,Baseline
2025-01-22 10:00:00,Collections,TotalCount,4876,count,W:450/C:500,CRITICAL,Week 1 - Removed 358
2025-01-29 10:00:00,Collections,TotalCount,4521,count,W:450/C:500,CRITICAL,Week 2 - Ongoing
2025-02-05 10:00:00,Collections,TotalCount,3987,count,W:450/C:500,CRITICAL,Week 3 - Major improvements
2025-02-12 10:00:00,Collections,TotalCount,3245,count,W:450/C:500,WARNING,Week 4 - Approaching target
```

**Colonnes** :
- `Timestamp` : Date et heure de collecte
- `MetricCategory` : Collections/Performance/System/Deployments
- `MetricName` : Nom de la métrique
- `MetricValue` : Valeur numérique
- `MetricUnit` : Unité (count/seconds/percent/GB/levels)
- `Threshold` : Seuils Warning/Critical
- `Status` : OK/WARNING/CRITICAL (calculé automatiquement)
- `Notes` : Commentaires contextuels

## 💡 Utilisation Power BI

### Import rapide
1. Power BI Desktop > **Obtenir les données** > Texte/CSV
2. Sélectionner `C:\SCCM_Monitoring\Data\SCCM_Metrics_History.csv`
3. Cliquer **Charger**

### Visuels recommandés

#### 1. Graphique en courbes - Évolution Collections
```
Axe X      : Timestamp
Axe Y      : MetricValue
Légende    : MetricName
Filtre     : MetricCategory = "Collections"
```

#### 2. Carte - Total Collections Actuel
```
Valeur     : MetricValue (dernière valeur)
Filtre     : MetricName = "TotalCount"
Format     : Grande police, couleur conditionnelle
```

#### 3. Jauge - Collections Incrémentales
```
Valeur     : MetricValue (dernière)
Minimum    : 0
Maximum    : 200 (limite Microsoft)
Cible      : 150 (target)
Filtre     : MetricName = "IncrementalCount"
```

#### 4. Tableau - Status Overview
```
Lignes     : MetricCategory, MetricName
Valeurs    : MetricValue (dernière), Status
Mise en forme : Conditionnelle selon Status
```

#### 5. KPI - Amélioration vs Baseline
```
Valeur     : MetricValue (dernière)
Objectif   : Baseline value
Tendance   : Timestamp
```

## 🔧 Personnalisation

### Modifier les seuils
Éditer `Config\thresholds.json` :
```json
"TotalCount": {
  "warning": 450,     ← Ajuster ici
  "critical": 500,    ← Et ici
  "target": 300
}
```

### Changer la fréquence
Modifier la tâche planifiée :
```powershell
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
Set-ScheduledTask -TaskName "SCCM-Monitoring-Hourly" -Trigger $trigger
```

### Ajouter des alertes email
Éditer `Collect-SCCMMetrics.ps1` dans la fonction `Save-Metrics` :
```powershell
if ($critical -gt 0) {
    Send-MailMessage -To "admin@company.com" `
        -Subject "⚠ Alerte SCCM" `
        -Body "Métriques critiques détectées"
}
```

## 📝 Checklist de Mise en Production

### Avant démarrage
- [ ] Serveur SCCM identifié
- [ ] Code de site connu (ex: PS1)
- [ ] Droits administrateur SCCM validés
- [ ] PowerShell 5.1+ vérifié
- [ ] Module ConfigurationManager disponible

### Installation
- [ ] Dossier copié vers C:\SCCM_Monitoring
- [ ] Seuils ajustés dans thresholds.json
- [ ] Initialize-Monitoring.ps1 exécuté avec succès
- [ ] Baseline capturée et sauvegardée
- [ ] Test de collecte manuel réussi

### Activation monitoring
- [ ] Tâche planifiée créée
- [ ] Tâche planifiée testée
- [ ] Première collecte horaire confirmée
- [ ] CSV historique alimenté
- [ ] Logs sans erreurs

### Rapports
- [ ] Rapport HTML généré avec succès
- [ ] Import Power BI testé
- [ ] Visuels Power BI créés
- [ ] Tableaux de bord partagés

### Documentation
- [ ] Équipe formée sur les scripts
- [ ] README partagé avec l'équipe
- [ ] Contact support défini
- [ ] Process de modification des seuils documenté

## 🎓 Formation Équipe

### Administrateurs SCCM (1h)
- Fonctionnement de la solution
- Lecture des métriques
- Ajustement des seuils
- Dépannage de base

### Management (30min)
- Objectifs du monitoring
- Lecture des rapports HTML
- Interprétation des KPI
- Démonstration Power BI

### Équipe Support (30min)
- Vérification collecte
- Consultation des logs
- Génération rapports à la demande

## 📞 Support

### Niveaux d'intervention

**Niveau 1** - Vérifications basiques
- Logs : `C:\SCCM_Monitoring\Logs\`
- Tâche planifiée : `Get-ScheduledTask -TaskName "SCCM-Monitoring-Hourly"`
- Dernière collecte : `Import-Csv $MetricsFile | Select-Object -Last 1`

**Niveau 2** - Tests diagnostiques
- Test collecte : `.\Collect-SCCMMetrics.ps1 -SiteCode "PS1"`
- Test connexion SCCM : Module ConfigurationManager
- Test SQL : `Invoke-Sqlcmd` sur base CM_

**Niveau 3** - Escalade équipe Infrastructure

---

## 🎉 Résultat Attendu

Après 4 semaines de remédiation :

| Métrique | Baseline T0 | Après 4 sem | Amélioration |
|----------|------------|-------------|--------------|
| Collections totales | 5,234 | 3,245 | -38% |
| Collections incrémentales | 312 | 167 | -46% |
| Collections vides | 87 | 23 | -74% |
| Temps moyen évaluation | 187s | 89s | -52% |
| Déploiements actifs | 2,451 | 987 | -60% |

**ROI Démontré** : Réduction de 40% de la charge système, amélioration de 50% des performances, conformité Microsoft 100% ✅
