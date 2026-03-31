#Requires -Version 5.1
<#
.SYNOPSIS
    KPI - Déploiements obsolètes : créés il y a plus de 3 ans.

.DESCRIPTION
    Interroge directement la base SQL du site SCCM.
    Produit un CSV : un déploiement par ligne avec
      - Nom du déploiement, type, collection cible
      - Date de création, âge en jours
      - Date et état du dernier changement d'état (Status Message)
      - Nombre de machines ciblées, taux de succès

.PARAMETER SiteCode
    Code du site SCCM (ex: CIR)

.PARAMETER SQLServer
    Serveur SQL distant (ex: SQLSRV01)

.PARAMETER OutputPath
    Dossier de dépôt du CSV. Défaut : D:\Backup\KPIs

.PARAMETER ObsoleteThresholdYears
    Seuil en années pour qualifier un déploiement d'obsolète. Défaut : 3

.EXAMPLE
    .\KPI_ObsoleteDeployments.ps1 -SiteCode CIR -SQLServer SQLSRV01
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
    [int]$ObsoleteThresholdYears = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Database  = "CM_$SiteCode"
$RunDate   = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputCSV = Join-Path $OutputPath "KPI_ObsoleteDeployments_$RunDate.csv"

# ─── Requête SQL ─────────────────────────────────────────────────────────────
#
# Logique :
#   - On sélectionne depuis v_DeploymentSummary les déploiements dont
#     la date de création dépasse le seuil (3 ans par défaut)
#   - On joint v_Collection pour récupérer les infos de la collection cible
#   - On récupère la date du dernier changement d'état via v_StatusMessage
#     (MessageID 30006 = package/TS deployment creation,
#      on prend le MAX(Time) sur ce déploiement pour avoir la dernière activité)
#   - FeatureType : 1=App, 2=Package, 5=SU, 6=Baseline, 7=TS
#
$Query = @"
SELECT
    dep.AssignmentID                                        AS DeploymentID,
    dep.AssignmentName                                     AS DeploymentName,
    CASE dep.FeatureType
        WHEN 1 THEN 'Application'
        WHEN 2 THEN 'Package/Programme'
        WHEN 5 THEN 'Software Update'
        WHEN 6 THEN 'Baseline'
        WHEN 7 THEN 'Task Sequence'
        ELSE        'Autre (' + CAST(dep.FeatureType AS VARCHAR) + ')'
    END                                                    AS DeploymentType,
    dep.CollectionID                                       AS CollectionID,
    dep.CollectionName                                     AS CollectionName,
    col.MemberCount                                        AS CollectionMemberCount,
    CONVERT(VARCHAR(19), dep.CreationTime, 120)            AS DateCreated,
    DATEDIFF(DAY, dep.CreationTime, GETDATE())             AS AgeInDays,
    dep.NumberTargeted                                     AS Targeted,
    dep.NumberSuccess                                      AS Success,
    dep.NumberErrors                                       AS Errors,
    dep.NumberInProgress                                   AS InProgress,
    CASE
        WHEN dep.NumberTargeted > 0
        THEN CAST(
            ROUND(100.0 * dep.NumberSuccess / dep.NumberTargeted, 1)
            AS DECIMAL(5,1))
        ELSE 0
    END                                                    AS SuccessRatePct,
    dep.Enabled                                            AS IsEnabled,
    -- Dernier changement d'état enregistré dans les status messages
    CONVERT(VARCHAR(19), lastmsg.LastStatusTime, 120)      AS LastStatusChange,
    DATEDIFF(DAY, lastmsg.LastStatusTime, GETDATE())       AS DaysSinceLastStatus
FROM
    v_DeploymentSummary dep
    LEFT JOIN v_Collection col
        ON dep.CollectionID = col.CollectionID
    -- Sous-requête : date du dernier status message lié à ce déploiement
    LEFT JOIN (
        SELECT
            ads.AssignmentID,
            MAX(sm.Time) AS LastStatusTime
        FROM
            v_StatusMessage sm
            INNER JOIN v_AssignmentState ads
                ON sm.MachineName = ads.MachineName  -- on lie par machine
        WHERE
            sm.Component  = 'SMS_Distribution_Manager'
            OR sm.Component = 'SMS_Policy_Provider'
        GROUP BY
            ads.AssignmentID
    ) lastmsg
        ON dep.AssignmentID = lastmsg.AssignmentID
WHERE
    dep.CreationTime < DATEADD(YEAR, -$ObsoleteThresholdYears, GETDATE())
ORDER BY
    AgeInDays             DESC,
    dep.NumberTargeted    DESC;
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

    Write-Host "[INFO] $($Results.Count) déploiements obsolètes trouvés (> $ObsoleteThresholdYears ans)." -ForegroundColor Cyan

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $Results |
        Select-Object DeploymentID, DeploymentName, DeploymentType,
                      CollectionID, CollectionName, CollectionMemberCount,
                      DateCreated, AgeInDays,
                      Targeted, Success, Errors, InProgress, SuccessRatePct,
                      IsEnabled, LastStatusChange, DaysSinceLastStatus |
        Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8 -Delimiter ";"

    Write-Host "[OK] CSV exporté : $OutputCSV" -ForegroundColor Green

    # Résumé console
    $Disabled        = ($Results | Where-Object { $_.IsEnabled -eq $false }).Count
    $EmptyCollection = ($Results | Where-Object { $_.CollectionMemberCount -eq 0 }).Count
    $NoActivity      = ($Results | Where-Object { $_.DaysSinceLastStatus -gt 365 -or $null -eq $_.LastStatusChange }).Count

    Write-Host ""
    Write-Host "  Déploiements obsolètes totaux          : $($Results.Count)"
    Write-Host "  Dont désactivés                        : $Disabled"
    Write-Host "  Dont sur collection vide               : $EmptyCollection" -ForegroundColor Yellow
    Write-Host "  Dont sans activité depuis > 1 an       : $NoActivity"     -ForegroundColor Red
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    throw
}
