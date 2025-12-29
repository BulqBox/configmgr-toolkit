# Examples

Exemples d'utilisation et documentation pour les scripts du toolkit.

## Comment utiliser ce toolkit

### 1. Configuration initiale

Avant d'utiliser les scripts, assurez-vous d'avoir :
- La console Configuration Manager installée
- Les droits suffisants sur l'infrastructure SCCM
- PowerShell 5.1 ou supérieur

### 2. Exemple basique

```powershell
# Importer le module commun
Import-Module .\Common\SCCM-Functions.psm1

# Se connecter au site
Connect-SCCMSite -SiteCode "ABC" -SiteServer "sccm-server.domain.com"

# Récupérer une collection
$Collection = Get-SCCMCollection -CollectionName "All Servers"

# Afficher les informations
Write-Host "Collection: $($Collection.Name)"
Write-Host "Nombre de membres: $($Collection.MemberCount)"
```

### 3. Exemple avec logging

```powershell
# Définir le chemin du log
$LogPath = "C:\Logs\MonScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Importer les fonctions
Import-Module .\Common\SCCM-Functions.psm1

# Logger le démarrage
Write-CMLog -Message "Script démarré" -Component "MonScript" -Type Info -LogPath $LogPath

try {
    # Votre code ici
    Connect-SCCMSite -SiteCode "ABC" -SiteServer "sccm-server.domain.com"
    Write-CMLog -Message "Connexion réussie" -Component "MonScript" -Type Info -LogPath $LogPath
}
catch {
    Write-CMLog -Message "Erreur: $_" -Component "MonScript" -Type Error -LogPath $LogPath
}
```

### 4. Exemple de déploiement avec baseline

```powershell
# Script de conformité pour empêcher Data Deduplication
Import-Module .\Common\SCCM-Functions.psm1

# Configuration
$SiteCode = "ABC"
$SiteServer = "sccm-server.domain.com"
$CollectionName = "All Servers"

# Connexion
Connect-SCCMSite -SiteCode $SiteCode -SiteServer $SiteServer

# Récupérer la collection
$Collection = Get-SCCMCollection -CollectionName $CollectionName

if ($Collection) {
    # Créer et déployer la baseline
    # Voir le script complet dans Compliance/Prevent-DataDeduplication.ps1
    Write-Host "✓ Baseline déployée sur $($Collection.MemberCount) machines"
}
```

### 5. Exemple de rapport personnalisé

```powershell
# Générer un rapport des machines sans activité
Import-Module .\Common\SCCM-Functions.psm1

# Connexion
Connect-SCCMSite -SiteCode "ABC" -SiteServer "sccm-server.domain.com"

# Requête SQL (via Reporting/vos-scripts-sql)
$InactiveMachines = Invoke-CMQuery -Query "SELECT * FROM v_R_System WHERE LastActiveTime < DATEADD(day, -30, GETDATE())"

# Export en CSV
$InactiveMachines | Export-Csv -Path "C:\Reports\InactiveMachines-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

Write-Host "✓ Rapport généré: $($InactiveMachines.Count) machines inactives"
```

## Bonnes pratiques

1. **Toujours tester en dev** : Ne jamais exécuter un script directement en production
2. **Logger les actions** : Utiliser Write-CMLog pour tracer toutes les opérations
3. **Gérer les erreurs** : Utiliser Try/Catch pour capturer les exceptions
4. **Documenter** : Ajouter des commentaires et l'aide PowerShell
5. **Paramétrer** : Éviter les valeurs en dur, utiliser des paramètres

## Ressources supplémentaires

- [Documentation PowerShell pour SCCM](https://docs.microsoft.com/en-us/powershell/module/configurationmanager/)
- [CMTrace pour lire les logs](https://docs.microsoft.com/en-us/mem/configmgr/core/support/cmtrace)
