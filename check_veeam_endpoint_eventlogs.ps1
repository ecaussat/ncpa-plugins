#############################################################################
# Script name:	check_veeam_endpoint_eventlogs.ps1
# Version: 	2.0
# Edit on: 	16/11/2018
# Author: 	RPR
# Purpose: 	Check Veeam Endpoint Backup success or failure via event logs
# Note: 	does NOT use PowerShell plug-in 
#############################################################################

# Pull in arguments
$ArgLogName = "Veeam Endpoint Backup" # veeam backup event log
$ArgEntryType = 1,2,3,4 # look for critical, error, warning and informational logs
$ArgProviderName = "Veeam Endpoint Backup"
$ArgEventID = 190 # backup job complete event id

$ArgLastHours = $args[0]

# Reconstruire et afficher la ligne de commande complète
$commandLine = "$($MyInvocation.InvocationName) " + ($args -join ' ')
#Write-Host "Complete Command: $commandLine"


# Setting default values if null 
if (!$ArgLastHours) { $ArgLastHours = (24) }
if (!$ArgWarningTH) { $ArgWarningTH = 0 }
if (!$ArgCriticalTH) { $ArgCriticalTH = 0 }
if (!$ArgMaxEntries) { $ArgMaxEntries = 50 }

$CriticalErrorResultCount = 0
$WarningResultCount = 0
$InfoResultCount = 0
$EventTypeLoopCount = 0
$LogNameLoopCount = 0
$ProviderNameLoopCount = 0
$EventIDLoopCount = 0
$ExitCode = 0

$Properties='Level','Message','ProviderName','TimeCreated','Id'

$Filter = @{
    LogName = $ArgLogName
    StartTime = (Get-Date).AddHours(-$ArgLastHours)
}

if($ArgProviderName) { $Filter += @{ProviderName = $ArgProviderName } }
if($ArgEventID) { $Filter += @{Id = $ArgEventID } }
if($ArgEntryType) { $Filter += @{Level = $ArgEntryType } }

# -ea SilentlyContinue gets rid of non-terminating error resulting from zero events
$LogEntries = Get-WinEvent -MaxEvents $ArgMaxEntries -FilterHashtable $Filter -ea SilentlyContinue -Oldest | Select-Object -Property $Properties 

if ($LogEntries) {

    ForEach ($LogEntry in $LogEntries) {
		if ($LogEntry.Message.ToString() -like "*EndpointBackup job `'Backup Job*")
		{
        $Level=$LogEntry.Level.ToString()
		if (($Level -eq 1) -Or ($Level -eq 2)) # find critical and errors
		{
		$Message=$LogEntry.Message.Substring(0,[System.Math]::Min(180, $LogEntry.Message.Length)).TrimEnd().ToString()
		$ProviderName=$LogEntry.ProviderName.ToString()
        $TimeCreated=$LogEntry.TimeCreated.ToString()
        $Id=$LogEntry.Id.ToString()
        $CriticalErrorResultCount++ 
         
                $CriticalErrorResults=@"
				
At: $TimeCreated
Level: $Level 
Event ID: $Id
Message: $Message
Source: $ProviderName
$CriticalErrorResults
"@
		}
		elseif ($Level -eq 3) # find warnings
		{
		$Message=$LogEntry.Message.Substring(0,[System.Math]::Min(180, $LogEntry.Message.Length)).TrimEnd().ToString()
		$ProviderName=$LogEntry.ProviderName.ToString()
        $TimeCreated=$LogEntry.TimeCreated.ToString()
        $Id=$LogEntry.Id.ToString()
        $WarningResultCount++ 
         
                $WarningResults=@"
At: $TimeCreated
Level: $Level 
Event ID: $Id
Message: $Message
Source: $ProviderName
$WarningResults
"@
		}
		else # all that's left, find info (4) messages
		{
		$Message=$LogEntry.Message.Substring(0,[System.Math]::Min(180, $LogEntry.Message.Length)).TrimEnd().ToString()
		$ProviderName=$LogEntry.ProviderName.ToString()
        $TimeCreated=$LogEntry.TimeCreated.ToString()
        $Id=$LogEntry.Id.ToString()
        $InfoResultCount++ 
         
                $InfoResults=@"
				
At: $TimeCreated
Level: $Level 
Event ID: $Id
Message: $Message
Source: $ProviderName
$InfoResults
"@
		}
    }

}

}

$Results= @"
$CriticalErrorResults $WarningResults $InfoResults
"@

if ($ArgEntryType) {
$TypeArray = @("all level","critical","error","warning","informational")
$LevelString = foreach ($Entry in $ArgEntryType) { 
	if ($ArgEntryType.Count -gt 1) { 
	$LevelStringBuild = $TypeArray[$Entry]
		if ($ArgEntryType.Count -ne $EventTypeLoopCount+1) {
		$LevelStringBuild +=","
		}
	}

	else { $LevelStringBuild = $TypeArray[$Entry] }
	$EventTypeLoopCount++
	$LevelStringBuild
	}
}

$LogNameString = foreach ($LogNameEntry in $ArgLogName) { 
	$LogNameStringBuild += $LogNameEntry
	if ($ArgLogName.Count -gt 1 -And $ArgLogName.Count -ne $LogNameLoopCount+1) {
		$LogNameStringBuild += ", "
		}
	$LogNameLoopCount++
	}

$ProviderNameString = foreach ($ProviderNameEntry in $ArgProviderName) { 
	$ProviderNameStringBuild += $ProviderNameEntry
	if ($ArgProviderName.Count -gt 1 -And $ArgProviderName.Count -ne $ProviderNameLoopCount+1) {
		$ProviderNameStringBuild += ", "
		}
	$ProviderNameLoopCount++
	}

$EventIDString = foreach ($EventIDEntry in $ArgEventID) { 
	$EventIDStringBuild += "$EventIDEntry"
	if ($ArgEventID.Count -gt 1 -And $ArgEventID.Count -ne $EventIDLoopCount+1) {
		$EventIDStringBuild += ", "
		}
	$EventIDLoopCount++
	}	

If ($CriticalErrorResultCount -gt 0) {
        $ResultString += "Backup failed: $CriticalErrorResultCount critical error(s) for backup job in last $ArgLastHours hours "
		$NagiosMetricString += "'Errors'=$CriticalErrorResultCount 'BackupUnknown'=1 "
		$ExitCode = 2
    }

If ($WarningResultCount -gt 0) {
        $ResultString += "Warning: backup job had $WarningResultCount warning message(s) in the last $ArgLastHours hours "
		If ($ExitCode -ne 2) {
		$NagiosMetricString += "'BackupUnknown'=1 "	
		$ExitCode = 1
		}
		$NagiosMetricString += "'Warnings'=$WarningResultCount "
		
    }

If (($InfoResultCount -lt 1) -And ($ExitCode -ne 1) -And ($ExitCode -ne 2)) {
        $ResultString += "Backup failed: backup job has not run in last $ArgLastHours hours "
		$NagiosMetricString += "'BackupNotRun'=1 "
		$ExitCode = 2
    }
	
If (($InfoResultCount -ge 1) -And ($CriticalErrorResultCount -eq 0 ) -And ($WarningResultCount -eq 0 )){
        $ResultString += "OK: backup job completed successfully in last $ArgLastHours hours "
		$NagiosMetricString = "'BackupSuccess'=1 "
		$ExitCode = 0
    }

	write-host $ResultString 
	write-host $Results 
	write-host $ResultString"|"$NagiosMetricString
exit $ExitCode