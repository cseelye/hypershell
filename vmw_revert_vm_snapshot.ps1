Param(
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
    log -Color Cyan "Reverting $vm to snap $snap"
    $tasks += $vm | Set-VM -Snapshot $snap -Confirm:$false -RunAsync
}
log -Info "Waiting for revert to complete on all VMs"
Start-Sleep 10
foreach ($task in $tasks)
{
    $vm_id = $task.ObjectId
    $vm = Get-VM -Id $vm_id
    log -Debug "Waiting for snap revert on $vm"
    #Wait-Task -Task $task
    $tv = $task | Get-View
    $tv.WaitForTask($tv.MoRef) | Out-Null
}
log -Color Green "All VMs have finished reverting to snapshot"

log
disconnect-viserver -server * -force -confirm:$false | out-null
