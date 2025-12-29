#Requires -Version 5.1
#Requires -Modules ConfigurationManager

<#
.SYNOPSIS
    Collecte horaire des métriques SCCM pour monitoring des performances
    
.DESCRIPTION
    Collecte tous les KPIs définis et les enregistre dans le fichier CSV historique
    avec calcul automatique des statuts selon les seuils configurables
    
.PARAMETER SiteCode
    Code du site SCCM
    
.PARAMETER MonitoringPath
    Chemin racine du monitoring (par défaut C:\SCCM_Monitoring)
    
.EXAMPLE
    .\Collect-SCCMMetrics.ps1 -SiteCode "PS1"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteCode,
    
    [Parameter(Mandatory=$false)]
    [string]$MonitoringPath = "C:\SCCM_Monitoring",
    
    [Parameter(Mandatory=$false)]
    [string]$SQLServer
)

#region Configuration
$ErrorActionPreference = "Continue"  # Continue pour ne pas bloquer sur une métrique
$WarningPreference = "SilentlyContinue"

# Chemins
$DataPath = Join-Path $MonitoringPath "Data"
$ConfigPath = Join-Path $MonitoringPath "Config"
$LogsPath = Join-Path $MonitoringPath "Logs"

# Fichiers
$MetricsFile = Join-Path $DataPath "SCCM_Metrics_History.csv"
$ThresholdsFile = Join-Path $ConfigPath "thresholds.json"
$LogFile = Join-Path $LogsPath "Collection_$(Get-Date -Format 'yyyyMMdd').log"

# Variable globale pour les métriques collectées
$script:CollectedMetrics = @()
$script:StartTime = Get-Date
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
    
    try {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
    
    # Afficher seulement si exécuté manuellement (pas en tâche planifiée)
    if ([Environment]::UserInteractive) {
        switch ($Level) {
            "INFO"    { Write-Host $Message -ForegroundColor White }
            "WARNING" { Write-Host $Message -ForegroundColor Yellow }
            "ERROR"   { Write-Host $Message -ForegroundColor Red }
            "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        }
    }
}

function Get-ThresholdStatus {
    param(
        [double]$Value,
        [double]$Warning,
        [double]$Critical,
        [bool]$InverseLogic = $false
    )
    
    if ($InverseLogic) {
        # Pour les métriques où plus bas = problème (ex: taux de succès)
        if ($Value -le $Critical) { return "CRITICAL" }
        elseif ($Value -le $Warning) { return "WARNING" }
        else { return "OK" }
    } else {
        # Pour les métriques où plus haut = problème (cas standard)
        if ($Value -ge $Critical) { return "CRITICAL" }
        elseif ($Value -ge $Warning) { return "WARNING" }
        else { return "OK" }
    }
}

function Add-Metric {
    param(
        [string]$Category,
        [string]$Name,
        $Value,
        [string]$Unit,
        $Threshold,
        [string]$Status,
        [string]$Notes = ""
    )
    
    $script:CollectedMetrics += [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        MetricCategory = $Category
        MetricName = $Name
        MetricValue = $Value
        MetricUnit = $Unit
        Threshold = $Threshold
        Status = $Status
        Notes = $Notes
    }
}

function Connect-SCCMSite {
    try {
        # Import module
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
        
        # Connexion au site
        $SiteProvider = Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue
        if (!$SiteProvider) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME -ErrorAction Stop | Out-Null
        }
        
        Set-Location "$($SiteCode):" -ErrorAction Stop
        
        # Récupérer le serveur SQL si pas fourni
        if (!$SQLServer) {
            $siteInfo = Get-CMSite -SiteCode $SiteCode
            $script:SQLServer = $siteInfo.DatabaseServerName
            $script:Database = "CM_$SiteCode"
        }
        
        Write-Log "✓ Connecté au site $SiteCode" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "ERREUR connexion SCCM : $_" -Level ERROR
        return $false
    }
}
#endregion

