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
        Log -Color Cyan "Taking a snapshot of $vm"
        $snap_name = "PowerCLI snapshot $datestamp"
        $tasks += $vm | New-Snapshot -Name $snap_name -Memory:$true -Quiesce:$true -RunAsync
    }
    Log-Info "Waiting for snapshots to complete"
    foreach ($task in $tasks)
    {
        $vm_id = $task.ObjectId
        $vm = Get-VM -Id $vm_id
        Log-Debug "Waiting for snap on $vm"
        #Wait-Task -Task $task
        $tv = $task | Get-View
        $tv.WaitForTask($tv.MoRef) | Out-Null
    }
    Log -Color Green "All snapshots have finished"

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
