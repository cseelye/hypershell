Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $PoolName = "Resources" # the 'Resources' pool is the root level pool all VMs are in
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

    Log-Info "Setting DRS policy to [cluster default] for VMs in pool $PoolName"
    $tasks = Get-ResourcePool -Name $PoolName | Get-VM | Set-VM -DrsAutomationLevel AsSpecifiedByCluster -Confirm:$false -RunAsync
    $tasks | Wait-Task

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
