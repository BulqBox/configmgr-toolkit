# Deployment

Scripts pour automatiser les déploiements d'applications et de mises à jour.

## Scripts disponibles

*À venir : ajoutez vos scripts de déploiement ici*

## Conventions

Les scripts de déploiement doivent :
- Vérifier les prérequis avant le déploiement
- Utiliser des variables d'environnement SCCM pour les chemins
- Logger les résultats dans des fichiers horodatés
- Gérer les codes de retour pour l'intégration SCCM
- Supporter le mode silencieux

## Codes de retour standards

- `0` : Succès
- `3010` : Succès - redémarrage requis
- `1` : Erreur générale
- `1603` : Erreur fatale pendant l'installation