#region Collecte Collections
function Collect-CollectionsMetrics {
    param($Thresholds)
    
    Write-Log "Collecte des métriques Collections..." -Level INFO
    
    try {
        # Récupérer toutes les collections
        $collections = Get-CMCollection -ErrorAction Stop
        $totalCount = $collections.Count
        
        # Total Collections
        $threshold = $Thresholds.Collections.TotalCount
        $status = Get-ThresholdStatus -Value $totalCount -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Collections" -Name "TotalCount" -Value $totalCount -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        # Collections incrémentales (RefreshType 4 = Incremental, 6 = Periodic+Incremental)
        $incrementalCount = ($collections | Where-Object { $_.RefreshType -in @(4, 6) }).Count
        $threshold = $Thresholds.Collections.IncrementalCount
        $status = Get-ThresholdStatus -Value $incrementalCount -Warning $threshold.warning -Critical $threshold.critical
        $notes = if ($incrementalCount -gt 200) { "Dépasse limite Microsoft ($incrementalCount/200)" } else { "" }
        Add-Metric -Category "Collections" -Name "IncrementalCount" -Value $incrementalCount -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status -Notes $notes
        
        # Collections vides
        $emptyCollections = ($collections | Where-Object { $_.MemberCount -eq 0 }).Count
        $threshold = $Thresholds.Collections.EmptyCollections
        $status = Get-ThresholdStatus -Value $emptyCollections -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Collections" -Name "EmptyCollections" -Value $emptyCollections -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        # Collections inutilisées (sans déploiements et pas utilisées comme limitante)
        $unusedCount = 0
        foreach ($col in $collections) {
            $deployments = Get-CMDeployment -CollectionName $col.Name -ErrorAction SilentlyContinue
            $usedAsLimiting = $collections | Where-Object { $_.LimitToCollectionID -eq $col.CollectionID }
            
            if (!$deployments -and !$usedAsLimiting -and $col.MemberCount -eq 0) {
                $unusedCount++
            }
        }
        $threshold = $Thresholds.Collections.UnusedCollections
        $status = Get-ThresholdStatus -Value $unusedCount -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Collections" -Name "UnusedCollections" -Value $unusedCount -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        # Profondeur maximale et moyenne
        $depths = @()
        foreach ($col in $collections) {
            $depth = Get-CollectionDepth -CollectionID $col.CollectionID
            $depths += $depth
        }
        
        $maxDepth = ($depths | Measure-Object -Maximum).Maximum
        $avgDepth = [math]::Round(($depths | Measure-Object -Average).Average, 2)
        
        $threshold = $Thresholds.Collections.MaxDepth
        $status = Get-ThresholdStatus -Value $maxDepth -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Collections" -Name "MaxDepth" -Value $maxDepth -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        $threshold = $Thresholds.Collections.AvgDepth
        $status = Get-ThresholdStatus -Value $avgDepth -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Collections" -Name "AvgDepth" -Value $avgDepth -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        Write-Log "✓ Métriques Collections collectées" -Level SUCCESS
        
    } catch {
        Write-Log "ERREUR collecte Collections : $_" -Level ERROR
    }
}

function Get-CollectionDepth {
    param(
        [string]$CollectionID,
        [int]$CurrentDepth = 0,
        [int]$MaxDepth = 10
    )
    
    if ($CurrentDepth -ge $MaxDepth) { return $CurrentDepth }
    if ($CollectionID -in @("SMS00001", "SMS00002", "SMS00004")) { return $CurrentDepth }
    
    try {
        $col = Get-CMCollection -CollectionId $CollectionID -ErrorAction SilentlyContinue
        if ($col -and $col.LimitToCollectionID) {
            return Get-CollectionDepth -CollectionID $col.LimitToCollectionID -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
        }
    } catch {}
    
    return $CurrentDepth
}
#endregion

