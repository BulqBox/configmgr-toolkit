#Requires -Version 5.1
#Requires -Modules ConfigurationManager

<#
.SYNOPSIS
    Script d'initialisation du système de monitoring SCCM
    
.DESCRIPTION
    - Vérifie les prérequis
    - Crée la structure de fichiers
    - Capture la baseline initiale (T0)
    - Configure la tâche planifiée de collecte horaire
    
.PARAMETER SiteCode
    Code du site SCCM (ex: PS1)
    
.PARAMETER SetupScheduledTask
    Créer la tâche planifiée pour collecte horaire
    
.EXAMPLE
    .\Initialize-Monitoring.ps1 -SiteCode "PS1" -SetupScheduledTask
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteCode,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupScheduledTask,
    
    [Parameter(Mandatory=$false)]
    [string]$MonitoringPath = "C:\SCCM_Monitoring"
)

#region Configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Chemins
$DataPath = Join-Path $MonitoringPath "Data"
$ConfigPath = Join-Path $MonitoringPath "Config"
$ScriptsPath = Join-Path $MonitoringPath "Scripts"
$LogsPath = Join-Path $MonitoringPath "Logs"
$ReportsPath = Join-Path $MonitoringPath "Reports"

# Fichiers
$MetricsFile = Join-Path $DataPath "SCCM_Metrics_History.csv"
$BaselineFile = Join-Path $DataPath "SCCM_Baseline_Initial.json"
$ThresholdsFile = Join-Path $ConfigPath "thresholds.json"
$LogFile = Join-Path $LogsPath "Initialize_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
#endregion

#region Fonctions utilitaires
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    # Écrire dans le fichier
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    
    # Afficher à l'écran
    switch ($Level) {
        "INFO"    { Write-Host $Message -ForegroundColor White }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
    }
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." -Level INFO
    
    $issues = @()
    
    # Vérifier les modules
    try {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
        Write-Log "✓ Module ConfigurationManager chargé" -Level SUCCESS
    } catch {
        $issues += "Module ConfigurationManager non disponible"
    }
    
    # Vérifier la connexion au site
    try {
        $SiteProvider = Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue
        if (!$SiteProvider) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME -ErrorAction Stop | Out-Null
        }
        Set-Location "$($SiteCode):" -ErrorAction Stop
        
        $SiteInfo = Get-CMSite -SiteCode $SiteCode
        Write-Log "✓ Connecté au site : $($SiteInfo.SiteName)" -Level SUCCESS
        
        # Retour au système de fichiers
        Set-Location C:\
        
    } catch {
        $issues += "Impossible de se connecter au site SCCM $SiteCode"
    }
    
    # Vérifier les permissions
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $issues += "Droits administrateur requis"
    } else {
        Write-Log "✓ Droits administrateur validés" -Level SUCCESS
    }
    
    if ($issues.Count -gt 0) {
        Write-Log "ERREURS détectées :" -Level ERROR
        $issues | ForEach-Object { Write-Log "  - $_" -Level ERROR }
        return $false
    }
    
    return $true
}

function Initialize-FolderStructure {
    Write-Log "`nCréation de la structure de dossiers..." -Level INFO
    
    $folders = @($DataPath, $ConfigPath, $ScriptsPath, $LogsPath, $ReportsPath)
    
    foreach ($folder in $folders) {
        if (!(Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Write-Log "✓ Créé : $folder" -Level SUCCESS
        } else {
            Write-Log "  Existe déjà : $folder" -Level INFO
        }
    }
}

function Initialize-MetricsFile {
    Write-Log "`nInitialisation du fichier de métriques..." -Level INFO
    
    if (Test-Path $MetricsFile) {
        Write-Log "⚠ Le fichier de métriques existe déjà : $MetricsFile" -Level WARNING
        Write-Log "  Les nouvelles données seront ajoutées" -Level INFO
    } else {
        # Créer le header CSV
        $header = "Timestamp,MetricCategory,MetricName,MetricValue,MetricUnit,Threshold,Status,Notes"
        Set-Content -Path $MetricsFile -Value $header -Encoding UTF8
        Write-Log "✓ Fichier de métriques créé" -Level SUCCESS
    }
}

function Capture-Baseline {
    Write-Log "`nCapture de la baseline initiale..." -Level INFO
    
    try {
        # Charger la configuration des seuils
        $thresholds = Get-Content $ThresholdsFile -Raw | ConvertFrom-Json
        
        # Se connecter au site SCCM
        Set-Location "$($SiteCode):"
        
        # Collecter les métriques de base
        Write-Log "  Collecte des collections..." -Level INFO
        $collections = Get-CMCollection
        
        $baseline = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SiteCode = $SiteCode
            Environment = @{
                SiteServerName = $env:COMPUTERNAME
                Version = (Get-CMSite -SiteCode $SiteCode).Version
            }
            Metrics = @{
                Collections = @{
                    TotalCount = $collections.Count
                    DeviceCollections = ($collections | Where-Object { $_.CollectionType -eq 2 }).Count
                    UserCollections = ($collections | Where-Object { $_.CollectionType -eq 1 }).Count
                    IncrementalCount = ($collections | Where-Object { $_.RefreshType -in @(4, 6) }).Count
                    EmptyCollections = ($collections | Where-Object { $_.MemberCount -eq 0 }).Count
                }
                Deployments = @{
                    TotalCount = (Get-CMDeployment).Count
                }
            }
            ThresholdsVersion = $thresholds.version
            Purpose = "Baseline initiale avant remédiation - Point de référence T0"
        }
        
        # Sauvegarder la baseline
        $baseline | ConvertTo-Json -Depth 10 | Out-File $BaselineFile -Encoding UTF8
        Write-Log "✓ Baseline sauvegardée : $BaselineFile" -Level SUCCESS
        
        # Afficher un résumé
        Write-Log "`n=== RÉSUMÉ DE LA BASELINE ===" -Level INFO
        Write-Log "Collections totales      : $($baseline.Metrics.Collections.TotalCount)" -Level INFO
        Write-Log "Collections incrémentales: $($baseline.Metrics.Collections.IncrementalCount)" -Level INFO
        Write-Log "Collections vides        : $($baseline.Metrics.Collections.EmptyCollections)" -Level INFO
        Write-Log "Déploiements actifs      : $($baseline.Metrics.Deployments.TotalCount)" -Level INFO
        
        # Retour au système de fichiers
        Set-Location C:\
        
        return $true
        
    } catch {
        Write-Log "ERREUR lors de la capture de la baseline : $_" -Level ERROR
        Set-Location C:\
        return $false
    }
}

