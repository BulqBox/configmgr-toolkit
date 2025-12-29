# Inventory

Scripts pour collecter et analyser l'inventaire matériel et logiciel.

## Scripts disponibles

*À venir : ajoutez vos scripts d'inventaire ici*

## Types d'inventaire

### Inventaire matériel étendu
- Informations BIOS/UEFI
- Configuration réseau détaillée
- État des disques et SMART
- Périphériques USB

### Inventaire logiciel personnalisé
- Applications non-MSI
- Versions de frameworks (.NET, Java, etc.)
- Licences et activation
- Services et processus critiques

## Collecte de données WMI

Les scripts d'inventaire utilisent généralement WMI pour collecter les informations :

```powershell
# Exemple de collecte d'informations BIOS
Get-WmiObject -Class Win32_BIOS | Select-Object Manufacturer, Version, SerialNumber
```

## Extension de l'inventaire SCCM

Pour ajouter des données personnalisées à l'inventaire SCCM :
1. Créer une classe MOF personnalisée
2. Importer la classe dans la console SCCM
3. Activer la collecte pour les collections cibles
4. Créer des requêtes pour exploiter les données
