<#
    .SYNOPSIS
        A script for installing a vCenter Server Appliance
    .DESCRIPTION
        The script will deploy a vCenter Server Appliance with the
        help of a json file used for unattended installation

        The installation is built for a nested lab environment used
        by Proact IT Norge AS.

        The deployment process relies heavily on the work done by
        William Lam, virtuallyghetto.com
    .LINK

    .NOTES
        Author: Rudi Martinsen / Proact IT Norge AS
        Created: 21/3-2020
        Version: 0.3.0
        Changelog:
        0.3.0 -- Parameterized some more variables
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
    .PARAMETER AddHosts
        Parameter to control if hosts should be added to the deployed vCenter or not
    .PARAMETER NumHosts
        The number of ESXi hosts to add, parameter used to calculate host names
    .PARAMETER DomainName
        The domain name of the environment
    .PARAMETER IsoHost
        The server that hosts the VCSA ISO. Note that the host needs to have a share VCSA with
        the extracted iso sorted in folders with the version number
    .PARAMETER VIUserName
        The username for the hosting vCenter
    .PARAMETER VIPassword
        vCenter users password
#>
##############
# Parameters #
##############
$EnvName = "<EnvName>"
$VCenter = "<VCenter>"
$Datacenter = "<Datacenter>"
$Network = "<Network>"
$Datastore = "<Datastore>"
$Cluster = "<Cluster>" 
$AddHosts = "<AddHosts>"
$NumHosts = "<NumHosts>"
$domainName = "<DomainName>"
$isoHost = "<IsoHost>"
$VIUserName = "<VIUser>"
$VIPassword = "<VIPassword>"

$Version = "14367737"


$mountpath = "\\$isoHost\vcsa\$version"
$vmName = $envName + "-vcsa-01" #." + $envName + ".$domainName"
$systemName = "vcsa-01." + $envName + ".$domainName"
$VIServer = $VCenter

$VCSADeploymentSize = "small"
$VCSADisplayName = $vmName
$VCSAIPAddress = "192.168.101.20"
$VMDNS = "192.168.101.11"
$VCSAPrefix = "24"
$VMGateway = "192.168.101.1"
$VCSAHostname = $systemName
$VCSARootPassword = "VMware1!"
$VCSASSHEnable = $true
$VMNTP = "ntp.uio.no"
$VCSASSOPassword = "VMware1!"
$VCSASSODomainName = "vsphere.local"

#### DO NOT EDIT BELOW THIS LINE ####


$config = (Get-Content -Raw "$mountpath\vcsa-cli-installer\templates\install\embedded_vCSA_on_VC.json") | convertfrom-json
$config.new_vcsa.vc.hostname = $VIServer
$config.new_vcsa.vc.username = $VIUsername
$config.new_vcsa.vc.password = $VIPassword
$config.new_vcsa.vc.deployment_network = $Network
$config.new_vcsa.vc.datastore = $datastore
$config.new_vcsa.vc.datacenter = $datacenter
$config.new_vcsa.vc.target = $Cluster
$config.new_vcsa.appliance.thin_disk_mode = $true
$config.new_vcsa.appliance.deployment_option = $VCSADeploymentSize
$config.new_vcsa.appliance.name = $VCSADisplayName
$config.new_vcsa.network.ip_family = "ipv4"
$config.new_vcsa.network.mode = "static"
$config.new_vcsa.network.ip = $VCSAIPAddress
$config.new_vcsa.network.dns_servers[0] = $VMDNS
$config.new_vcsa.network.prefix = $VCSAPrefix
$config.new_vcsa.network.gateway = $VMGateway
$config.new_vcsa.network.system_name = $VCSAHostname
$config.new_vcsa.os.password = $VCSARootPassword
if($VCSASSHEnable -eq "true") {
    $VCSASSHEnableVar = $true
} else {
    $VCSASSHEnableVar = $false
}
$config.new_vcsa.os.ntp_servers = $VMNTP
$config.new_vcsa.os.ssh_enable = $VCSASSHEnableVar
$config.new_vcsa.sso.password = $VCSASSOPassword
$config.new_vcsa.sso.domain_name = $VCSASSODomainName

$config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json"

#Run the installer
Invoke-Expression "$mountPath\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"

#Configure VC
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope session -Confirm:$false
$vc = Connect-VIServer $systemName -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue
$vcDc = New-Datacenter -Name Datacenter -Server $vc -Location (Get-Folder -Type Datacenter -Server $vc)
if($AddHosts -eq "yes"){
    $cluster = New-Cluster -Name C1 -Location $vcDc

    for($i=1;$i -le $NumHosts;$i++){
        if($i -lt 10){
            $num="0"+$i
        }
        else{
            $num=$i
        }
        $esxiName = "esx-$num.$envName.$domainName"
        Add-VMHost -Name $esxiName -Location $cluster -User root -Password VMware1! -Force
    }
}
