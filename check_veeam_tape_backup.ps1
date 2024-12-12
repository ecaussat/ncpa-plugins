#	Title:			veeam_tape_backup.ps1
#	Description:	This is a Nagios plug-in that will check the last status and
#					last run of a Veeam Backup & Replication tape job passed as 
#					an argument.
#	Author:			Laz Ravelo
#	Date:			2018-01-10
#	Version:		1.0
#	Usage:			veeam_tape_backup.ps1 $name $period
#	Notes:			Credit goes to Tytus Kurek for originally creating the script
#					that would check the same info for non-tape jobs in Veeam.
#=================================================================================

#	Add the Veeam SnapIn
asnp VeeamPSSnapin -ErrorAction SilentlyContinue

# Global variables
$name = $args[0].Trim('"')
$period = $args[1].Trim('"')

# Reconstruire et afficher la ligne de commande complète
$commandLine = "$($MyInvocation.InvocationName) " + ($args -join ' ')
#Write-Host "Complete Command: $commandLine"

#	Get Tape Backup Job info

$job = Get-VBRTapeJob -Name $name
$name = "'" + $name + "'"

#	Check if job argument is missing
if ($job -eq $null)
{
	Write-Host "No such tape job: $name"
	exit 3
}

#	Check if period argument is missing
if ($period -eq $null)
{
	Write-Host "Missing the period argument!"
	exit 3
}

#	Assign last result of job to variable
$status = $job.lastResult
$state = $job.lastState

if($state -eq "Working"){
	Write-Host "OK - Job: $name is currently in progress."
	exit 0
}

if ($state -eq "Stopped"){
 
if ($status -eq "Failed")
{
	Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name."
	exit 2
}


if ($status -ne "Success")
{
	Write-Host "WARNING! Job $name didn't fully succeed."
Write-Host $Status
	exit 1
}
}

#	Date comparison
$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("yyyy-MM-dd")
$last = get-vbrsession -job $job -Last | select -ExpandProperty "CreationTime"
$last = $last.ToString("yyyy-MM-dd")

#	Throw warning if last backup job ran more than x days ago (depends on value of $period)
if((Get-Date $now) -gt (Get-Date $last))
{
	Write-Host "CRITICAL! Last run of job $name happened more than $period days ago."
	exit 2
}
else
{
	Write-Host "OK! Tape backup job $name has completed successfully."
	exit 0
}