Param(
    $VmHost = "192.168.0.0",
    $VmName = ""
)

. ./libcs.ps1
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

log -Info "Finding $VmName"
$kill_vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName='$VmName'" -ComputerName $VmHost
if (-not $kill_vm)
{
    log -Error "Could not find VM $VmName"
    return
}
$vm_pid = $kill_vm.ProcessID

if ($vm_pid -le 0)
{
    log -Info "$VmName is already stopped"
    return
}
log -Info "Killing PID $vm_pid"
$script = $ExecutionContext.InvokeCommand.NewScriptBlock("Stop-Process -Id $vm_pid -Force")
Invoke-Command -ComputerName $VmHost -ScriptBlock $script

