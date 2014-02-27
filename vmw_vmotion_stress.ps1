Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $VmCount = 5,
  $WaitTime = 10,
  $PoolName = "vMotionStress"
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
$Host.UI.RawUI.WindowTitle = "vMotion Stress Test - $ClusterName - $PoolName"

$cluster = Get-Cluster -Name $ClusterName

# Set the DRS policy of the VMs in this pool to manual
log -Info "Setting DRS policy to Manual on VMs in pool $PoolName"
$vms2modify = $cluster | Get-ResourcePool -Name $PoolName | Get-VM | Where { $_.DrsAutomationLevel -ne "Manual" }
if ($vms2modify.Count -gt 0)
{
    $tasks = $vms2modify | Set-VM -DrsAutomationLevel Manual -Confirm:$false -RunAsync
    $tasks | Wait-Task | Out-Null
}

while ($true)
{
    log -Info "Finding VMs in pool $PoolName in cluster $ClusterName"
    $pool = $cluster | Get-ResourcePool -Name $PoolName
    $vm_list = $pool | Get-VM
    $vm_count = $vm_list.Count
    if ($VmCount > $vm_count)
    {
        $VmCount = $vm_count
    }
    $vms_to_vm = $vm_list | Get-Random -Count $VmCount
    $vms_to_vm = $vms_to_vm | Sort-Object
    
    $tasks = @()
    foreach ($vm in $vms_to_vm)
    {
        # Pick a new host for the VM
        $current_host = $vm.VmHost
        do
        {
            $new_host = $cluster | Get-VMHost | Get-Random
        }
        until ($new_host -ne $current_host)
        
        # vMotion the VM to the new host
        log -Color Cyan "vMotioning $vm to host $new_host"
        
        $tasks += $vm | Move-VM -Destination $new_host -Confirm:$false -RunAsync
    }
    $tasks | Wait-Task | Out-Null
    log -Color Green "All VMs moved successfully"

    log -Info "Waiting for $WaitTime seconds..."
    $remaining = $WaitTime
    while ($remaining -gt 0)
    {
        log -Color Gray "    Continuing test in $remaining sec"
        Start-Sleep 1
        $remaining--
    }
}

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
