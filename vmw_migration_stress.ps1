Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $VmCount = 5,
  $WaitTime = 10,
  $PoolName = "MigrationStress",
  $DestinationDatastore = "datastore2"
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
    Log-Info "Connecting to vSphere"
    $viserver = Connect-VIServer -Server $MgmtServer -User $Username -Password $Password
    $Host.UI.RawUI.WindowTitle = "Migration Stress Test - $ClusterName - $PoolName"

    $cluster = Get-Cluster -Name $ClusterName

    while ($true)
    {
        Log-Info "Finding VMs in pool $PoolName"
        $pool = $cluster | Get-ResourcePool -Name $PoolName
        $vm_list = $pool | Get-VM
        $vm_count = $vm_list.Count
        if ($VmCount > $vm_count)
        {
            $VmCount = $vm_count
        }
        $vms_to_vm = $vm_list | Get-Random -Count $VmCount
        $vms_to_vm = $vms_to_vm | Sort-Object

        # Move VM to new datastore
        $old_ds = @{}
        $tasks = @()
        foreach ($vm in $vms_to_vm)
        {
            $old_ds[$vm] = $vm | Get-Datastore

            # Migrate the VM to the new datastore
            Log -Color Cyan ("Migrating $vm to datastore $DestinationDatastore")

            $tasks += $vm | Move-VM -Datastore $DestinationDatastore -Confirm:$false -RunAsync
        }
        $tasks | Wait-Task | Out-Null
        Log -Color Green "All VMs migrated."

        # Move VM back to old datastore
        $tasks = @()
        foreach ($vm in $vms_to_vm)
        {
            $ds = $old_ds[$vm];
            $dsname = $ds.Name

            # Migrate the VM to the old datastore
            Log -Color Cyan ("Migrating $vm back to datastore $dsname")

            $tasks += $vm | Move-VM -Datastore $ds -Confirm:$false -RunAsync
        }
        $tasks | Wait-Task | Out-Null
        Log -Color Green "All VMs migrated back"

        Log-Info "Waiting for $WaitTime seconds..."
        $remaining = $WaitTime
        while ($remaining -gt 0)
        {
            Log -Color Gray "    Continuing test in $remaining sec"
            Start-Sleep 1
            $remaining--
        }
    }

    Write-Host
    Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
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
