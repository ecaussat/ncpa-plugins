# Utilisation du script :

# 1) S'assurer du chemin de snmpget.exe, et de sa présence
$exe = "C:\Program Files\NSClient++\snmpget.exe"

# 2) Modifier l'adresse IP 
$IProuteur = "192.168.80.254";

# 3) Indiquer l'interface à monitorer (ajouter 1 à l'interface : X1 => 2, X2 => 3, etc.)
$interface = 2


# On récupère les informations de l'interface en SNMP
$inQueueFirst = &$exe -q -r:$IProuteur -c:smartit -o:.1.3.6.1.2.1.2.2.1.10.$interface
$outQueueFirst = &$exe -q -r:$IProuteur -c:smartit -o:.1.3.6.1.2.1.2.2.1.16.$interface


$maxIn = 0
$maxOut = 0

$inQueue = 0
$outQueue = 0

$previousInQueue = $inQueueFirst
$previousOutQueue = $outQueueFirst

# Echantillonnage
$sleep = 6
$echantillon = $sleep*10

$val=0

while($val -ne 9) {

start-sleep -s $sleep

$inQueue = &$exe -q -r:$IProuteur -c:smartit -o:.1.3.6.1.2.1.2.2.1.10.$interface
$outQueue = &$exe -q -r:$IProuteur -c:smartit -o:.1.3.6.1.2.1.2.2.1.16.$interface

$diffInQueue = [math]::Round((($inQueue/1000)-($previousInQueue/1000)))
$diffOutQueue = [math]::Round((($outQueue/1000)-($previousOutQueue/1000)))

if(($maxIn -lt $diffInQueue) -And ($diffInQueue -gt 0)) {$maxIn=$diffInQueue}
if(($maxOut -lt $diffOutQueue) -And ($diffOutQueue -gt 0)) {$maxOut=$diffOutQueue}

$previousInQueue = $inQueue
$previousOutQueue = $outQueue

$val++
}


$totalIn = [math]::Round(($inQueue/1000)-($inQueueFirst/1000))
$totalOut = [math]::Round(($outQueue/1000)-($outQueueFirst/1000))

$totalInKbps = [math]::Round($totalIn/$echantillon*8)
$totalOutKbps = [math]::Round($totalOut/$echantillon*8)

$maxIn = [math]::Round($maxIn/$sleep*8)
$maxOut = [math]::Round($maxOut/$sleep*8)


if($maxOut -le 0){exit 2}
elseif($maxIn -le 0){exit 2}
else {
    Write-Output "In: ${totalInKbps}Kbps ; MaxIn: ${maxIn}Kbps" "Out: ${totalOutKbps}Kbps ; MaxOut: ${maxOut}Kbps|'In'=$totalInKbps 'Out'=$totalOutKbps"
    exit 0
 }