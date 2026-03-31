#Requires -Version 5.1
<#
.SYNOPSIS
    KPI - Collections vides : dernière machine vue + déploiements associés.

.DESCRIPTION
    Interroge directement la base SQL du site SCCM.
    Produit un CSV : une ligne par collection vide avec
      - Nom, ID, collection limitante
      - Date de création, date du dernier rafraîchissement
      - Nombre de jours depuis la dernière machine vue
      - Présence et nombre de déploiements actifs ciblant cette collection

.PARAMETER SiteCode
    Code du site SCCM (ex: CIR)

.PARAMETER SQLServer
    Serveur SQL distant (ex: SQLSRV01)

.PARAMETER OutputPath
    Dossier de dépôt du CSV. Défaut : D:\Backup\KPIs

.EXAMPLE
    .\KPI_EmptyCollections.ps1 -SiteCode CIR -SQLServer SQLSRV01
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [string]$SQLServer,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "D:\Backup\KPIs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Database  = "CM_$SiteCode"
$RunDate   = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputCSV = Join-Path $OutputPath "KPI_EmptyCollections_$RunDate.csv"

# ─── Requête SQL ─────────────────────────────────────────────────────────────
#
# Logique :
#   - On sélectionne les collections Device (CollectionType = 2) avec MemberCount = 0
#   - On joint la table des déploiements pour compter ceux qui ciblent ces collections
#   - On expose la date du dernier changement de membres pour calculer
#     le nombre de jours depuis la dernière machine vue
#   - On exclut les collections système intégrées (IsBuiltIn = 1)
#
$Query = @"
SELECT
    col.CollectionID                                        AS CollectionID,
    col.Name                                               AS CollectionName,
    col.LimitToCollectionName                              AS LimitingCollection,
    col.CreatedBy                                          AS CreatedBy,
    CONVERT(VARCHAR(19), col.CollectionDateCreated, 120)   AS DateCreated,
    CONVERT(VARCHAR(19), col.LastMemberChangeTime, 120)    AS LastMemberChange,
    DATEDIFF(DAY,
        col.LastMemberChangeTime,
        GETDATE())                                         AS DaysSinceLastMember,
    CONVERT(VARCHAR(19), col.LastRefreshTime, 120)         AS LastRefresh,
    COUNT(dep.AssignmentID)                                AS DeploymentCount,
    ISNULL(
        STUFF((
            SELECT DISTINCT '; ' + d2.AssignmentName
            FROM v_DeploymentSummary d2
            WHERE d2.CollectionID = col.CollectionID
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, '')
    , '')                                                   AS DeploymentNames
FROM
    v_Collection col
    LEFT JOIN v_DeploymentSummary dep
        ON col.CollectionID = dep.CollectionID
WHERE
    col.CollectionType = 2          -- Device collections uniquement
    AND col.MemberCount  = 0
    AND col.IsBuiltIn    = 0        -- Exclure les collections système
GROUP BY
    col.CollectionID,
    col.Name,
    col.LimitToCollectionName,
    col.CreatedBy,
    col.CollectionDateCreated,
    col.LastMemberChangeTime,
    col.LastRefreshTime
ORDER BY
    DaysSinceLastMember DESC,
    DeploymentCount      DESC;
"@

# ─── Exécution ───────────────────────────────────────────────────────────────

try {
    Write-Host "[INFO] Connexion à $SQLServer / $Database" -ForegroundColor Cyan

    $Results = Invoke-Sqlcmd `
        -ServerInstance $SQLServer `
        -Database       $Database `
        -Query          $Query `
        -QueryTimeout   120 `
        -ErrorAction    Stop

    Write-Host "[INFO] $($Results.Count) collections vides trouvées." -ForegroundColor Cyan

    # Création du dossier si absent
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Export CSV
    $Results |
        Select-Object CollectionID, CollectionName, LimitingCollection,
                      CreatedBy, DateCreated, LastMemberChange,
                      DaysSinceLastMember, LastRefresh,
                      DeploymentCount, DeploymentNames |
        Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8 -Delimiter ";"

    Write-Host "[OK] CSV exporté : $OutputCSV" -ForegroundColor Green

    # Résumé console
    $WithDeploy    = ($Results | Where-Object { $_.DeploymentCount -gt 0 }).Count
    $OlderThan90   = ($Results | Where-Object { $_.DaysSinceLastMember -gt 90 }).Count
    $OlderThan365  = ($Results | Where-Object { $_.DaysSinceLastMember -gt 365 }).Count

    Write-Host ""
    Write-Host "  Collections vides totales        : $($Results.Count)"
    Write-Host "  Dont avec déploiement(s) actif(s): $WithDeploy"  -ForegroundColor Yellow
    Write-Host "  Vides depuis > 90 jours          : $OlderThan90"
    Write-Host "  Vides depuis > 365 jours         : $OlderThan365" -ForegroundColor Red
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    throw
}
