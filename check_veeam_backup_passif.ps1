# Veeam version
$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Program Files\Veeam\Backup and Replication\Console\veeam.backup.shell.exe").FileVersion

# Check if no parameters are provided
if ($args.Count -eq 0) {
    Write-Host "Utilisation : script.ps1 <NomDuJob> <Période> <HeureDébut> <HeureFin>"
    Write-Host "Exemple : script.ps1 'Backup Job' 7 22 6"
    Write-Host ""
    Write-Host "Notes :"
    Write-Host " Le nomdujob est celui configuré sur Veeam."
    Write-Host ""
    Write-Host " La période définie le nombre de jour entre deux sauvegardes (alerte si dépassé)."
    Write-Host " Il y a aussi alerte si les logs Veeam rapportent des erreurs lors de ladernière sauvegarde."
    Write-Host ""
    Write-Host " La plage horaire définie par <HeureDébut> et <HeureFin> est celle où le check ne doit pas avoir lieu."
    exit 0
}

# Adding required SnapIn
asnp VeeamPSSnapin -ErrorAction SilentlyContinue

# Global variables
$name = $args[0].Trim('"')
$period = $args[1].Trim('"')
$startHour = [int]$args[2].Trim('"')
$endHour = [int]$args[3].Trim('"')

# Check if current time is within the allowed time window
$currentHour = (Get-Date).Hour
if ($currentHour -ge $startHour -and $currentHour -lt $endHour) {
    #Write-Host "The current time ($currentHour) is outside the allowed verification window ($startHour-$endHour)."
    exit 0
}

# Reconstruire et afficher la ligne de commande complète
$commandLine = "$($MyInvocation.InvocationName) " + ($args -join ' ')
#Write-Host "Complete Command: $commandLine"

# Veeam Backup & Replication job status check

$job = Get-VBRJob -Name $name
#$name = '"' + $name + '"'

if ($job -eq $null) {
    Write-Host "UNKNOWN! No such a job: $name."
    exit 3
}

if ($job.JobType -eq "Replica" -or $job.JobType -eq "BackupSync") {
    $Jobs = Get-VBRJob -Name $name

    $allsessions = Get-VBRBackupSession | ? { ($_.JobName -eq $name) -and ($_.Status -ne "InProgress") -and ($_.Result -ne "None") }
    $allorderdedsess = $allsessions | Sort-Object -Property EndTimeUTC -Descending  
    $lastsessions = $allorderdedsess | select -First 1

    $lastsessions | % { 
        $lastsession = $_;

        if ($lastsession.Result -eq "Failed") {
            Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => $lastsession.Result - $lastsession.EndTimeUTC"
            exit 2
        } elseif ($lastsession.Result -ne "Success") {
            write-host "WARNING! Job $name didn't fully succeed => $lastsession.Result - $lastsession.EndTimeUTC"
            exit 1 
        }
    }
} elseif ($job.JobType -eq "SimpleBackupCopyPolicy") {
    $Job = Get-VBRJob -Name $name

    #$lastsession = [Veeam.Backup.Core.CBackupSession]::GetByJob($Job.id) | where {$_.State -eq 'Stopped'} | Select Name, Result, CreationTime -Last 1
    $lastsession = [Veeam.Backup.Core.CBackupSession]::GetByJob($Job.id) | Select Name, Result, CreationTime, State -Last 1

    # Vérifier si le job est en cours d'exécution
    if ($lastsession.State -eq "Working") {
        Write-Host "OK - Job: $name is currently in progress."
        exit 0
    }

    # Vérifier le résultat de la dernière session
    if ($lastsession.Result -eq "Failed") {
        Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => $lastsession.Result"
        exit 2
    } elseif ($lastsession.Result -ne "Success") {
        write-host "WARNING! Job $name didn't fully succeed => $lastsession.Result"
        exit 1 
    }    
} else {
    $status = $job.GetLastResult()

    if ($($job.findlastsession()).State -eq "Working") {
        Write-Host "OK - Job: $name is currently in progress."
        exit 0
    }
    if ($status -eq "Failed") {
        Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => $lastsession.Result"
        exit 2
    }

    if ($status -ne "Success") {
        Write-Host "WARNING! Job $name didn't fully succeed => $lastsession.Result"
        exit 1
    }
}

# Veeam Backup & Replication job last run check

$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("yyyy-MM-dd")

if ([version]$version -lt [version]"10.0.0.0") {
    $last = $job.GetScheduleOptions()
    $last = $last -replace '.*Latest run time: 

\[', ''
    $last = $last -replace '\]

, Next run time: .*', ''
} elseif ($job.JobType -eq "SimpleBackupCopyPolicy") {
    $last = $lastsession.CreationTime.ToString()
} else {
    $last = $job.LatestRunLocal.ToString()
}
$last = $last.split(' ')[0]

if ((Get-Date $now) -gt (Get-Date $last)) {
    Write-Host "CRITICAL! Last run of job: $name more than $period days ago => $last"
    exit 2
} else {
    Write-Host "OK! Backup process of job $name completed successfully => $last"
    exit 0
}
