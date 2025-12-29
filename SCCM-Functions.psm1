<#
.SYNOPSIS
    Module de fonctions communes pour Configuration Manager
.DESCRIPTION
    Ce module contient des fonctions utilitaires pour faciliter l'interaction
    avec Microsoft Configuration Manager dans les scripts PowerShell.
.NOTES
    Auteur: Thomas
    Version: 1.0.0
#>

<#
.SYNOPSIS
    Se connecte à un site Configuration Manager
.DESCRIPTION
    Établit une connexion au site SCCM et charge le module ConfigurationManager
.PARAMETER SiteCode
    Code du site SCCM (ex: ABC)
.PARAMETER SiteServer
    Nom FQDN du serveur de site
.EXAMPLE
    Connect-SCCMSite -SiteCode "ABC" -SiteServer "sccm-server.domain.com"
#>
function Connect-SCCMSite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SiteCode,
        
        [Parameter(Mandatory=$true)]
        [string]$SiteServer
    )
    
    try {
        # Importer le module ConfigurationManager
        if (-not (Get-Module -Name ConfigurationManager)) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
        }
        
        # Se connecter au site
        if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -ErrorAction Stop
        }
        
        # Basculer vers le drive du site
        Set-Location "$($SiteCode):\" -ErrorAction Stop
        
        Write-Host "✓ Connecté au site $SiteCode sur $SiteServer" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Erreur de connexion au site SCCM: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Écrit un message dans un fichier log au format Configuration Manager
.DESCRIPTION
    Crée des entrées de log compatibles avec CMTrace
.PARAMETER Message
    Message à logger
.PARAMETER Component
    Nom du composant/script
.PARAMETER Type
    Type de message: Info, Warning, Error
.PARAMETER LogPath
    Chemin complet du fichier log
.EXAMPLE
    Write-CMLog -Message "Script démarré" -Component "MonScript" -Type Info -LogPath "C:\Logs\script.log"
#>
function Write-CMLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$true)]
        [string]$Component,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","Warning","Error")]
        [string]$Type = "Info",
        
        [Parameter(Mandatory=$true)]
        [string]$LogPath
    )
    
    # Déterminer le type de message
    switch ($Type) {
        "Info"    { $TypeNum = 1 }
        "Warning" { $TypeNum = 2 }
        "Error"   { $TypeNum = 3 }
    }
    
    # Créer le dossier si nécessaire
    $LogDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Formater la ligne de log
    $Time = Get-Date -Format "HH:mm:ss.fff"
    $Date = Get-Date -Format "MM-dd-yyyy"
    $Context = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    
    $LogLine = "<![LOG[$Message]LOG]!><time=`"$Time+000`" date=`"$Date`" component=`"$Component`" context=`"$Context`" type=`"$TypeNum`" thread=`"$PID`" file=`"`">"
    
    # Écrire dans le fichier
    Add-Content -Path $LogPath -Value $LogLine -Encoding UTF8
}

<#
.SYNOPSIS
    Teste la connectivité vers un serveur SCCM
.DESCRIPTION
    Vérifie la disponibilité du serveur et des services SCCM
.PARAMETER SiteServer
    Nom FQDN du serveur de site
.EXAMPLE
    Test-SCCMConnectivity -SiteServer "sccm-server.domain.com"
#>
function Test-SCCMConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SiteServer
    )
    
    $Result = @{
        ServerReachable = $false
        WMIAccessible = $false
        SMSProviderAvailable = $false
    }
    
    try {
        # Test de ping
        if (Test-Connection -ComputerName $SiteServer -Count 2 -Quiet) {
            $Result.ServerReachable = $true
            Write-Verbose "✓ Serveur $SiteServer accessible"
        }
        
        # Test d'accès WMI
        $WMI = Get-WmiObject -ComputerName $SiteServer -Namespace "root\cimv2" -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($WMI) {
            $Result.WMIAccessible = $true
            Write-Verbose "✓ WMI accessible sur $SiteServer"
        }
        
        # Test du SMS Provider
        $SMSProvider = Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms" -Class SMS_ProviderLocation -ErrorAction SilentlyContinue
        if ($SMSProvider) {
            $Result.SMSProviderAvailable = $true
            Write-Verbose "✓ SMS Provider disponible"
        }
    }
    catch {
        Write-Warning "Erreur lors du test de connectivité: $_"
    }
    
    return $Result
}

<#
.SYNOPSIS
    Récupère une collection SCCM par son nom
.DESCRIPTION
    Recherche et retourne une collection Configuration Manager
.PARAMETER CollectionName
    Nom de la collection à rechercher
.EXAMPLE
    Get-SCCMCollection -CollectionName "All Servers"
#>
function Get-SCCMCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CollectionName
    )
    
    try {
        $Collection = Get-CMCollection -Name $CollectionName -ErrorAction Stop
        
        if ($Collection) {
            Write-Verbose "✓ Collection trouvée: $CollectionName (ID: $($Collection.CollectionID))"
            return $Collection
        }
        else {
            Write-Warning "Collection '$CollectionName' introuvable"
            return $null
        }
    }
    catch {
        Write-Error "Erreur lors de la recherche de la collection: $_"
        return $null
    }
}

# Exporter les fonctions
Export-ModuleMember -Function Connect-SCCMSite, Write-CMLog, Test-SCCMConnectivity, Get-SCCMCollection