function Setup-ScheduledTask {
    Write-Log "`nConfiguration de la tâche planifiée..." -Level INFO
    
    try {
        $taskName = "SCCM-Monitoring-Hourly"
        $collectScript = Join-Path $ScriptsPath "Collect-SCCMMetrics.ps1"
        
        # Vérifier si le script de collecte existe
        if (!(Test-Path $collectScript)) {
            Write-Log "⚠ Script de collecte non trouvé : $collectScript" -Level WARNING
            Write-Log "  Vous devrez créer la tâche planifiée manuellement" -Level WARNING
            return $false
        }
        
        # Vérifier si la tâche existe déjà
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log "⚠ La tâche planifiée existe déjà : $taskName" -Level WARNING
            $response = Read-Host "Voulez-vous la recréer ? (O/N)"
            if ($response -ne "O" -and $response -ne "o") {
                Write-Log "  Tâche planifiée non modifiée" -Level INFO
                return $true
            }
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # Créer l'action
        $action = New-ScheduledTaskAction `
            -Execute "PowerShell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$collectScript`" -SiteCode `"$SiteCode`""
        
        # Créer le trigger (toutes les heures)
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
        
        # Créer les paramètres
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        
        # Créer la tâche (s'exécute avec le compte système)
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -User "SYSTEM" `
            -Description "Collecte horaire des métriques SCCM pour monitoring des performances" `
            -RunLevel Highest | Out-Null
        
        Write-Log "✓ Tâche planifiée créée : $taskName" -Level SUCCESS
        Write-Log "  Fréquence : Toutes les heures" -Level INFO
        Write-Log "  Compte : SYSTEM" -Level INFO
        
        return $true
        
    } catch {
        Write-Log "ERREUR lors de la création de la tâche planifiée : $_" -Level ERROR
        return $false
    }
}
#endregion

#region Exécution principale
function Main {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║           INITIALISATION DU MONITORING SCCM                    ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Log "Début de l'initialisation..." -Level INFO
    Write-Log "Site Code        : $SiteCode" -Level INFO
    Write-Log "Chemin monitoring: $MonitoringPath" -Level INFO
    
    # 1. Vérifier les prérequis
    if (!(Test-Prerequisites)) {
        Write-Log "`n❌ Initialisation annulée : prérequis non satisfaits" -Level ERROR
        exit 1
    }
    
    # 2. Créer la structure de dossiers
    Initialize-FolderStructure
    
    # 3. Initialiser le fichier de métriques
    Initialize-MetricsFile
    
    # 4. Capturer la baseline
    if (!(Capture-Baseline)) {
        Write-Log "`n⚠ Initialisation partielle : baseline non capturée" -Level WARNING
    }
    
    # 5. Configurer la tâche planifiée si demandé
    if ($SetupScheduledTask) {
        Setup-ScheduledTask
    } else {
        Write-Log "`nℹ Tâche planifiée non configurée (utilisez -SetupScheduledTask)" -Level INFO
    }
    
    # Résumé final
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                    ✅ INITIALISATION TERMINÉE                  ║
╠════════════════════════════════════════════════════════════════╣
║ Structure créée   : $MonitoringPath
║ Fichier métriques : $MetricsFile
║ Baseline          : $BaselineFile
║ Log               : $LogFile
╚════════════════════════════════════════════════════════════════╝

PROCHAINES ÉTAPES :
1. Ajuster les seuils dans : $ThresholdsFile
2. Exécuter la première collecte : .\Collect-SCCMMetrics.ps1 -SiteCode "$SiteCode"
3. Configurer la tâche planifiée : .\Initialize-Monitoring.ps1 -SiteCode "$SiteCode" -SetupScheduledTask
4. Vérifier les données : Import-Csv "$MetricsFile"

"@ -ForegroundColor Green

    Write-Log "Initialisation terminée avec succès" -Level SUCCESS
}

# Exécution
Main
#endregion
