Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $SourcePool = "pool1",
  $DestPool = "pool2",
  $VmCount = 25
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

$source = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $SourcePool
$dest = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $DestPool

$vm_list = $source | Get-VM -NoRecursion
$vm_list = $vm_list | Sort-Object

$count = 1
foreach ($vm in $vm_list)
{
    log -Color Cyan "Moving $vm to pool $DestPool"
    $vm | Move-VM -Destination $dest | Out-Null
    $count++
    if ($count -gt $VmCount)
    {
        break
    }
}

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
