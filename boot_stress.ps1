Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $VmCount = 5,
  $WaitTime = 10,
  $PoolName = "BootStress"
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

while ($true)
{
    log -Info "Finding VMs in pool $PoolName in cluster $ClusterName"
    $pool = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName
    $vm_list = $pool | Get-VM
    $vm_count = $vm_list.Count
    if ($VmCount > $vm_count)
    {
        $VmCount = $vm_count
    }
    $vms_to_boot = $vm_list | Get-Random -Count $VmCount
    $vms_to_boot = $vms_to_boot | Sort-Object

    # Send the shutdown to the VM gues
    foreach ($vm in $vms_to_boot)
    {
        $vmname = $vm.Name
        if ($vm.PowerState -ne "PoweredOn")
        {
            log -Warn "$vmname is already powered off"
        }
        else
        {
            log -Color cyan "Shutting down guest in $vmname"
            $vm | Shutdown-VMGuest -Confirm:$false | Out-Null
        }
    }
    
    # Wait for all VMs to finish shut down
    log -Info "Waiting for VMs to shut down..."
    do
    {
        Start-Sleep 2
        # Refresh status
        $vms_to_boot = $pool | Get-VM | where { $vms_to_boot -contains $_ }
    }
    until (@($vms_to_boot | Where { $_.PowerState -eq "PoweredOff" }).Count -eq $VmCount)
    log -Color Green "VMs are shut down."
    
    # Start the VMs
    $tasks = @()
    foreach ($vm in $vms_to_boot)
    {
        $vmname = $vm.Name
        log -Color cyan "Powering on $vmname"
        
        $tasks += $vm | Start-VM -Confirm:$false -RunAsync
    }
    $tasks | Wait-Task | Out-Null
    
    # Wait for VMs to be fully up
    log -Info "Waiting for VMs to boot up..."
    do
    {
        Start-Sleep 2
        # Refresh status
        $test = $pool | Get-VM | where { $vms_to_boot -contains $_ } | Get-View
    }
    until (@($test | Where { $_.Guest.ToolsRunningStatus -eq "guestToolsRunning" }).Count -eq $VmCount)
    log -Color Green "VMs are up."

    log -Info "Waiting for $WaitTime seconds..."
    $remaining = $WaitTime
    while ($remaining -gt 0)
    {
        log -Color gray "    Continuing test in $remaining sec"
        Start-Sleep 1
        $remaining--
    }
}

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
