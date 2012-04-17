﻿Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "SnapshotStress"
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

$vm_list = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName | Get-VM
$vm_list = $vm_list | Sort-Object

$datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$tasks = @()
foreach ($vm in $vm_list)
{
    $snap_list = $vm | Get-Snapshot
    if (@($snap_list).Count -le 0)
    {
        log -Warn "There are no snapshots on $vm"
        continue
    }
    $snap = @($snap_list)[0]
    
    log -Color Cyan "Deleting snap $snap from $vm"
    $tasks += $snap | Remove-Snapshot -Confirm:$false -RunAsync
}
log -Info "Waiting for delete to complete on all VMs"
$tasks | Wait-Task | Out-Null
log -Color Green "All VMs have finished deleting snapshots"

log
disconnect-viserver -server * -force -confirm:$false | out-null