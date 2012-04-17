Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "pool1"
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

log -Info "Finding VMs in pool $PoolName in cluster $ClusterName"
$pool = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName
$vm_list = $pool | Get-VM | Sort-Object

# Shut down VMs
foreach ($vm in $vm_list)
{
    if ($vm.PowerState -ne "poweredon")
    {
        log -Info "$vm is not powered on"
        continue
    }
    log -Color Cyan "Shutting down guest in $vm"
    $vm | Shutdown-VMGuest -Confirm:$false | Out-Null
}

# Wait for all VMs to finish shut down
log -Info "Waiting for VMs to shut down..."
do
{
    Start-Sleep 2
    # Refresh status
    $vm_list = $pool | Get-VM | Sort-Object
}
until (@($vm_list | Where { $_.PowerState -eq "PoweredOff" }).Count -eq $vm_list.Count)
log -Color Green "All VMs are shut down."

# Start the VMs
$tasks = @()
foreach ($vm in $vm_list)
{
    log -Color cyan "Powering on $vm"
    
    $tasks += $vm | Start-VM -Confirm:$false -RunAsync
}
$tasks | Wait-Task | Out-Null

# Wait for VMs to be fully up
log -Info "Waiting for VMs to boot up..."
do
{
    Start-Sleep 2
    # Refresh status
    $test = $pool | Get-VM | Get-View
}
until (@($test | Where { $_.Guest.ToolsRunningStatus -eq "guestToolsRunning" }).Count -eq $vm_list.Count)
log -Color Green "All VMs are up."
