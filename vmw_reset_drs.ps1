Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $PoolName = "Resources" # the 'Resources' pool is the root level pool all VMs are in
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

log -Info "Setting DRS policy to [cluster default] for VMs in pool $PoolName"
$tasks = Get-ResourcePool -Name $PoolName | Get-VM | Set-VM -DrsAutomationLevel AsSpecifiedByCluster -Confirm:$false -RunAsync
$tasks | Wait-Task

log
Disconnect-VIServer -Server * -Force -Confirm:$false | Out-Null
