Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $VmHost = "192.168.0.0"
)
# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

. ./libcs.ps1
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
log
log -Info "Connecting to vSphere"
$viserver = connect-viserver -server $VcServer -user $Username -password $Password

# Rescan the host

$host_obj = Get-VMHost -Name $VmHost
if ($host_obj.IsStandalone)
{
    # Rescan this host
    log -Info "Rescanning HBAs on $VmHost..."
    Get-VMHostStorage -VMHost $VmHost -RescanAllHba -RescanVmfs | Out-Null
}
else
{
    # Rescan the entire cluster
    $cluster_name = $host_obj.Parent.Name
    log -Info "Rescanning all hosts in cluster $cluster_name"
    Get-Cluster -Name $cluster_name | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null
}

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
