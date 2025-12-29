#Requires -Version 5.1

<#
.SYNOPSIS
    Export et analyse des données pour Power BI et reporting
    
.DESCRIPTION
    - Génère des résumés statistiques
    - Crée des rapports HTML interactifs
    - Prépare les données pour import Power BI
    
.PARAMETER MonitoringPath
    Chemin racine du monitoring
    
.PARAMETER DateFrom
    Date de début pour l'analyse
    
.PARAMETER DateTo
    Date de fin pour l'analyse
    
.EXAMPLE
    .\Export-PowerBIReport.ps1 -DateFrom "2025-01-15" -DateTo "2025-02-15"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MonitoringPath = "C:\SCCM_Monitoring",
    
    [Parameter(Mandatory=$false)]
    [datetime]$DateFrom,
    
    [Parameter(Mandatory=$false)]
    [datetime]$DateTo = (Get-Date),
    
    [switch]$GenerateHTML,
    [switch]$OpenReport
)

# Chemins
$DataPath = Join-Path $MonitoringPath "Data"
$ReportsPath = Join-Path $MonitoringPath "Reports"
$MetricsFile = Join-Path $DataPath "SCCM_Metrics_History.csv"
$BaselineFile = Join-Path $DataPath "SCCM_Baseline_Initial.json"

