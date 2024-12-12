# Définir le chemin du dossier à scanner et le fichier updates.txt
$folderPath = "C:\Program Files\Nagios\NCPA\plugins"
$updatesFilePath = "C:\Users\ecaussat\OneDrive - SMART IT\Bureau\updates.txt"

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

# Scanner les fichiers dans le dossier et calculer les hash
$hashList = @()
Get-ChildItem -Path $folderPath -File | ForEach-Object {
    $filePath = $_.FullName
    $hash = Get-FileHashSHA256 -filePath $filePath
    $hashList += "$hash $($_.Name)"
}

# Écrire les hash dans le fichier updates.txt
$hashList | Out-File -FilePath $updatesFilePath -Encoding UTF8

Write-Host "Le fichier updates.txt a été créé avec succès dans $folderPath"