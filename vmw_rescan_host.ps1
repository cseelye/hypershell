Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $VmHost = "192.168.0.0"
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
    $viserver = connect-viserver -server $MgmtServer -user $Username -password $Password

    # Rescan the host

    $host_obj = Get-VMHost -Name $VmHost
    if ($host_obj.IsStandalone)
    {
        # Rescan this host
        Log-Info "Rescanning HBAs on $VmHost..."
        Get-VMHostStorage -VMHost $VmHost -RescanAllHba -RescanVmfs | Out-Null
    }
    else
    {
        # Rescan the entire cluster
        $cluster_name = $host_obj.Parent.Name
        Log-Info "Rescanning all hosts in cluster $cluster_name"
        Get-Cluster -Name $cluster_name | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null
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
