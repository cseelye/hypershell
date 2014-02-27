Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "pool1",
  $IpPrefix = "192"
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

    $vm_list = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName | Get-VM
    $vm_list = $vm_list | Sort-Object

    foreach ($vm in $vm_list)
    {
        if ($vm.PowerState -ne "poweredon")
        {
            Log-Info "$vm is not powered on"
        }
        else
        {
            foreach ($ip in $vm.Guest.IpAddress)
            {
                if ($ip.StartsWith($ipPrefix))
                {
                    $vm_ip = $ip
                    break
                }
            }
            if (-not $vm_ip)
            {
                Log-Warn "Could not find an IP address for $vm"
                continue
            }
            Log-Info "Checking $vm at $vm_ip"

            $response = ssh-command -Hostname $vm_ip -RemoteCommand "tail /cygdrive/c/Users/Administrator/Desktop/vdbench/output/logfile.html"
            foreach ($line in $response.Split("`n"))
            {
                Log-Debug " | $line"
            }
        }
    }
    Write-Host
    disconnect-viserver -server * -force -confirm:$false | out-null
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
