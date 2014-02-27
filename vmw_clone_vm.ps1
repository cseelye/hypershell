Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $Provisioning = "Thin",
  $SourceVm = "gold-win-esx",
  $DestinationDatastore = "datastore1",
  $DestinationPool = "pool1",
  $DestinationHost = "192.168.0.0",
  $CloneCount = 10,
  $CloneNamePre = "clone-",
  $CloneNamePost = "-win",
  $CloneStartNum = 1001
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
    $host_obj = Get-VMHost -name $DestinationHost
    $datastore = $host_obj | Get-Datastore -Name $DestinationDatastore

    if ($destination.IsStandalone)
    {
        $dest_pool = $host_obj | Get-ResourcePool -Name $DestinationPool
    }
    else
    {
        $cluster_name = $host_obj.Parent.Name
        $dest_pool = Get-Cluster -Name $cluster_name | Get-ResourcePool -Name $DestinationPool
    }


    Write-Host
    Log-Info "Cloning '$SourceVm' $CloneCount times to datastore '$DestinationDatastore'"
    $start_time = get-date
    Log-Info "Starting clones at $start_time"
    Write-Host
    $clone_tasks = @{}
    for ($clone_num = $CloneStartNum; $clone_num -lt ($CloneStartNum + $CloneCount); $clone_num++)
    {
        $clone_name = ("$CloneNamePre{0:000}$CloneNamePost" -f $clone_num)

        Log -Color Cyan "Starting clone '$clone_name'"
        $clone_task = new-vm -vm $SourceVm -datastore $datastore -VMHost $host_obj -ResourcePool $dest_pool -name $clone_name -runasync -DiskStorageFormat $Provisioning
        $clone_tasks[$clone_name] = $clone_task
    }
    Write-Host
    Log-Info "Waiting for all clones to complete..."
    $clone_names = @()
    while ($clone_tasks.Count -gt 0)
    {
        $names = $($clone_tasks.keys)
        foreach ($clone_name in $names)
        {
            $clone_task = $clone_tasks[$clone_name]
            # refresh the status of the task
            $clone_task = get-task | where {$_.Id -eq $clone_task.Id}
            $state = $clone_task.State
            if ($state -eq "Success")
            {
                Log -Color Green "    Clone '$clone_name' complete"
                $clone_tasks.Remove($clone_name)

                # boot the VM
                Log-Info "    Powering on '$clone_name'..."
                $start_task = get-vm -name $clone_name | start-vm -runasync
            }
            elseif ($state -eq "Error")
            {
                Log-Error ("    Clone '$clone_name' failed: " + $clone_task.extensiondata.info.error.localizedMessage)
                $clone_tasks.Remove($clone_name)
            }
        }
        if ($clone_tasks.Count -gt 0)
        {
            Start-Sleep -Seconds 15
        }
    }
    Write-Host
    $end_time = get-date
    $elapsed = $end_time - $start_time
    $elapsed_str = ("{0}-{1}:{2}:{3}.{4}" -f $elapsed.Days,$elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds,$elapsed.Milliseconds)
    Log-Info "Cloning finished at $end_time ($elapsed_str)"
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
