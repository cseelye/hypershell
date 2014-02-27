Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $VmCount = 5,
  $WaitTime = 10,
  $PoolName = "BootStress"
)

Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    Add-PSSnapin "Vmware.VimAutomation.Core" | Out-Null
    Import-Module -DisableNameChecking .\csutil.psm1

    Log-Info "Connecting to vSphere"
    $viserver = Connect-VIServer -Server $MgmtServer -User $Username -Password $Password
    $Host.UI.RawUI.WindowTitle = "Boot Stress Test - $ClusterName - $PoolName"
    while ($true)
    {
        Log-Info "Finding VMs in pool $PoolName in cluster $ClusterName"
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
                Log-Warn "$vmname is already powered off"
            }
            else
            {
                Log -Color cyan "Shutting down guest in $vmname"
                $vm | Shutdown-VMGuest -Confirm:$false | Out-Null
            }
        }

        # Wait for all VMs to finish shut down
        Log-Info "Waiting for VMs to shut down..."
        do
        {
            Start-Sleep 2
            # Refresh status
            $vms_to_boot = $pool | Get-VM | where { $vms_to_boot -contains $_ }
        }
        until (@($vms_to_boot | Where { $_.PowerState -eq "PoweredOff" }).Count -eq $VmCount)
        Log -Color Green "VMs are shut down."

        # Start the VMs
        $tasks = @()
        foreach ($vm in $vms_to_boot)
        {
            $vmname = $vm.Name
            Log -Color cyan "Powering on $vmname"

            $tasks += $vm | Start-VM -Confirm:$false -RunAsync
        }
        $tasks | Wait-Task | Out-Null

        # Wait for VMs to be fully up
        Log-Info "Waiting for VMs to boot up..."
        do
        {
            Start-Sleep 2
            # Refresh status
            $test = $pool | Get-VM | where { $vms_to_boot -contains $_ } | Get-View
        }
        until (@($test | Where { $_.Guest.ToolsRunningStatus -eq "guestToolsRunning" }).Count -eq $VmCount)
        Log -Color Green "VMs are up."

        Log-Info "Waiting for $WaitTime seconds..."
        $remaining = $WaitTime
        while ($remaining -gt 0)
        {
            Log -Color gray "    Continuing test in $remaining sec"
            Start-Sleep 1
            $remaining--
        }
    }

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
