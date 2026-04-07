#Requires -Version 5.1
<#
.SYNOPSIS
    Orchestrateur KPI SCCM - Lance les collectes et historise une ligne de synthèse.

.DESCRIPTION
    Exécute séquentiellement :
      1. KPI_EmptyCollections.ps1
      2. KPI_ObsoleteDeployments.ps1
    Puis lit les CSV produits et ajoute une ligne dans KPI_History.csv —
    un fichier persistant qui s'enrichit à chaque exécution quotidienne.

.PARAMETER SiteCode
    Code du site SCCM (ex: CIR)

.PARAMETER SQLServer
    Nom ou IP du serveur SQL distant (ex: SQLSRV01)

.PARAMETER OutputPath
    Dossier de dépôt des CSV et du fichier d'historique. Défaut : D:\Backup\KPIs

.PARAMETER WhatIf
    Simulation : affiche ce qui serait fait sans écrire de fichier.

.EXAMPLE
    .\KPI_Runner.ps1 -SiteCode CIR -SQLServer SQLSRV01
    .\KPI_Runner.ps1 -SiteCode CIR -SQLServer SQLSRV01 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
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

# ─── Initialisation ──────────────────────────────────────────────────────────

$RunDate     = Get-Date -Format "yyyyMMdd_HHmmss"
$RunDateISO  = Get-Date -Format "yyyy-MM-dd"
$LogFile     = Join-Path $OutputPath "KPI_Runner_$RunDate.log"
$HistoryFile = Join-Path $OutputPath "KPI_History.csv"
$ScriptDir   = $PSScriptRoot

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","OK")]
        [string]$Level = "INFO"
    )
    $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $entry -ForegroundColor $(switch ($Level) {
        "OK"    { "Green"  }
        "WARN"  { "Yellow" }
        "ERROR" { "Red"    }
        default { "White"  }
    })
    if (-not $WhatIfPreference) {
        Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    }
}

# ─── Création du dossier de sortie ───────────────────────────────────────────

if (-not (Test-Path $OutputPath)) {
    if ($PSCmdlet.ShouldProcess($OutputPath, "Créer le dossier de sortie")) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Log "Dossier créé : $OutputPath" -Level OK
    }
}

Write-Log "=== Démarrage KPI Runner === Site: $SiteCode | SQL: $SQLServer" -Level INFO

# ─── Définition des scripts enfants ──────────────────────────────────────────

$Scripts = @(
    @{
        Name      = "Collections vides"
        Script    = Join-Path $ScriptDir "KPI_EmptyCollections.ps1"
        OutputKey = "EmptyCollections"
        Params    = @{
            SiteCode   = $SiteCode
            SQLServer  = $SQLServer
            OutputPath = $OutputPath
        }
    },
    @{
        Name      = "Déploiements obsolètes"
        Script    = Join-Path $ScriptDir "KPI_ObsoleteDeployments.ps1"
        OutputKey = "ObsoleteDeployments"
        Params    = @{
            SiteCode   = $SiteCode
            SQLServer  = $SQLServer
            OutputPath = $OutputPath
        }
    }
)

# ─── Exécution des scripts enfants ───────────────────────────────────────────

$RunResults  = @()
$ProducedCSV = @{}

foreach ($Item in $Scripts) {

    if (-not (Test-Path $Item.Script)) {
        Write-Log "Script introuvable : $($Item.Script)" -Level ERROR
        $RunResults += [PSCustomObject]@{ Name = $Item.Name; Status = "ERREUR"; Detail = "Fichier absent" }
        continue
    }

    Write-Log "Lancement : $($Item.Name)" -Level INFO
    $Start = Get-Date

    try {
        if ($PSCmdlet.ShouldProcess($Item.Name, "Exécuter le script KPI")) {
            & $Item.Script @($Item.Params) -ErrorAction Stop
        }

        $Duration = [math]::Round(((Get-Date) - $Start).TotalSeconds, 1)
        Write-Log "$($Item.Name) terminé en ${Duration}s" -Level OK
        $RunResults += [PSCustomObject]@{ Name = $Item.Name; Status = "OK"; Detail = "${Duration}s" }

        $Pattern = "KPI_$($Item.OutputKey)_*.csv"
        $Latest  = Get-ChildItem -Path $OutputPath -Filter $Pattern |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1
        if ($Latest) {
            $ProducedCSV[$Item.OutputKey] = $Latest.FullName
            Write-Log "CSV identifié : $($Latest.Name)" -Level INFO
        }
    }
    catch {
        $Duration = [math]::Round(((Get-Date) - $Start).TotalSeconds, 1)
        Write-Log "$($Item.Name) ÉCHOUÉ : $_" -Level ERROR
        $RunResults += [PSCustomObject]@{ Name = $Item.Name; Status = "ERREUR"; Detail = $_.Exception.Message }
    }
}

# ─── Fonction d'ajout dans l'historique ──────────────────────────────────────

function Add-HistoryRow {
    param([PSCustomObject]$Row)
    $exists = Test-Path $HistoryFile
    if (-not $exists) {
        $Row | Export-Csv -Path $HistoryFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        Write-Log "Fichier d'historique créé : $HistoryFile" -Level OK
    }
    else {
        $Row |
            ConvertTo-Csv -NoTypeInformation -Delimiter ";" |
            Select-Object -Skip 1 |
            Add-Content -Path $HistoryFile -Encoding UTF8
        Write-Log "Ligne ajoutée dans l'historique : $HistoryFile" -Level OK
    }
}

# ─── Synthèse et historisation ───────────────────────────────────────────────

$AllScriptsOK = ($RunResults | Where-Object { $_.Status -ne "OK" }).Count -eq 0

