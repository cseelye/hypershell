Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $SourcePool = "pool1",
  $DestPool = "pool2",
  $VmCount = 25
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

    $source = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $SourcePool
    $dest = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $DestPool

    $vm_list = $source | Get-VM -NoRecursion
    $vm_list = $vm_list | Sort-Object

    $count = 1
    foreach ($vm in $vm_list)
    {
        Log -Color Cyan "Moving $vm to pool $DestPool"
        $vm | Move-VM -Destination $dest | Out-Null
        $count++
        if ($count -gt $VmCount)
        {
            break
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
