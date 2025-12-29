# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Structure initiale du repository
- Module commun SCCM-Functions.psm1 avec fonctions de base
- README et documentation pour chaque catégorie
- Guide de contribution (CONTRIBUTING.md)
- Fichiers LICENSE et .gitignore

### Modifié
- N/A

### Corrigé
- N/A

### Supprimé
- N/A

---

## [1.0.0] - 2025-01-XX

### Ajouté
- Première version publique du ConfigMgr Toolkit
- Organisation en catégories : Compliance, Deployment, Reporting, Maintenance, Inventory
- Fonctions communes pour l'interaction avec SCCM
- Documentation complète et exemples d'utilisation

---

## Format des entrées

Pour chaque version, documenter les changements dans ces catégories :
- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements dans les fonctionnalités existantes
- **Déprécié** : Fonctionnalités qui seront supprimées
- **Supprimé** : Fonctionnalités supprimées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Corrections de vulnérabilités

Exemple :
```
## [1.1.0] - 2025-02-15

### Ajouté
- Script Compliance/Check-WindowsUpdates.ps1 pour vérifier l'état des mises à jour
- Fonction Get-SCCMDeviceInfo dans le module commun

### Modifié
- Amélioration de la fonction Connect-SCCMSite avec retry automatique
- Optimisation des requêtes dans Reporting/Inactive-Machines.ps1

### Corrigé
- Correction d'un bug dans Write-CMLog avec les caractères spéciaux
```