function Generate-HTMLReport {
    param($Data, $Baseline, $Summary)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = Join-Path $ReportsPath "SCCM_Report_$timestamp.html"
    
    # Calculer les améliorations depuis baseline
    $improvements = @{}
    if ($Baseline) {
        $latestData = $Data | Group-Object MetricName | ForEach-Object {
            $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
        }
        
        foreach ($metric in $latestData) {
            $baselineValue = switch ($metric.MetricName) {
                "TotalCount" { $Baseline.Metrics.Collections.TotalCount }
                "IncrementalCount" { $Baseline.Metrics.Collections.IncrementalCount }
                "EmptyCollections" { $Baseline.Metrics.Collections.EmptyCollections }
                "ActiveDeployments" { $Baseline.Metrics.Deployments.TotalCount }
                default { $null }
            }
            
            if ($baselineValue) {
                $improvement = $baselineValue - $metric.MetricValue
                $improvementPct = [math]::Round(($improvement / $baselineValue) * 100, 1)
                $improvements[$metric.MetricName] = @{
                    Initial = $baselineValue
                    Current = $metric.MetricValue
                    Improvement = $improvement
                    ImprovementPct = $improvementPct
                }
            }
        }
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Rapport SCCM Monitoring - $(Get-Date -Format 'dd/MM/yyyy')</title>
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 3px solid #3498db; 
            padding-bottom: 15px; 
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .metric-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        .metric-card.ok { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .metric-card.warning { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .metric-card.critical { background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); }
        .metric-value {
            font-size: 48px;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            font-size: 14px;
            opacity: 0.9;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .improvement {
            margin-top: 10px;
            padding: 10px;
            background: rgba(255,255,255,0.2);
            border-radius: 5px;
            font-size: 14px;
        }
        .improvement.positive { border-left: 4px solid #27ae60; }
        .improvement.negative { border-left: 4px solid #e74c3c; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            background: white;
            border-radius: 8px;
            overflow: hidden;
        }
        th {
            background: #3498db;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #ecf0f1;
        }
        tr:hover { background: #f8f9fa; }
        .status-badge {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
        }
        .status-ok { background: #27ae60; color: white; }
        .status-warning { background: #f39c12; color: white; }
        .status-critical { background: #e74c3c; color: white; }
        .section {
            margin: 40px 0;
        }
        .chart-container {
            height: 400px;
            margin: 20px 0;
        }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="container">
        <h1>📊 Rapport SCCM Monitoring</h1>
        <p><strong>Période analysée :</strong> $(if($DateFrom){"du $($DateFrom.ToString('dd/MM/yyyy'))"}) au $($DateTo.ToString('dd/MM/yyyy HH:mm'))</p>
        <p><strong>Total métriques :</strong> $($Data.Count) | <strong>Baseline :</strong> $(if($Baseline){"$($Baseline.Timestamp)"}else{"Non disponible"})</p>
        
        <div class="section">
            <h2>🎯 Métriques Clés</h2>
            <div class="summary-grid">
"@
    
    # Ajouter les cartes de métriques avec améliorations
    foreach ($metricName in @("TotalCount", "IncrementalCount", "EmptyCollections", "ActiveDeployments")) {
        $latest = $Data | Where-Object { $_.MetricName -eq $metricName } | Sort-Object Timestamp -Descending | Select-Object -First 1
        if ($latest) {
            $cardClass = switch ($latest.Status) {
                "OK" { "ok" }
                "WARNING" { "warning" }
                "CRITICAL" { "critical" }
                default { "" }
            }
            
            $improvementHtml = ""
            if ($improvements.ContainsKey($metricName)) {
                $imp = $improvements[$metricName]
                $impClass = if ($imp.Improvement -gt 0) { "positive" } else { "negative" }
                $arrow = if ($imp.Improvement -gt 0) { "↓" } else { "↑" }
                $improvementHtml = @"
<div class="improvement $impClass">
    Baseline: $($imp.Initial) $arrow $($imp.Current) ($($imp.ImprovementPct)%)
</div>
"@
            }
            
            $html += @"
                <div class="metric-card $cardClass">
                    <div class="metric-label">$($latest.MetricName)</div>
                    <div class="metric-value">$($latest.MetricValue)</div>
                    <div>Status: $($latest.Status) | Seuil: $($latest.Threshold)</div>
                    $improvementHtml
                </div>
"@
        }
    }
    
    $html += @"
            </div>
        </div>
        
        <div class="section">
            <h2>📈 Évolution dans le temps</h2>
            <canvas id="trendChart" class="chart-container"></canvas>
        </div>
        
        <div class="section">
            <h2>📋 Détails par Catégorie</h2>
"@
    
    # Tableaux par catégorie
    $categories = $Data | Group-Object MetricCategory
    foreach ($category in $categories) {
        $html += "<h3>$($category.Name)</h3><table><tr><th>Métrique</th><th>Valeur</th><th>Unité</th><th>Seuil</th><th>Status</th><th>Notes</th></tr>"
        
        $latestMetrics = $category.Group | Group-Object MetricName | ForEach-Object {
            $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
        }
        
        foreach ($metric in $latestMetrics) {
            $statusClass = "status-" + $metric.Status.ToLower()
            $html += @"
<tr>
    <td><strong>$($metric.MetricName)</strong></td>
    <td>$($metric.MetricValue)</td>
    <td>$($metric.MetricUnit)</td>
    <td>$($metric.Threshold)</td>
    <td><span class="status-badge $statusClass">$($metric.Status)</span></td>
    <td>$($metric.Notes)</td>
</tr>
"@
        }
        $html += "</table>"
    }
    
    # Script Chart.js pour graphique
    $chartData = $Data | Where-Object { $_.MetricName -in @("TotalCount", "IncrementalCount") } | 
        Select-Object Timestamp, MetricName, MetricValue | 
        ConvertTo-Json -Compress
    
    $html += @"
        </div>
        
        <div style="text-align: center; color: #7f8c8d; margin-top: 50px; padding: 20px; border-top: 1px solid #bdc3c7;">
            <p>Rapport généré automatiquement le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
            <p>Fichier source : $MetricsFile</p>
        </div>
    </div>
    
    <script>
    // Données pour le graphique
    const rawData = $chartData;
    const datasets = {};
    
    rawData.forEach(item => {
        if (!datasets[item.MetricName]) {
            datasets[item.MetricName] = {
                label: item.MetricName,
                data: [],
                borderColor: item.MetricName === 'TotalCount' ? '#3498db' : '#e74c3c',
                tension: 0.1
            };
        }
        datasets[item.MetricName].data.push({
            x: new Date(item.Timestamp),
            y: item.MetricValue
        });
    });
    
    const ctx = document.getElementById('trendChart').getContext('2d');
    new Chart(ctx, {
        type: 'line',
        data: {
            datasets: Object.values(datasets)
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    type: 'time',
                    time: {
                        unit: 'day'
                    }
                },
                y: {
                    beginAtZero: true
                }
            },
            plugins: {
                title: {
                    display: true,
                    text: 'Évolution des Collections'
                }
            }
        }
    });
    </script>
</body>
</html>
"@
    
    $html | Out-File $reportFile -Encoding UTF8
    Write-Host "✓ Rapport HTML généré : $reportFile" -ForegroundColor Green
    
    if ($OpenReport) {
        Start-Process $reportFile
    }
    
    return $reportFile
}

function Main {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║             EXPORT RAPPORT SCCM                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    # Vérifier que le fichier de données existe
    if (!(Test-Path $MetricsFile)) {
        Write-Host "ERREUR : Fichier de métriques introuvable : $MetricsFile" -ForegroundColor Red
        exit 1
    }
    
    # Charger les données
    Write-Host "Chargement des données..." -ForegroundColor Yellow
    $data = Import-Csv $MetricsFile
    
    # Filtrer par date si spécifié
    if ($DateFrom) {
        $data = $data | Where-Object { [datetime]$_.Timestamp -ge $DateFrom -and [datetime]$_.Timestamp -le $DateTo }
    }
    
    Write-Host "  $($data.Count) métriques chargées" -ForegroundColor Green
    
    # Charger la baseline si disponible
    $baseline = $null
    if (Test-Path $BaselineFile) {
        $baseline = Get-Content $BaselineFile -Raw | ConvertFrom-Json
        Write-Host "  Baseline chargée : $($baseline.Timestamp)" -ForegroundColor Green
    }
    
    # Statistiques
    $summary = @{
        TotalMetrics = $data.Count
        Critical = ($data | Where-Object { $_.Status -eq "CRITICAL" }).Count
        Warning = ($data | Where-Object { $_.Status -eq "WARNING" }).Count
        OK = ($data | Where-Object { $_.Status -eq "OK" }).Count
    }
    
    Write-Host "`nRésumé :" -ForegroundColor Cyan
    Write-Host "  OK       : $($summary.OK)" -ForegroundColor Green
    Write-Host "  WARNING  : $($summary.Warning)" -ForegroundColor Yellow
    Write-Host "  CRITICAL : $($summary.Critical)" -ForegroundColor Red
    
    # Générer le rapport HTML
    if ($GenerateHTML) {
        $reportFile = Generate-HTMLReport -Data $data -Baseline $baseline -Summary $summary
        Write-Host "`n✅ Export terminé" -ForegroundColor Green
        Write-Host "   Rapport : $reportFile" -ForegroundColor White
    }
    
    # Instructions Power BI
    Write-Host @"

📊 POUR POWER BI :
1. Ouvrir Power BI Desktop
2. Obtenir les données > Texte/CSV
3. Sélectionner : $MetricsFile
4. Créer des visuels :
   - Graphique en courbes : Timestamp (axe X) vs MetricValue (axe Y) par MetricName
   - Carte : Dernière valeur par métrique
   - Jauge : Avec seuils Warning/Critical
   - Tableau : Toutes les métriques avec Status

"@ -ForegroundColor Yellow
}

Main
