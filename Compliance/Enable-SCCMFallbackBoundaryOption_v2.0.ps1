# ===================================================================================================
# SCRIPT : Enable-SCCMFallbackBoundaryOption.ps1
# DESCRIPTION : Active l'option de fallback vers le Default Boundary Group sur les déploiements SCCM
# VERSION : 1.0
# ===================================================================================================

<#
.SYNOPSIS
Active l'option de fallback vers le Default Boundary Group sur les déploiements SCCM

.PARAMETER SiteCode
Code du site SCCM (ex: PS1)

.PARAMETER WhatIf
Mode Simulation sans modification

.EXAMPLE
.\Enable-SCCMFallback.ps1 -SiteCode "PS1" -WhatIf
Mode test

.EXAMPLE
.\Enable-SCCMFallback.ps1 -SiteCode "PS1"
Activation reelle

#>
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[A-Z]{3}$')]
    [String]$SiteCode,

    [switch]$WhatIf
)

# Initialisation du module SCCM
try{
    Write-Host $SiteCode
    $AdminUIPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SMS\Setup"
    $ModulePath = Join-Path $AdminUIPath."UI Installation Directory" "bin\ConfigurationManager.psd1"
    Import-Module $ModulePath -Force -ErrorAction Stop
    Set-Location "${SiteCode}:"
    Write-Host "Connecte au site $SiteCode" -ForegroundColor Green
} catch {
    Write-Host "Erreur de connexion SCCM: $_" -ForegroundColor Red
    exit 1
}


Write-Host @"
========================================================================
ACTIVATION FALLBACK DEFAULT BOUNDARY GROUP
Site: $SiteCode | Mode: $(if ($WhatIf) { "SIMULATION" } else { "REEL" })
========================================================================
"@ -ForegroundColor Cyan

$TotalModified = 0

# =========================================================================
# PACKAGES (Avec StandardProgram uniquement)
# =========================================================================
Write-Host "Traitement des packages..." -ForegroundColor Yellow

try {
    $Packages = @(Get-CMPackageDeployment)
    $PackageCount = 0

    foreach ($Package in $Packages) {
        if (![string]::IsNullOrEmpty($Package.ProgramName)) {
            if ($WhatIf) {
            Write-Host "       [TEST] $($Package.ProgramName)" -ForegroundColor Gray
            } else {
                try {
                    Set-CMPackageDeployment -PackageID $Package.PackageID -StandardProgramName $Package.ProgramName -CollectionID $Package.CollectionID -AllowFallback $true
                    Write-Host "       OK. $($Package.ProgramName)" -ForegroundColor Green
                } catch {
                    Write-Host "       KO. $($Package.ProgramName) : $_" -ForegroundColor Red
                }
            }
            $PackageCount++
        }
    }
    
    Write-Host "Packages: $PackageCount traites" -ForegroundColor Cyan
    $TotalModified += $PackageCount

} catch {
    Write-Host "Erreur packages : $_" -ForegroundColor Red
}

# =========================================================================
# TASK SEQUENCES
# =========================================================================
Write-Host "Traitement des sequences de taches..." -ForegroundColor Yellow

try {
    $TaskSequences = @(Get-CMTaskSequenceDeployment -fast)
    $TSCount = 0

    foreach ($TS in $TaskSequences) {
        $AllowFallback = if ($TS.PSObject.Properties.Name -contains "AllowFallback") { $TS.AllowFallback } else { $false }

        if (!$AllowFallback) {
            if ($WhatIf) {
            Write-Host "       [TEST] $($TS.AdvertisementName)" -ForegroundColor Gray
            } else {
                try {
                    Set-CMTaskSequenceDeployment -InputObject $TS -AllowFallback $true
                    Write-Host "       OK. $($TS.AdvertisementName)" -ForegroundColor Green
                } catch {
                    Write-Host "       KO. $($TS.AdvertisementName) : $_" -ForegroundColor Red
                }
            }
            $TSCount++
        }
    }
    
    Write-Host "Sequence de taches: $TSCount traites" -ForegroundColor Cyan
    $TotalModified += $TSCount

} catch {
    Write-Host "Erreur sequence de taches: $_" -ForegroundColor Red
}

# =========================================================================
# SOFTWARE UPDATES
# =========================================================================
Write-Host "Traitement des mises a jour..." -ForegroundColor Yellow

try {
    $SoftwareUpdates = @(Get-CMSoftwareUpdateDeployment)
    $SUCount = 0

    foreach ($SU in $SoftwareUpdates) {
        $UnprotectedType = if ($SU.PSObject.Properties.Name -contains "UnprotectedType") { $SU.UnprotectedType } else { "Unknown" }

        if ($UnprotectedType -ne "UnprotectedDistributionPoint") {
            if ($WhatIf) {
            Write-Host "       [TEST] $($SU.AssignmentName)" -ForegroundColor Gray
            } else {
                try {
                    Set-CMSoftwareUpdateDeployment -InputObject $SU -UnprotectedType "UnprotectedDistributionPoint"
                    Write-Host "       OK. $($SU.AssignmentName)" -ForegroundColor Green
                } catch {
                    Write-Host "       KO. $($SU.AssignmentName) : $_" -ForegroundColor Red
                }
            }
            $SUCount++
        }
    }
    
    Write-Host "Software Updates: $SUCount traites" -ForegroundColor Cyan
    $TotalModified += $SUCount

} catch {
    Write-Host "Erreur Software updates: $_" -ForegroundColor Red
}

# =========================================================================
# APPLICATIONS
# =========================================================================
Write-Host "Traitement des applications..." -ForegroundColor Yellow

try {
    $Applications = @(Get-CMApplication -fast)
    $AppsCount = 0

    foreach ($App in $Applications) 
        {
            $DeploymentTypes = Get-CMDeploymentType -ApplicationName $App.LocalizedDisplayName
            $Fallback = 
            foreach ($DT in $DeploymentTypes)
                {
                    if ($WhatIf) {
                        Write-Host "       [TEST] $($DT.LocalizedDisplayName)" -ForegroundColor Gray
                    } else {
                        try {
                            if ($DT.Technology -eq "Script") {
                                Set-CMScriptDeploymentType -InputObject $DT -EnableContentLocationFallback $true
                                Write-Host "       OK. $($DT.LocalizedDisplayName) Type: $($DT.Technology)" -ForegroundColor Green

                            } elseif ($DT.Technology -eq "MSI") {
                                Set-CMMsiDeploymentType -InputObject $DT -ContentFallback $true
                                Write-Host "       OK. $($DT.LocalizedDisplayName) Type: $($DT.Technology)" -ForegroundColor Green
                            } else {
                                Write-Host "       KO. $($DT.LocalizedDisplayName) : $_" -ForegroundColor Red}

                        } catch {
                            Write-Host "       KO. $($DT.LocalizedDisplayName) : $_" -ForegroundColor Red
                        }
                
                    $AppsCount++
                }
        }
    }
    
    Write-Host "Applications: $AppsCount traites" -ForegroundColor Cyan
    $TotalModified += $AppsCount

} catch {
    Write-Host "Erreur Application: $_" -ForegroundColor Red
}

# =========================================================================
# RESUME
# =========================================================================
Write-Host @"
========================================================================
TERMINE
Total deploiments $(if ($WhatIf) { "a traiter" } else { "modifies" }): $TotalModified
========================================================================
"@ -ForegroundColor Green

if ($WhatIf){
    Write-Host "Relancer sans -WhatIf pour appliquer les modifications" -ForegroundColor Yellow
}

# Retour au repertoire systeme
#Set-Location $env:SystemDrive
