# Guide de contribution

Merci de votre intérêt pour contribuer au ConfigMgr Toolkit ! Ce document décrit les processus et conventions pour contribuer efficacement.

## Comment contribuer

### Signaler un bug

1. Vérifiez que le bug n'a pas déjà été signalé dans les Issues
2. Créez une nouvelle Issue avec :
   - Un titre descriptif
   - Les étapes pour reproduire le problème
   - Le comportement attendu vs observé
   - Votre environnement (version PowerShell, version SCCM, OS)
   - Les logs pertinents

### Proposer une amélioration

1. Créez une Issue pour discuter de votre idée
2. Attendez les retours avant de commencer le développement
3. Référencez l'Issue dans votre Pull Request

### Soumettre du code

1. **Fork** le repository
2. Créez une **branche** pour votre fonctionnalité : `feature/nom-descriptif`
3. **Committez** vos changements avec des messages clairs
4. **Testez** votre code dans un environnement de dev
5. **Soumettez** une Pull Request vers la branche `main`

## Standards de code

### Conventions PowerShell

- Utilisez des verbes approuvés PowerShell (Get-, Set-, New-, Remove-, etc.)
- Nommez les variables en PascalCase : `$CollectionName`
- Indentez avec 4 espaces (pas de tabulations)
- Limitez les lignes à 120 caractères maximum

### Documentation obligatoire

Chaque fonction doit inclure :

```powershell
<#
.SYNOPSIS
    Description courte
.DESCRIPTION
    Description détaillée du fonctionnement
.PARAMETER ParamName
    Description de chaque paramètre
.EXAMPLE
    Exemple-Fonction -Param "Valeur"
    Description de ce que fait l'exemple
.NOTES
    Auteur: Votre nom
    Version: 1.0
#>
```

### Gestion des erreurs

```powershell
try {
    # Code principal
}
catch {
    Write-Error "Message d'erreur descriptif: $_"
    # Nettoyage si nécessaire
}
```

### Logging

Utilisez la fonction `Write-CMLog` du module commun pour tous les logs :

```powershell
Write-CMLog -Message "Action effectuée" -Component "NomScript" -Type Info -LogPath $LogPath
```

## Structure des scripts

### Scripts autonomes

```powershell
<#
.SYNOPSIS
    Description du script
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RequiredParam,
    
    [Parameter(Mandatory=$false)]
    [string]$OptionalParam = "DefaultValue"
)

# Importer les modules nécessaires
Import-Module "$PSScriptRoot\..\Common\SCCM-Functions.psm1"

# Variables globales
$LogPath = "C:\Logs\MonScript-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonction principale
try {
    Write-CMLog -Message "Script démarré" -Component "MonScript" -Type Info -LogPath $LogPath
    
    # Code principal ici
    
    Write-CMLog -Message "Script terminé avec succès" -Component "MonScript" -Type Info -LogPath $LogPath
}
catch {
    Write-CMLog -Message "Erreur: $_" -Component "MonScript" -Type Error -LogPath $LogPath
    exit 1
}
```

## Tests

Avant de soumettre une Pull Request :

1. **Testez dans un lab** : Ne jamais tester directement en production
2. **Vérifiez les prérequis** : Documentez toutes les dépendances
3. **Testez les cas limites** : Collections vides, paramètres invalides, etc.
4. **Vérifiez les logs** : Assurez-vous que le logging fonctionne correctement

## Organisation des fichiers

- Placez les scripts dans le dossier thématique approprié
- Mettez à jour le README du dossier pour référencer votre script
- Ajoutez un exemple d'utilisation dans `Examples/` si pertinent

## Messages de commit

Format recommandé :

```
Type: Description courte (max 50 caractères)

Description détaillée si nécessaire, expliquant :
- Pourquoi ce changement
- Ce qui a été modifié
- Impact potentiel
```

Types de commit :
- `feat`: Nouvelle fonctionnalité
- `fix`: Correction de bug
- `docs`: Documentation uniquement
- `refactor`: Refactoring sans changement de fonctionnalité
- `test`: Ajout ou modification de tests
- `chore`: Maintenance (mise à jour dépendances, etc.)

## Questions ?

N'hésitez pas à créer une Issue pour poser des questions ou demander des clarifications.

Merci de contribuer au ConfigMgr Toolkit ! 🚀
