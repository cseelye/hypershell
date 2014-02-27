Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "SnapshotStress"
)
Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    Add-PSSnapin "Vmware.VimAutomation.Core" | Out-Null
    Import-Module -DisableNameChecking .\csutil.psm1

    Write-Host
    Log-Info "Connecting to $MgmtServer"
    $viserver = connect-viserver -server $MgmtServer -user $Username -password $Password

    $vm_list = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName | Get-VM
    $vm_list = $vm_list | Sort-Object

    $datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tasks = @()
    foreach ($vm in $vm_list)
    {
        $snap_list = $vm | Get-Snapshot
        if (@($snap_list).Count -le 0)
        {
            Log-Warn "There are no snapshots on $vm"
            continue
        }
        $snap = @($snap_list)[0]

        Log -Color Cyan "Deleting snap '$snap' from $vm"
        $tasks += $snap | Remove-Snapshot -Confirm:$false -RunAsync
    }
    Log-Info "Waiting for delete to complete on all VMs"
    Start-Sleep 10
    foreach ($task in $tasks)
    {
        $vm_id = $task.ObjectId
        $vm = Get-VM -Id $vm_id
        Log-Debug "Waiting for snap delete on $vm"
        #Wait-Task -Task $task
        $tv = $task | Get-View
        $tv.WaitForTask($tv.MoRef) | Out-Null
    }
    Log -Color Green "All VMs have finished deleting snapshots"

    Write-Host
    disconnect-viserver -server * -force -confirm:$false | out-null
}
catch
{
    $err_message = $_.ToString() + "`n`t" + $_.ScriptStackTrace
    try { Log-Error $err_message }
    catch { Write-Host $err_message }
    exit 1
}
finally
{
    try { Reinstate-Log } catch {}
    Write-Host
}
