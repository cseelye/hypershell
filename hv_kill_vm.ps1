Param(
    $VmHost = "192.168.0.0",
    $VmName = ""
)

Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    Log-Info "Finding $VmName"
    $kill_vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName='$VmName'" -ComputerName $VmHost
    if (-not $kill_vm)
    {
        Log-Error "Could not find VM $VmName"
        return
    }
    $vm_pid = $kill_vm.ProcessID

    if ($vm_pid -le 0)
    {
        Log-Info "$VmName is already stopped"
        return
    }
    Log-Info "Killing PID $vm_pid"
    $script = $ExecutionContext.InvokeCommand.NewScriptBlock("Stop-Process -Id $vm_pid -Force")
    Invoke-Command -ComputerName $VmHost -ScriptBlock $script
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
