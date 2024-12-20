#====================================== 
# check_wsb.ps1
#
# Original Author: Justin Bachmann
# Email: justin.bmann@gmail.com
# Created: 2012-08-29
# Version: 1.0.0
# Supported Platform: Windows Server 2008 R2 with Windows Server Backup enabled.
# This plugin requires the powershell snap-in that is part of the Win 2008 R2 Windows Server Backup command line interface.
#
# Usage: Run the script with NSClient++ or similar Nagios / Icinga windows agent.
#        Does not require any command line parameters.
#
# Plugin Process: 
# 1. The plugin will check that Windows Server Backup command line interface is installed on the server.
#
# 2. Check if WSB is performing a process and report the process to the user.
# 
# 3. Check that WSB has performed at lest one backup
# 
# 4. Checks the date of the last sucessful backup and compare it to the last backup data. If both match return ok.
#    Checks the result of the last backup. If return code is 0 then display ok.
#
# 5. Checks the dates of the last sucessful backup and compares it to the last backup data. If both don't match return critical.
#    Checks the result of the last backup. If return code is not 0 then display Critical.
#
#6. If No vaild condition is found return unknown.
#====================================== 


#add the Windows Server Backup Snapin into the powershell session if not already added.

if ( (Get-PSSnapin -Name windows.serverbackup -ErrorAction SilentlyContinue) -eq $null )
{
        # continue script if snap in not found. this error will be corrected in next step
        Add-PsSnapin windows.serverbackup -ErrorAction SilentlyContinue   
}



#try to get WBS information. if failed report issue to user. 
try
{
    #get the backup summary information from the server.
    $backup = Get-WBSummary
}
catch
{
        $crticalString  = "CRITICAL: WSB or WSB CLI is not installed."
        Write-Output $crticalString
        exit 2
}



#collect and process the last backup time performed by the server.
$LastBackupTime =$backup.LastBackupTime


#collect and process the last SUCCESSFUL backup time performed by the server.
$LastSuccessfulBackupTime =$backup.LastSuccessfulBackupTime


#collect and process the Next backup time to be performed by the server.
$NextBackupTime =$backup.NextBackupTime

#collect and process the current backup operation status of the server.
$CurrentOperationStatus=$backup.CurrentOperationStatus
$CurrentOperationStatusString = ""+$CurrentOperationStatus

#collect and process the status of the last performed backup.
$LastBackupResultHR=$backup.LastBackupResultHR


#collect and process the current number of backups of the server.
$NumberOfVersions=$backup.NumberOfVersions
$NumberOfVersionsString = ""+$NumberOfVersions



#Check that the server is performing a backup operation or not. if so display this.
if ($CurrentOperationStatusString.CompareTo("NoOperationInProgress") -ne 0)
{
    $okString = "OK: WSB Performing Operation: "+$CurrentOperationStatusString
     Write-Output $okString
    exit 0
}
#check that there is backups on the backup storage, if not warn about the issue.
elseif ($NumberOfVersions -eq 0)
{
    $warnString = "WARNING: No backups found on server."
    Write-Output $warnString
    exit 1
}

#check for vaild backup on the server.
elseif((($LastBackupTime.CompareTo($LastSuccessfulBackupTime)) -eq 0)  -or ($LastBackupResultHR -eq 0 ))
{
    $okString = "OK: The last backup was successful. " + $NumberOfVersionsString + " backups on storage"
     Write-Output $okString
    exit 0
}
#Check that the last successful backup time matches the last performed backup time or check if last backup result is not 0
elseif((($LastBackupTime.CompareTo($LastSuccessfulBackupTime)) -ne 0)  -or ($LastBackupResultHR -ne 0 ))
{
    $crticalString  = "CRITICAL: Failed Backup – The most recent backup failed."
    Write-Output $crticalString
    exit 2

}
#No vaild condition found - Unknown state.
else
{
     $unknownString = "UNKNOWN: unknown result from WSB, Please check server"
     echo $unknownString
    exit 3
}