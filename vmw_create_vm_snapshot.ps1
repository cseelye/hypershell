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
    log -Color Cyan "Taking a snapshot of $vm"
    $snap_name = "PowerCLI snapshot $datestamp"
    $tasks += $vm | New-Snapshot -Name $snap_name -Memory:$true -Quiesce:$true -RunAsync
}
log -Info "Waiting for snapshots to complete"
foreach ($task in $tasks)
{
    $vm_id = $task.ObjectId
    $vm = Get-VM -Id $vm_id
    log -Debug "Waiting for snap on $vm"
    #Wait-Task -Task $task
    $tv = $task | Get-View
    $tv.WaitForTask($tv.MoRef) | Out-Null
}
log -Color Green "All snapshots have finished"

log
disconnect-viserver -server * -force -confirm:$false | out-null
