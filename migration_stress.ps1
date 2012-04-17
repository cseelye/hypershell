Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $VmCount = 5,
  $WaitTime = 10,
  $PoolName = "MigrationStress",
  $DestinationDatastore = "datastore2"
)

# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

. ./libcs.ps1
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

log
log -Info "Connecting to vSphere"
$viserver = Connect-VIServer -Server $VcServer -User $Username -Password $Password

$cluster = Get-Cluster -Name $ClusterName

while ($true)
{
    log -Info "Finding VMs in pool $PoolName"
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
        log -Color Cyan ("Migrating $vm to datastore $DestinationDatastore")
        
        $tasks += $vm | Move-VM -Datastore $DestinationDatastore -Confirm:$false -RunAsync
    }
    $tasks | Wait-Task | Out-Null
    log -Color Green "All VMs migrated."

    # Move VM back to old datastore
    $tasks = @()
    foreach ($vm in $vms_to_vm)
    {
        $ds = $old_ds[$vm];
        $dsname = $ds.Name
                
        # Migrate the VM to the old datastore
        log -Color Cyan ("Migrating $vm back to datastore $dsname")
        
        $tasks += $vm | Move-VM -Datastore $ds -Confirm:$false -RunAsync
    }
    $tasks | Wait-Task | Out-Null

    Write-Host "Waiting for $WaitTime seconds..."
    $remaining = $WaitTime
    while ($remaining -gt 0)
    {
        Write-Host "    Continuing test in $remaining sec"
        Start-Sleep 1
        $remaining--
    }
}








Write-Host
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
