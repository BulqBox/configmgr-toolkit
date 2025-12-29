# Common

Modules et fonctions PowerShell partagés utilisés par les autres scripts du toolkit.

## Modules disponibles

### SCCM-Functions.psm1
Module contenant les fonctions communes pour interagir avec Configuration Manager.

**Fonctions incluses :**
- `Connect-SCCMSite` : Connexion au site SCCM
- `Get-SCCMCollection` : Récupération d'une collection
- `Write-CMLog` : Écriture de logs au format Configuration Manager
- `Test-SCCMConnectivity` : Test de la connectivité au serveur

## Utilisation

Pour utiliser les fonctions communes dans vos scripts :

```powershell
# Importer le module
Import-Module .\Common\SCCM-Functions.psm1

# Utiliser les fonctions
Connect-SCCMSite -SiteCode "ABC" -SiteServer "sccm-server.domain.com"
Write-CMLog -Message "Script démarré" -Component "MonScript" -Type Info
```

## Développement de nouvelles fonctions

Lors de l'ajout de nouvelles fonctions communes :
- Utiliser des verbes PowerShell standards (Get-, Set-, New-, Remove-, etc.)
- Inclure l'aide basée sur les commentaires
- Gérer les erreurs avec Try/Catch
- Valider les paramètres
- Retourner des objets typés

## Template de fonction

```powershell
<#
.SYNOPSIS
    Description courte de la fonction
.DESCRIPTION
    Description détaillée
.PARAMETER ParamName
    Description du paramètre
.EXAMPLE
    Exemple d'utilisation
#>
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ParamName
    )
    
    try {
        # Code de la fonction
    }
    catch {
        Write-Error "Erreur: $_"
    }
}
```
