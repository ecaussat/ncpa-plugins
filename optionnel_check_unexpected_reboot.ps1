# Un script simple mais efficace pour vérifier les redémarrages inattendus en comparant la date entre les redémarrages attendus et inattendus
# événements dans le journal des événements Windows
# Ce script utilise Get-WinEvent, qui est disponible dans Windows PowerShell
# Si vous souhaitez vérifier d'autres types d'événements, recherchez l'ID dans le journal des événements et changez le numéro derrière "EventID="
# Crédits à Tom Kerremans
# Licence GPL V2

function Get-EventLogDate {
    param (
        [int]$EventID
    )
    $event = Get-WinEvent -FilterHashtable @{LogName='System'; ID=$EventID} -MaxEvents 1 | Select-Object -ExpandProperty TimeCreated
    return $event
}

$expected = Get-EventLogDate -EventID 13
$unexpected = Get-EventLogDate -EventID 41

if (-not $expected -and -not $unexpected) {
    Write-Output "Avertissement Le dernier redemarrage est inconnu"
    exit 0
}

if (-not $unexpected) {
    Write-Output "OK Le dernier redemarrage le $($expected.ToString('dd/MM/yyyy HH:mm:ss')) etait propre"
    exit 0
}

if ($unexpected -gt $expected) {
    $currentDate = Get-Date
    if ($unexpected.Date -eq $currentDate.Date) {
        Write-Output "Critique Redemarrage inattendu le $($unexpected.ToString('dd/MM/yyyy HH:mm:ss'))"
        exit 2
    } else {
        Write-Output "OK Mais Redemarrage inattendu le $($unexpected.ToString('dd/MM/yyyy HH:mm:ss'))."
        exit 0
    }
} else {
    Write-Output "OK Le dernier redemarrage le $($expected.ToString('dd/MM/yyyy HH:mm:ss')) etait propre"
    exit 0
}