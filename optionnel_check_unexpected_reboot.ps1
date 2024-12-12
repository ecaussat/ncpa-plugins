# Un script simple mais efficace pour v�rifier les red�marrages inattendus en comparant la date entre les red�marrages attendus et inattendus
# �v�nements dans le journal des �v�nements Windows
# Ce script utilise Get-WinEvent, qui est disponible dans Windows PowerShell
# Si vous souhaitez v�rifier d'autres types d'�v�nements, recherchez l'ID dans le journal des �v�nements et changez le num�ro derri�re "EventID="
# Cr�dits � Tom Kerremans
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