if ($AllScriptsOK -and $ProducedCSV.Count -eq 2) {

    Write-Log "Calcul de la synthèse..." -Level INFO

    try {
        # ── Collections vides ──
        $EmptyData = Import-Csv -Path $ProducedCSV["EmptyCollections"] -Delimiter ";"

        $Empty_Total          = $EmptyData.Count
        $Empty_WithDeployment = ($EmptyData | Where-Object { [int]$_.DeploymentCount -gt 0 }).Count
        $Empty_Over90Days     = ($EmptyData | Where-Object { [int]$_.DaysSinceLastMember -gt 90 }).Count
        $Empty_Over365Days    = ($EmptyData | Where-Object { [int]$_.DaysSinceLastMember -gt 365 }).Count

        # ── Déploiements obsolètes ──
        $ObsoleteData = Import-Csv -Path $ProducedCSV["ObsoleteDeployments"] -Delimiter ";"

        $Obsolete_Total        = $ObsoleteData.Count
        $Obsolete_OnEmptyColl  = ($ObsoleteData | Where-Object { [int]$_.CollectionMemberCount -eq 0 }).Count
        $Obsolete_Disabled     = ($ObsoleteData | Where-Object { $_.IsEnabled -eq "False" }).Count
        $Obsolete_NoActivity1Y = ($ObsoleteData | Where-Object {
            $_.DaysSinceLastStatus -eq "" -or
            $_.DaysSinceLastStatus -eq "NULL" -or
            ([int]$_.DaysSinceLastStatus -gt 365)
        }).Count

        # ── Ligne de synthèse ──
        $SummaryRow = [PSCustomObject]@{
            Date                  = $RunDateISO
            Empty_Total           = $Empty_Total
            Empty_WithDeployment  = $Empty_WithDeployment
            Empty_Over90Days      = $Empty_Over90Days
            Empty_Over365Days     = $Empty_Over365Days
            Obsolete_Total        = $Obsolete_Total
            Obsolete_OnEmptyColl  = $Obsolete_OnEmptyColl
            Obsolete_Disabled     = $Obsolete_Disabled
            Obsolete_NoActivity1Y = $Obsolete_NoActivity1Y
            RunStatus             = "OK"
        }

        if ($PSCmdlet.ShouldProcess($HistoryFile, "Ajouter une ligne de synthèse")) {
            Add-HistoryRow -Row $SummaryRow
        }

        # ── Affichage console ──
        Write-Log "--- Synthèse du jour ($RunDateISO) ---" -Level INFO
        Write-Log "  Collections vides totales      : $Empty_Total"           -Level INFO
        Write-Log "  Dont avec déploiement(s)       : $Empty_WithDeployment"  -Level $(if ($Empty_WithDeployment -gt 0)   { "WARN" } else { "INFO" })
        Write-Log "  Vides depuis > 90 jours        : $Empty_Over90Days"      -Level INFO
        Write-Log "  Vides depuis > 365 jours       : $Empty_Over365Days"     -Level $(if ($Empty_Over365Days -gt 0)     { "WARN" } else { "INFO" })
        Write-Log "  Déploiements obsolètes totaux  : $Obsolete_Total"        -Level INFO
        Write-Log "  Dont sur collection vide       : $Obsolete_OnEmptyColl"  -Level $(if ($Obsolete_OnEmptyColl -gt 0)  { "WARN" } else { "INFO" })
        Write-Log "  Dont désactivés                : $Obsolete_Disabled"     -Level INFO
        Write-Log "  Dont sans activité > 1 an      : $Obsolete_NoActivity1Y" -Level $(if ($Obsolete_NoActivity1Y -gt 0) { "WARN" } else { "INFO" })
    }
    catch {
        Write-Log "Erreur lors de la synthèse : $_" -Level ERROR
        $ErrorRow = [PSCustomObject]@{
            Date                  = $RunDateISO
            Empty_Total           = ""; Empty_WithDeployment  = ""
            Empty_Over90Days      = ""; Empty_Over365Days     = ""
            Obsolete_Total        = ""; Obsolete_OnEmptyColl  = ""
            Obsolete_Disabled     = ""; Obsolete_NoActivity1Y = ""
            RunStatus             = "ERREUR_SYNTHESE"
        }
        if ($PSCmdlet.ShouldProcess($HistoryFile, "Ajouter une ligne d'erreur")) {
            Add-HistoryRow -Row $ErrorRow
        }
    }
}
else {
    Write-Log "Synthèse ignorée — un ou plusieurs scripts en erreur." -Level WARN
    $PartialRow = [PSCustomObject]@{
        Date                  = $RunDateISO
        Empty_Total           = ""; Empty_WithDeployment  = ""
        Empty_Over90Days      = ""; Empty_Over365Days     = ""
        Obsolete_Total        = ""; Obsolete_OnEmptyColl  = ""
        Obsolete_Disabled     = ""; Obsolete_NoActivity1Y = ""
        RunStatus             = "PARTIEL"
    }
    if ($PSCmdlet.ShouldProcess($HistoryFile, "Ajouter une ligne partielle")) {
        Add-HistoryRow -Row $PartialRow
    }
}

# ─── Résumé d'exécution ──────────────────────────────────────────────────────

Write-Log "=== Résumé d'exécution ===" -Level INFO
$RunResults | ForEach-Object {
    $lvl = if ($_.Status -eq "OK") { "OK" } else { "ERROR" }
    Write-Log "  [$($_.Status)] $($_.Name) — $($_.Detail)" -Level $lvl
}

$Errors = $RunResults | Where-Object { $_.Status -ne "OK" }
if ($Errors.Count -gt 0) {
    Write-Log "$($Errors.Count) script(s) en erreur. Consulter le log : $LogFile" -Level WARN
    exit 1
}

Write-Log "=== KPI Runner terminé avec succès ===" -Level OK
exit 0
