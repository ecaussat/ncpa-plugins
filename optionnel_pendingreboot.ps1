$ComputerName = $env:COMPUTERNAME
$PendingReboot = $false

$HKLM = [UInt32] "0x80000002"
$WMI_Reg = [WMIClass] "\\$ComputerName\root\default:StdRegProv"

if ($WMI_Reg) {
    if (($WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\")).sNames -contains 'RebootPending') {
        $PendingReboot = $true
    }
    if (($WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")).sNames -contains 'RebootRequired') {
        $PendingReboot = $true
    }

    # Checking for SCCM namespace
    $SCCM_Namespace = Get-WmiObject -Namespace ROOT\CCM\ClientSDK -List -ComputerName $ComputerName -ErrorAction Ignore
    if ($SCCM_Namespace) {
        if (([WmiClass]"\\$ComputerName\ROOT\CCM\ClientSDK:CCM_ClientUtilities").DetermineIfRebootPending().RebootPending -eq $true) {
            $PendingReboot = $true
        }
    }

    if ($PendingReboot) {
        Write-Host "WARNING : Redemarrage requis"
        exit 1
    } else {
        Write-Host "OK : Pas de redemarrage attendu"
        exit 0
    }
} else {
    Write-Host "UNKNOWN! Unable to access WMI registry"
    exit 3
}
