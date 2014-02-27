Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster" # leave empty for all clusters
)
# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
. ./libcs.ps1

log
log -Info "Connecting to $VcServer"
$viserver = connect-viserver -server $VcServer -user $Username -password $Password

if ([string]::IsNullOrEmpty($ClusterName))
{
    log -Info "Finding all VMs with snapshots"
    $vm_list = Get-VM
}
else
{
    log -Info "Finding all VMs with snapshots in cluster $ClusterName"
    $vm_list = Get-Cluster -Name $ClusterName | Get-VM | Sort-Object
}
$vm_snaps = @()
foreach ($vm in $vm_list) 
{
    $snap_list = $vm | Get-Snapshot
    if (@($snap_list).Count -le 0)
    {
        continue
    }
    log -Info ("$vm has " + @($snap_list).Count + " snapshots")
    foreach ($snap in $snap_list)
    {
        log -Info ("  " + $snap)
    }
}
