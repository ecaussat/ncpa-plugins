# D�finir les chemins locaux et distants
$localPath = "C:\Program Files\Nagios\NCPA\plugins"
$repoUrl = "https://github.com/ecaussat/ncpa-plugins"
$tempPath = "C:\Temp\plugins"
$updatesFile = "updates.txt"

# Cr�er le dossier temporaire s'il n'existe pas
if (-Not (Test-Path -Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath > $null
}

# T�l�charger le fichier updates.txt
Invoke-WebRequest -Uri "$repoUrl/raw/main/$updatesFile" -OutFile "$tempPath\$updatesFile"

# Lire le fichier updates.txt et stocker les hash dans un dictionnaire
$hashes = @{}
Get-Content "$tempPath\$updatesFile" | ForEach-Object {
    $parts = $_ -split ' '
    $hashes[$parts[1]] = $parts[0]
}

# Fonction pour calculer le hash SHA256 d'un fichier
function Get-FileHashSHA256 {
    param (
        [string]$filePath
    )
    $fileStream = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($fileStream)
    $fileStream.Close()
    return [BitConverter]::ToString($hashBytes) -replace '-', ''
}

# Variables pour suivre les mises � jour
$updatesCount = 0
$errorsCount = 0

# V�rifier les fichiers et t�l�charger ceux qui sont absents ou incorrects
foreach ($file in $hashes.Keys) {
    $localFile = "$localPath\$file"
    $downloadUrl = "$repoUrl/raw/main/$file"
    $tempFile = "$tempPath\$file"

    $download = $false
    if (-Not (Test-Path -Path $localFile)) {
        $download = $true
    } else {
        $localHash = Get-FileHashSHA256 -filePath $localFile
        if ($localHash -ne $hashes[$file]) {
            $download = $true
        }
    }

    if ($download) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
        $downloadedHash = Get-FileHashSHA256 -filePath $tempFile
        if ($downloadedHash -eq $hashes[$file]) {
            Copy-Item -Path $tempFile -Destination $localFile -Force
            $updatesCount++
        } else {
            Write-Host "Le hash du fichier $file t�l�charg� ne correspond pas. T�l�chargement ignor�."
            $errorsCount++
        }
    }
}

# Nettoyer le dossier temporaire
Remove-Item -Recurse -Force $tempPath > $null

# Retourner le statut et le code de sortie
if ($updatesCount -eq 0 -and $errorsCount -eq 0) {
    Write-Host "OK: Aucun fichier mis � jour."
    exit 0
} elseif ($updatesCount -gt 0 -and $errorsCount -eq 0) {
    Write-Host "OK: $updatesCount fichier(s) mis � jour."
    exit 0
} else {
    Write-Host "WARNING: $updatesCount fichier(s) mis � jour, $errorsCount erreur(s) lors de la mise � jour."
    exit 1
}