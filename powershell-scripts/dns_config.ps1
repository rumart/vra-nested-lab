<#
    .SYNOPSIS
        A script for installing and configuring DNS server
    .DESCRIPTION
        The script will install DNS server and configure a forward
        and reverse lookup zone

        The installation is built for a nested lab environment used
        by Proact IT Norge AS.
    .LINK
        https://rudimartinsen.com/2020/04/12/deploying-a-nested-lab-environment-with-vra-part-1/
    .NOTES
        Author: Rudi Martinsen / Proact IT Norge AS
        Created: 21/3-2020
        Version: 0.2.1
        Revised: 12/4-2020
        Changelog:
        0.2.1 -- Added vcenter CNAME
        0.2.0 -- Removed environment from systemname prefix
    .PARAMETER EnvName
        Environment/deployment name
    .PARAMETER VCenter
        The vCenter to deploy the VM on
    .PARAMETER Datacenter
        The datacenter folder
    .PARAMETER Network
        The portgroup to connect the VM to
    .PARAMETER Datastore
        The datastore to deploy the VM on
    .PARAMETER Cluster
        The cluster to deploy the VM in
    .PARAMETER Version
        The version to deploy
    .PARAMETER AddHosts
        Parameter to control if the script should add ESXi hosts to the deployed vCenter
    .PARAMETER NumHosts
        The number of hosts that are deployed and that should be added to vCenter
#>
##############
# Parameters #
##############
#Variables to be replaced in vRO
$NumESXi = <NumESXi>


$NetworkId = "192.168.101.0/24"
#$ESXiPrefix = (($ZoneName_FW).split("."))[0] + "-n-esx-"
$ESXiPrefix = "esx-"
$vcsaName = "vcsa-01"
$ZoneFile_FW = $ZoneName_FW
$netSplit = $NetworkId.split(".")
$ReverseSuffix = ".in-addr.arpa.dns"
$ZoneFile_RV = $netSplit[2] + "." + $netSplit[1] + "." + $netSplit[0] + $ReverseSuffix
#$vcsaName = (($ZoneName_FW).split("."))[0] + "-n-vcsa-01"

$vcsaIP = $netSplit[0] + "." + $netSplit[1] + "." + $netSplit[2] + "." + 20

#Install DNS server
Install-WindowsFeature DNS -IncludeManagementTools

#Create zone files
Add-DnsServerPrimaryZone -ZoneFile $ZoneFile_FW -Name $ZoneName_FW
Add-DnsServerPrimaryZone -NetworkID $NetworkId -ZoneFile $ZoneFile_RV

#Add A records for the ESXi hosts
for($i=1;$i -le $numEsxi;$i++){
    $num="{0:00}" -f $i
    $name = $ESXiPrefix + $num
    $ip = $netSplit[0] + "." + $netSplit[1] + "." + $netSplit[2] + ".1" + $num
    Add-DnsServerResourceRecord -ZoneName $ZoneName_FW -CreatePtr -Name $name -IPv4Address $ip -A
}

#Add A record for the VCSA
Add-DnsServerResourceRecord -ZoneName $ZoneName_FW -CreatePtr -Name $vcsaName -IPv4Address $vcsaIP -A

#Add CNAME for the VCSA
Add-DnsServerResourceRecordCName -Name vcenter -HostNameAlias ($vcsaName + ".$ZoneName_FW") -ZoneName $ZoneName_FW