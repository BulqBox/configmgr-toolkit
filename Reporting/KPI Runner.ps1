#Requires -Version 5.1
<#
.SYNOPSIS
    Orchestrateur KPI SCCM - Lance les trois collectes et produit un log d'exécution.

.PARAMETER SiteCode
    Code du site SCCM (ex: CIR)

.PARAMETER SQLServer
    Nom ou IP du serveur SQL distant (ex: SQLSRV01)

.PARAMETER OutputPath
    Dossier de dépôt des CSV. Défaut : D:\Backup\KPIs

.PARAMETER NewCollectionsDays
    Horizon de détection des nouvelles collections en jours. Défaut : 7

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
    [string]$OutputPath = "D:\Backup\KPIs",

    [Parameter(Mandatory = $false)]
    [int]$NewCollectionsDays = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Initialisation ──────────────────────────────────────────────────────────

$RunDate  = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile  = Join-Path $OutputPath "KPI_Runner_$RunDate.log"
$ScriptDir = $PSScriptRoot

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
        Name   = "Collections vides"
        Script = Join-Path $ScriptDir "KPI_EmptyCollections.ps1"
        Params = @{
            SiteCode   = $SiteCode
            SQLServer  = $SQLServer
            OutputPath = $OutputPath
        }
    },
    @{
        Name   = "Déploiements obsolètes"
        Script = Join-Path $ScriptDir "KPI_ObsoleteDeployments.ps1"
        Params = @{
            SiteCode   = $SiteCode
            SQLServer  = $SQLServer
            OutputPath = $OutputPath
        }
    },
    @{
        Name   = "Nouvelles collections"
        Script = Join-Path $ScriptDir "KPI_NewCollections.ps1"
        Params = @{
            SiteCode      = $SiteCode
            SQLServer     = $SQLServer
            OutputPath    = $OutputPath
            LastDays      = $NewCollectionsDays
        }
    }
)

# ─── Exécution ───────────────────────────────────────────────────────────────

$Results = @()

foreach ($Item in $Scripts) {

    if (-not (Test-Path $Item.Script)) {
        Write-Log "Script introuvable : $($Item.Script)" -Level ERROR
        $Results += [PSCustomObject]@{ Name = $Item.Name; Status = "ERREUR"; Detail = "Fichier absent" }
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
        $Results += [PSCustomObject]@{ Name = $Item.Name; Status = "OK"; Detail = "${Duration}s" }
    }
    catch {
        $Duration = [math]::Round(((Get-Date) - $Start).TotalSeconds, 1)
        Write-Log "$($Item.Name) ÉCHOUÉ : $_" -Level ERROR
        $Results += [PSCustomObject]@{ Name = $Item.Name; Status = "ERREUR"; Detail = $_.Exception.Message }
    }
}

# ─── Résumé ──────────────────────────────────────────────────────────────────

Write-Log "=== Résumé d'exécution ===" -Level INFO
$Results | ForEach-Object {
    $lvl = if ($_.Status -eq "OK") { "OK" } else { "ERROR" }
    Write-Log "  [$($_.Status)] $($_.Name) — $($_.Detail)" -Level $lvl
}

$Errors = $Results | Where-Object { $_.Status -ne "OK" }
if ($Errors.Count -gt 0) {
    Write-Log "$($Errors.Count) script(s) en erreur. Consulter le log : $LogFile" -Level WARN
    exit 1
}

Write-Log "=== KPI Runner terminé avec succès ===" -Level OK
exit 0
