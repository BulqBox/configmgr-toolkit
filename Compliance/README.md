# Compliance

Scripts pour la gestion des baselines de conformité et des configurations de sécurité.

## Scripts disponibles

### Prevent-DataDeduplication.ps1
Empêche l'installation de la fonctionnalité Data Deduplication sur les serveurs Windows.

**Utilisation :**
```powershell
.\Prevent-DataDeduplication.ps1 -CollectionName "All Servers" -SiteCode "ABC"
```

**Paramètres :**
- `CollectionName` : Nom de la collection cible
- `SiteCode` : Code du site SCCM

**Notes :**
- Utilise une baseline de conformité SCCM
- Compatible avec PowerShell DSC
- Vérifie l'état toutes les heures

## Ajout de nouveaux scripts

Les scripts de compliance doivent suivre ces conventions :
- Utiliser des baselines de configuration plutôt que des déploiements
- Inclure des capacités de remédiation
- Logger les actions dans le journal d'événements Windows
- Retourner des codes de conformité standardisés (0 = conforme, 1 = non-conforme)
