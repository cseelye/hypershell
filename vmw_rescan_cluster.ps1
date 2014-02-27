Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster"
)

# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
log
log -Info "Connecting to vSphere"
$viserver = Connect-VIServer -Server $VcServer -User $Username -Password $Password

log -Info "Rescanning all hosts in cluster $cluster_name"
Get-Cluster -Name $ClusterName | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
