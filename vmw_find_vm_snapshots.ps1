Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster" # leave empty for all clusters
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
    Log-Info "Connecting to $MgmtServer"
    $viserver = connect-viserver -server $MgmtServer -user $Username -password $Password

    if ([string]::IsNullOrEmpty($ClusterName))
    {
        Log-Info "Finding all VMs with snapshots"
        $vm_list = Get-VM
    }
    else
    {
        Log-Info "Finding all VMs with snapshots in cluster $ClusterName"
        $vm_list = Get-Cluster -Name $ClusterName | Get-VM | Sort-Object
    }
    $vm_snaps = @()
    foreach ($vm in $vm_list)
    {
        $snap_list = $vm | Get-Snapshot
        if (@($snap_list).Count -le 0)
        {
            continue
        }
        Log-Info ("$vm has " + @($snap_list).Count + " snapshots")
        foreach ($snap in $snap_list)
        {
            Log-Info ("  " + $snap)
        }
    }
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
