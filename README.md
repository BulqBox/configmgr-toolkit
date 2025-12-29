# ConfigMgr Toolkit

Une collection de scripts PowerShell pour l'administration et la gestion de Microsoft Configuration Manager (SCCM/MECM).

## 📋 Vue d'ensemble

Ce toolkit regroupe des scripts utilitaires développés pour faciliter l'administration quotidienne d'environnements Configuration Manager de grande envergure. Les scripts sont organisés par catégorie et peuvent être utilisés indépendamment ou intégrés dans vos processus existants.

## 🗂️ Structure du repository

```
configmgr-toolkit/
├── Compliance/          # Baselines et scripts de conformité
├── Deployment/          # Scripts de déploiement et packaging
├── Reporting/           # Rapports et requêtes personnalisés
├── Maintenance/         # Maintenance et optimisation
├── Inventory/           # Collecte et analyse d'inventaire
├── Common/              # Fonctions et modules partagés
└── Examples/            # Exemples d'utilisation et documentation
```

## 🚀 Pour commencer

### Prérequis

- PowerShell 5.1 ou supérieur
- Console Configuration Manager installée
- Droits suffisants sur l'infrastructure SCCM

### Installation

1. Clonez le repository :
```powershell
git clone https://github.com/votre-username/configmgr-toolkit.git
cd configmgr-toolkit
```

2. Importez les modules communs si nécessaire :
```powershell
Import-Module .\Common\SCCM-Functions.psm1
```

3. Consultez les README spécifiques dans chaque dossier pour les détails d'utilisation

## 📚 Documentation

Chaque catégorie possède son propre README avec :
- Description détaillée des scripts disponibles
- Paramètres et exemples d'utilisation
- Prérequis spécifiques
- Notes et limitations

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs via les Issues
- Proposer des améliorations
- Soumettre des pull requests avec de nouveaux scripts

## ⚠️ Avertissement

Ces scripts sont fournis "tels quels" sans garantie. Testez toujours dans un environnement de développement avant utilisation en production.

## 📝 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

Thomas - Consultant indépendant spécialisé en infrastructure Microsoft

## 🔗 Ressources utiles

- [Documentation officielle Configuration Manager](https://docs.microsoft.com/en-us/mem/configmgr/)
- [PowerShell Gallery - ConfigurationManager](https://www.powershellgallery.com/packages/ConfigurationManager/)
