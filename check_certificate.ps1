<#
.SYNOPSIS
    Script pour Nagios pour vérifier l'expiration des certificats SSL.
.DESCRIPTION
    Le script se connecte à une URL, récupère le certificat, extrait les informations et affiche un statut OK, WARNING ou CRITICAL.
.NOTES
    Auteur : CAUSSAT Eugène
    Date : Août 2024
    Version : 1.0.10
.PARAMETER url
    Domaine.tld - L'URL du serveur dont vous souhaitez vérifier le certificat. Valeur par défaut : "www.google.fr".
.PARAMETER Warn
    Le nombre de jours avant l'expiration pour déclencher un avertissement.
.PARAMETER Crit
    Le nombre de jours avant l'expiration pour déclencher une alerte critique.
.PARAMETER port
    Le port sur lequel se connecter, par défaut 443.
.EXAMPLE
    ./check_certificate -url "www.google.fr" -port 443
    ./check_certificate -url "www.google.fr" -port 8443 -Crit 10
    ./check_certificate -url "www.google.fr" -Warn 15 -Crit 7
#>

[CmdletBinding()]
Param(
    [string]$url = "www.google.fr", # domaine.tld avec une valeur par défaut
    [Alias("W")]
    [int]$Warn = 30, # valeur par défaut pour les avertissements
    [Alias("C")]
    [int]$Crit = 5, # valeur par défaut pour les alertes critiques
    [int]$port = 443 # Port par défaut
)

# Fonction pour vérifier l'expiration du certificat
function Check-Certificate {
    param (
        [string]$url,
        [int]$Warn,
        [int]$Crit,
        [int]$port
    )

    $url = "https://${url}:${port}/"
    Write-Host "Vérification du certificat pour $url" -ForegroundColor Green

    # Désactiver la validation du certificat pour éviter les erreurs sur les certificats auto-signés
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $req = [Net.HttpWebRequest]::Create($url)
    $req.Timeout = 10000
    $req.AllowAutoRedirect = $false
    
    try {
        #Write-Host "Attempting to get a response..." -ForegroundColor Cyan
        $response = $req.GetResponse()
        #Write-Host "Response obtained successfully." -ForegroundColor Cyan
        $response.Close() # Fermeture de la réponse après utilisation
    }
    catch {
        Write-Host ("Exception lors de la vérification de l'URL $url : $_") -ForegroundColor Red
        return 3 # Retourne CRITICAL en cas d'erreur de connexion
    }

    # Extraction des informations du certificat
    try {
        $cert = $req.ServicePoint.Certificate
        if ($cert -eq $null) {
            Write-Host "CRITICAL: Pas de certificat trouvé $url" -ForegroundColor Red
            return 3
        }

        $certExpiresOnString = $cert.GetExpirationDateString()
        #Write-Host "Certificate expiration date string: $certExpiresOnString" -ForegroundColor Cyan
        
        [datetime]$expiration = [System.DateTime]::Parse($certExpiresOnString)
        #Write-Host "Date d'expiration du certificat : $expiration" -ForegroundColor Cyan
        
        [int]$certExpiresIn = ($expiration - $(Get-Date)).Days
        #Write-Host "Jours avant expiration : $certExpiresIn" -ForegroundColor Cyan
    }
    catch {
        Write-Host ("Exception lors du traitement du certificat pour l'URL $url : $_") -ForegroundColor Red
        return 3 # Retourne CRITICAL en cas d'erreur de traitement du certificat
    }

    if ($certExpiresIn -gt $Warn) {
        Write-Host "OK: Le certificat expire dans $certExpiresIn jours [le $expiration]" -ForegroundColor Green
        return 0 # Retourne OK
    }
    elseif ($certExpiresIn -le $Crit) {
        Write-Host "CRITICAL: Le certificat $url expire dans $certExpiresIn jours [le $expiration]" -ForegroundColor Red
        return 2 # Retourne CRITICAL
    }
    elseif ($certExpiresIn -le $Warn) {
        Write-Host "WARNING: Le certificat $url expire dans $certExpiresIn jours [le $expiration]" -ForegroundColor Yellow
        return 1 # Retourne WARNING
    }
}

# Appeler la fonction pour vérifier l'expiration du certificat
$status = Check-Certificate -url $url -Warn $Warn -Crit $Crit -port $port
exit $status
