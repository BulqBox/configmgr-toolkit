# Reporting

Requêtes SQL personnalisées et scripts de génération de rapports pour Configuration Manager.

## Scripts disponibles

*À venir : ajoutez vos scripts de reporting ici*

## Structure des rapports

Les scripts de reporting doivent :
- Se connecter au serveur SQL de façon sécurisée
- Exporter les résultats en CSV ou HTML
- Inclure des horodatages dans les noms de fichiers
- Gérer les erreurs de connexion proprement

## Exemple de requête

```sql
-- Récupérer les machines sans client actif depuis 30 jours
SELECT 
    sys.Name0 AS ComputerName,
    sys.AD_Site_Name0 AS ADSite,
    stat.LastActiveTime
FROM v_R_System sys
INNER JOIN v_ClientHealthState stat ON sys.ResourceID = stat.ResourceID
WHERE stat.LastActiveTime < DATEADD(day, -30, GETDATE())
ORDER BY stat.LastActiveTime
```

## Connexion à la base

Utilisez toujours l'authentification Windows et les connexions sécurisées.