#region Collecte Performance
function Collect-PerformanceMetrics {
    param($Thresholds)
    
    Write-Log "Collecte des métriques Performance..." -Level INFO
    
    try {
        # Temps d'évaluation des collections (via SQL si disponible)
        if ($script:SQLServer) {
            $query = @"
SELECT 
    AVG(EvaluationLength) as AvgEvalTime,
    MAX(EvaluationLength) as MaxEvalTime,
    COUNT(CASE WHEN EvaluationLength > 300 THEN 1 END) as SlowCollections
FROM v_CollectionRuleEvaluation
WHERE LastEvaluationTime > DATEADD(hour, -24, GETDATE())
"@
            try {
                $perfData = Invoke-Sqlcmd -ServerInstance $script:SQLServer -Database $script:Database -Query $query -ErrorAction Stop
                
                # Temps moyen d'évaluation
                $avgEvalTime = [math]::Round($perfData.AvgEvalTime, 2)
                $threshold = $Thresholds.Performance.AvgEvalTime
                $status = Get-ThresholdStatus -Value $avgEvalTime -Warning $threshold.warning -Critical $threshold.critical
                Add-Metric -Category "Performance" -Name "AvgEvalTime" -Value $avgEvalTime -Unit $threshold.unit `
                    -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
                
                # Temps maximum d'évaluation
                $maxEvalTime = [math]::Round($perfData.MaxEvalTime, 2)
                $threshold = $Thresholds.Performance.MaxEvalTime
                $status = Get-ThresholdStatus -Value $maxEvalTime -Warning $threshold.warning -Critical $threshold.critical
                Add-Metric -Category "Performance" -Name "MaxEvalTime" -Value $maxEvalTime -Unit $threshold.unit `
                    -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
                
                # Collections lentes
                $slowCount = $perfData.SlowCollections
                $threshold = $Thresholds.Performance.SlowCollections
                $status = Get-ThresholdStatus -Value $slowCount -Warning $threshold.warning -Critical $threshold.critical
                Add-Metric -Category "Performance" -Name "SlowCollections" -Value $slowCount -Unit $threshold.unit `
                    -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
                
            } catch {
                Write-Log "AVERTISSEMENT : Métriques SQL Performance non disponibles : $_" -Level WARNING
            }
        }
        
        # Backlog des évaluations (via WMI)
        try {
            $namespace = "root\sms\site_$SiteCode"
            $evalQueue = Get-WmiObject -Namespace $namespace -Class SMS_CollectionEvaluator -ErrorAction SilentlyContinue
            if ($evalQueue) {
                $backlog = $evalQueue.QueueLength
                $threshold = $Thresholds.Performance.CollEvalBacklog
                $status = Get-ThresholdStatus -Value $backlog -Warning $threshold.warning -Critical $threshold.critical
                Add-Metric -Category "Performance" -Name "CollEvalBacklog" -Value $backlog -Unit $threshold.unit `
                    -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
            }
        } catch {
            Write-Log "AVERTISSEMENT : Métrique backlog non disponible" -Level WARNING
        }
        
        Write-Log "✓ Métriques Performance collectées" -Level SUCCESS
        
    } catch {
        Write-Log "ERREUR collecte Performance : $_" -Level ERROR
    }
}
#endregion

#region Collecte System
function Collect-SystemMetrics {
    param($Thresholds)
    
    Write-Log "Collecte des métriques System..." -Level INFO
    
    try {
        # CPU Site Server
        $cpuSite = (Get-Counter "\Processor(_Total)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        if ($cpuSite) {
            $cpuSite = [math]::Round($cpuSite, 2)
            $threshold = $Thresholds.System.SiteServerCPU
            $status = Get-ThresholdStatus -Value $cpuSite -Warning $threshold.warning -Critical $threshold.critical
            Add-Metric -Category "System" -Name "SiteServerCPU" -Value $cpuSite -Unit $threshold.unit `
                -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        }
        
        # Taille base de données SQL
        if ($script:SQLServer) {
            $query = @"
SELECT 
    SUM(size * 8.0 / 1024 / 1024) as SizeGB
FROM sys.master_files
WHERE database_id = DB_ID('$($script:Database)')
"@
            try {
                $dbSize = Invoke-Sqlcmd -ServerInstance $script:SQLServer -Database "master" -Query $query -ErrorAction Stop
                $sizeGB = [math]::Round($dbSize.SizeGB, 2)
                
                $threshold = $Thresholds.System.SQLDatabaseSize
                $status = Get-ThresholdStatus -Value $sizeGB -Warning $threshold.warning -Critical $threshold.critical
                Add-Metric -Category "System" -Name "SQLDatabaseSize" -Value $sizeGB -Unit $threshold.unit `
                    -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
            } catch {
                Write-Log "AVERTISSEMENT : Taille DB non disponible : $_" -Level WARNING
            }
        }
        
        Write-Log "✓ Métriques System collectées" -Level SUCCESS
        
    } catch {
        Write-Log "ERREUR collecte System : $_" -Level ERROR
    }
}
#endregion

