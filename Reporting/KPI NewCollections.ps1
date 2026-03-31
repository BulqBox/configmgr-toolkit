#Requires -Version 5.1
<#
.SYNOPSIS
    KPI - Nouvelles collections : créées dans la fenêtre de suivi + profondeur hiérarchique.

.DESCRIPTION
    Interroge directement la base SQL du site SCCM.
    Utilise une CTE récursive pour calculer la profondeur de chaque collection
    dans l'arborescence (0 = racine, N = N niveaux sous la racine).
    Produit un CSV : une ligne par nouvelle collection avec
      - Nom, ID, collection limitante
      - Créée par, date de création
      - Profondeur calculée dans la hiérarchie
      - Mode de rafraîchissement, nombre de règles d'adhésion
      - Présence de déploiements

.PARAMETER SiteCode
    Code du site SCCM (ex: CIR)

.PARAMETER SQLServer
    Serveur SQL distant (ex: SQLSRV01)

.PARAMETER OutputPath
    Dossier de dépôt du CSV. Défaut : D:\Backup\KPIs

.PARAMETER LastDays
    Fenêtre de détection en jours. Défaut : 7

.EXAMPLE
    .\KPI_NewCollections.ps1 -SiteCode CIR -SQLServer SQLSRV01 -LastDays 7
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [string]$SQLServer,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "D:\Backup\KPIs",

    [Parameter(Mandatory = $false)]
    [int]$LastDays = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Database  = "CM_$SiteCode"
$RunDate   = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputCSV = Join-Path $OutputPath "KPI_NewCollections_$RunDate.csv"

# ─── Requête SQL avec CTE récursive ──────────────────────────────────────────
#
# Explication de la CTE :
#   1. CollectionHierarchy - Ancre (anchor) :
#      On part des collections racines — celles dont LimitToCollectionID
#      est NULL ou vaut leur propre ID (ex: SMS00001 / All Systems).
#      On leur attribue une profondeur de 0.
#
#   2. CollectionHierarchy - Récursion :
#      Pour chaque collection dont on connaît déjà la profondeur,
#      on cherche ses enfants directs (ceux qui ont LimitToCollectionID = son ID)
#      et on leur attribue profondeur_parent + 1.
#      UNION ALL continue jusqu'à ce qu'il n'y ait plus d'enfants.
#
#   3. On joint le résultat de la CTE (la profondeur de TOUTES les collections)
#      avec les collections créées dans la fenêtre $LastDays.
#
$Query = @"
WITH CollectionHierarchy AS (

    -- Ancre : collections racines (limitées à elles-mêmes ou sans parent)
    SELECT
        col.CollectionID,
        col.Name,
        col.LimitToCollectionID,
        0 AS Depth
    FROM
        v_Collection col
    WHERE
        col.LimitToCollectionID IS NULL
        OR col.LimitToCollectionID = col.CollectionID

    UNION ALL

    -- Récursion : on descend d'un niveau à chaque itération
    SELECT
        child.CollectionID,
        child.Name,
        child.LimitToCollectionID,
        parent.Depth + 1
    FROM
        v_Collection child
        INNER JOIN CollectionHierarchy parent
            ON child.LimitToCollectionID = parent.CollectionID
    WHERE
        child.LimitToCollectionID <> child.CollectionID  -- Éviter boucle sur racine

)

SELECT
    col.CollectionID                                        AS CollectionID,
    col.Name                                               AS CollectionName,
    col.LimitToCollectionName                              AS LimitingCollection,
    col.CreatedBy                                          AS CreatedBy,
    CONVERT(VARCHAR(19), col.CollectionDateCreated, 120)   AS DateCreated,
    ISNULL(hier.Depth, -1)                                 AS HierarchyDepth,
    CASE col.RefreshType
        WHEN 1 THEN 'Manuel'
        WHEN 2 THEN 'Planifié'
        WHEN 4 THEN 'Incrémental'
        WHEN 6 THEN 'Planifié + Incrémental'
        ELSE        'Inconnu (' + CAST(col.RefreshType AS VARCHAR) + ')'
    END                                                    AS RefreshType,
    col.MemberCount                                        AS MemberCount,
    -- Nombre de règles d'adhésion (direct + query + include + exclude)
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleQuery    rq WHERE rq.CollectionID = col.CollectionID
    ) +
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleDirect   rd WHERE rd.CollectionID = col.CollectionID
    ) +
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleInclude  ri WHERE ri.CollectionID = col.CollectionID
    ) +
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleExclude  re WHERE re.CollectionID = col.CollectionID
    )                                                       AS TotalRuleCount,
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleInclude  ri WHERE ri.CollectionID = col.CollectionID
    )                                                       AS IncludeRuleCount,
    (
        SELECT COUNT(*)
        FROM v_CollectionRuleExclude  re WHERE re.CollectionID = col.CollectionID
    )                                                       AS ExcludeRuleCount,
    COUNT(dep.AssignmentID)                                AS DeploymentCount
