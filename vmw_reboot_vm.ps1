Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "pool1"
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

    Log-Info "Finding VMs in pool $PoolName in cluster $ClusterName"
    $pool = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName
    $vm_list = $pool | Get-VM | Sort-Object

    # Shut down VMs
    foreach ($vm in $vm_list)
    {
        if ($vm.PowerState -ne "poweredon")
        {
            Log-Info "$vm is not powered on"
            continue
        }
        Log -Color Cyan "Shutting down guest in $vm"
        $vm | Shutdown-VMGuest -Confirm:$false | Out-Null
    }

    # Wait for all VMs to finish shut down
    Log-Info "Waiting for VMs to shut down..."
    do
    {
        Start-Sleep 2
        # Refresh status
        $vm_list = $pool | Get-VM | Sort-Object
    }
    until (@($vm_list | Where { $_.PowerState -eq "PoweredOff" }).Count -eq $vm_list.Count)
    Log -Color Green "All VMs are shut down."

    # Start the VMs
    $tasks = @()
    foreach ($vm in $vm_list)
    {
        Log -Color cyan "Powering on $vm"

        $tasks += $vm | Start-VM -Confirm:$false -RunAsync
    }
    $tasks | Wait-Task | Out-Null

    # Wait for VMs to be fully up
    Log-Info "Waiting for VMs to boot up..."
    do
    {
        Start-Sleep 2
        # Refresh status
        $test = $pool | Get-VM | Get-View
    }
    until (@($test | Where { $_.Guest.ToolsRunningStatus -eq "guestToolsRunning" }).Count -eq $vm_list.Count)
    Log -Color Green "All VMs are up."
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