#region Collecte Deployments
function Collect-DeploymentsMetrics {
    param($Thresholds)
    
    Write-Log "Collecte des métriques Deployments..." -Level INFO
    
    try {
        $deployments = Get-CMDeployment -ErrorAction Stop
        
        # Total déploiements actifs
        $activeCount = $deployments.Count
        $threshold = $Thresholds.Deployments.ActiveDeployments
        $status = Get-ThresholdStatus -Value $activeCount -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Deployments" -Name "ActiveDeployments" -Value $activeCount -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        # Déploiements obsolètes (> 1 an)
        $obsoleteCount = ($deployments | Where-Object { 
            $_.DeploymentTime -lt (Get-Date).AddYears(-1)
        }).Count
        $threshold = $Thresholds.Deployments.ObsoleteDeployments
        $status = Get-ThresholdStatus -Value $obsoleteCount -Warning $threshold.warning -Critical $threshold.critical
        Add-Metric -Category "Deployments" -Name "ObsoleteDeployments" -Value $obsoleteCount -Unit $threshold.unit `
            -Threshold "W:$($threshold.warning)/C:$($threshold.critical)" -Status $status
        
        Write-Log "✓ Métriques Deployments collectées" -Level SUCCESS
        
    } catch {
        Write-Log "ERREUR collecte Deployments : $_" -Level ERROR
    }
}
#endregion

#region Sauvegarde des métriques
function Save-Metrics {
    try {
        # Ajouter au fichier CSV
        foreach ($metric in $script:CollectedMetrics) {
            $line = "$($metric.Timestamp),$($metric.MetricCategory),$($metric.MetricName),$($metric.MetricValue),$($metric.MetricUnit),$($metric.Threshold),$($metric.Status),$($metric.Notes)"
            Add-Content -Path $MetricsFile -Value $line -Encoding UTF8
        }
        
        Write-Log "✓ $($script:CollectedMetrics.Count) métriques sauvegardées" -Level SUCCESS
        
        # Statistiques
        $critical = ($script:CollectedMetrics | Where-Object { $_.Status -eq "CRITICAL" }).Count
        $warning = ($script:CollectedMetrics | Where-Object { $_.Status -eq "WARNING" }).Count
        $ok = ($script:CollectedMetrics | Where-Object { $_.Status -eq "OK" }).Count
        
        Write-Log "Status : $ok OK | $warning WARNING | $critical CRITICAL" -Level INFO
        
        if ($critical -gt 0) {
            Write-Log "⚠ $critical métriques CRITIQUES détectées" -Level WARNING
        }
        
    } catch {
        Write-Log "ERREUR sauvegarde métriques : $_" -Level ERROR
    }
}
#endregion

#region Main
function Main {
    if ([Environment]::UserInteractive) {
        Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║              COLLECTE MÉTRIQUES SCCM                           ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    }
    
    Write-Log "Début de la collecte - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
    
    # Charger la configuration des seuils
    if (!(Test-Path $ThresholdsFile)) {
        Write-Log "ERREUR : Fichier de configuration introuvable : $ThresholdsFile" -Level ERROR
        exit 1
    }
    
    $thresholds = Get-Content $ThresholdsFile -Raw | ConvertFrom-Json
    Write-Log "Configuration chargée : version $($thresholds.version)" -Level INFO
    
    # Connexion SCCM
    if (!(Connect-SCCMSite)) {
        Write-Log "ERREUR : Impossible de se connecter à SCCM" -Level ERROR
        exit 1
    }
    
    # Collecte des métriques
    Collect-CollectionsMetrics -Thresholds $thresholds.thresholds
    Collect-PerformanceMetrics -Thresholds $thresholds.thresholds
    Collect-SystemMetrics -Thresholds $thresholds.thresholds
    Collect-DeploymentsMetrics -Thresholds $thresholds.thresholds
    
    # Sauvegarde
    Save-Metrics
    
    # Retour au système de fichiers
    Set-Location C:\
    
    $duration = ((Get-Date) - $script:StartTime).TotalSeconds
    Write-Log "Collecte terminée en $([math]::Round($duration, 2))s" -Level SUCCESS
    
    if ([Environment]::UserInteractive) {
        Write-Host "`nVoir les données : Import-Csv '$MetricsFile' | Out-GridView" -ForegroundColor Yellow
    }
}

# Exécution
Main
#endregion