FROM
    v_Collection col
    -- On prend la profondeur MAX au cas où la CTE renverrait plusieurs chemins
    LEFT JOIN (
        SELECT CollectionID, MAX(Depth) AS Depth
        FROM CollectionHierarchy
        GROUP BY CollectionID
    ) hier ON col.CollectionID = hier.CollectionID
    LEFT JOIN v_DeploymentSummary dep
        ON col.CollectionID = dep.CollectionID
WHERE
    col.CollectionType            = 2       -- Device collections uniquement
    AND col.IsBuiltIn             = 0       -- Exclure collections système
    AND col.CollectionDateCreated >= DATEADD(DAY, -$LastDays, GETDATE())
GROUP BY
    col.CollectionID,
    col.Name,
    col.LimitToCollectionName,
    col.CreatedBy,
    col.CollectionDateCreated,
    col.RefreshType,
    col.MemberCount,
    hier.Depth
ORDER BY
    col.CollectionDateCreated DESC,
    hier.Depth                DESC;
"@

# ─── Exécution ───────────────────────────────────────────────────────────────

try {
    Write-Host "[INFO] Connexion à $SQLServer / $Database" -ForegroundColor Cyan
    Write-Host "[INFO] Fenêtre de détection : $LastDays derniers jours" -ForegroundColor Cyan

    # MAXRECURSION 50 : limite la profondeur de la CTE à 50 niveaux
    # (amplement suffisant, protège contre une boucle infinie en cas de données corrompues)
    $Results = Invoke-Sqlcmd `
        -ServerInstance $SQLServer `
        -Database       $Database `
        -Query          $Query `
        -QueryTimeout   120 `
        -MaxCharLength  4096 `
        -Variable       @("MAXRECURSION=50") `
        -ErrorAction    Stop

    Write-Host "[INFO] $($Results.Count) nouvelles collections détectées." -ForegroundColor Cyan

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $Results |
        Select-Object CollectionID, CollectionName, LimitingCollection,
                      CreatedBy, DateCreated, HierarchyDepth,
                      RefreshType, MemberCount,
                      TotalRuleCount, IncludeRuleCount, ExcludeRuleCount,
                      DeploymentCount |
        Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8 -Delimiter ";"

    Write-Host "[OK] CSV exporté : $OutputCSV" -ForegroundColor Green

    # Résumé console
    $Incremental   = ($Results | Where-Object { $_.RefreshType -like "*Incrémental*" }).Count
    $DeepPlus5     = ($Results | Where-Object { $_.HierarchyDepth -gt 5 }).Count
    $WithInclExcl  = ($Results | Where-Object { $_.IncludeRuleCount -gt 0 -or $_.ExcludeRuleCount -gt 0 }).Count

    Write-Host ""
    Write-Host "  Nouvelles collections (J-$LastDays)         : $($Results.Count)"
    Write-Host "  Dont avec rafraîchissement incrémental : $Incremental"  -ForegroundColor $(if ($Incremental -gt 0) { "Yellow" } else { "White" })
    Write-Host "  Dont profondeur > 5                    : $DeepPlus5"    -ForegroundColor $(if ($DeepPlus5 -gt 0)   { "Yellow" } else { "White" })
    Write-Host "  Dont avec règles include/exclude       : $WithInclExcl" -ForegroundColor $(if ($WithInclExcl -gt 0) { "Yellow" } else { "White" })
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    throw
}
