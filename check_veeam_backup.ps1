################################################################################################
#
# 02/04/2020 : Prise en charge des replica "SimpleBackupCopyPolicy (ajout des lignes 52 à 66 et 98 à 101)
#
# 18/05/2021 : ajout réplicas en v11 avec BackupSync (ligne 32 et suivantes) + ajout date dernier résultat
# 
################################################################################################

# Veeam version
$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Program Files\Veeam\Backup and Replication\Console\veeam.backup.shell.exe").FileVersion


# Adding required SnapIn
asnp VeeamPSSnapin -ErrorAction SilentlyContinue

# Global variables
$name = $args[0].Trim('"')
$period = $args[1].Trim('"')

# Reconstruire et afficher la ligne de commande complète
$commandLine = "$($MyInvocation.InvocationName) " + ($args -join ' ')
#Write-Host "Complete Command: $commandLine"


# Veeam Backup & Replication job status check

$job = Get-VBRJob -Name $name
#$name = '"' + $name + '"'


if ($job -eq $null)
{
	Write-Host "UNKNOWN! No such a job: $name."
	exit 3
}

if($job.JobType -eq "Replica" -Or $job.JobType -eq "BackupSync" ) {

	$Jobs = Get-VBRJob -Name $name

	$allsessions = Get-VBRBackupSession  | ? { ($_.JobName -eq $name) -and ($_.Status -ne "InProgress") -and ($_.Result -ne "None")}
	$allorderdedsess = $allsessions | Sort-Object -Property EndTimeUTC -Descending  
    $lastsessions = $allorderdedsess | select -First 1

    $lastsessions | % { 
        $lastsession = $_;

        if($lastsession.Result -eq "Failed") {
			Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => "$lastsession.Result"-"$lastsession.EndTimeUTC
			exit 2

		} elseif ($lastsession.Result -ne "Success") {
			write-host "WARNING! Job $name didn't fully succeed =>"$lastsession.Result"-"$lastsession.EndTimeUTC
			exit 1 
		}
		
    }
		
}  

elseif($job.JobType -eq "SimpleBackupCopyPolicy") {

	$Job = Get-VBRJob -Name $name

	$lastsession = [Veeam.Backup.Core.CBackupSession]::GetByJob($Job.id) | where {$_.State -eq 'Stopped'} | Select Name, Result, CreationTime -Last 1

        if($lastsession.Result -eq "Failed") {
			Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => " $lastsession.Result
			exit 2

		} elseif ($lastsession.Result -ne "Success") {
			write-host "WARNING! Job $name didn't fully succeed => " $lastsession.Result
			exit 1 
		}	
} 
else {
$status = $job.GetLastResult()

	if($($job.findlastsession()).State -eq "Working"){
		Write-Host "OK - Job: $name is currently in progress."
		exit 0
	}
	if ($status -eq "Failed")
	{
		Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name => " $lastsession.Result
		exit 2
	}


	if ($status -ne "Success")
	{
		Write-Host "WARNING! Job $name didn't fully succeed => " $lastsession.Result
		exit 1
	}
}	
# Veeam Backup & Replication job last run check

$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("yyyy-MM-dd")

if ([version]$version -lt [version]"10.0.0.0")
{
$last = $job.GetScheduleOptions()
$last = $last -replace '.*Latest run time: \[', ''
$last = $last -replace '\], Next run time: .*', ''
}
elseif ($job.JobType -eq "SimpleBackupCopyPolicy")
{
$last = $lastsession.CreationTime.ToString()
}
else
{
$last = $job.LatestRunLocal.ToString()
}
$last = $last.split(' ')[0]

#changed by DY on 11/04/2014 based on comment from cmot-weasel at http://exchange.nagios.org/directory/Plugins/Backup-and-Recovery/Others/check_veeam_backups/details
#if ($now -gt $last)
if ((Get-Date $now) -gt (Get-Date $last))
{
	Write-Host "CRITICAL! Last run of job: $name more than $period days ago => " $last
	exit 2
} 
else
{
	Write-Host "OK! Backup process of job $name completed successfully => " $last
	exit 0
}
