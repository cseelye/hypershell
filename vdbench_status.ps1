Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $ClusterName = "esxcluster",
  $PoolName = "pool1",
  $IpPrefix = "192"
)
# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

. ./libcs.ps1

log
log -Info "Connecting to $VcServer"
$viserver = connect-viserver -server $VcServer -user $Username -password $Password

$vm_list = Get-Cluster -Name $ClusterName | Get-ResourcePool -Name $PoolName | Get-VM
$vm_list = $vm_list | Sort-Object

foreach ($vm in $vm_list)
{
    if ($vm.PowerState -ne "poweredon")
    {
        log -Info "$vm is not powered on"
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
            log -Warn "Could not find an IP address for $vm"
            continue
        }
        log -Info "Checking $vm at $vm_ip"
        
        $response = ssh-command -Hostname $vm_ip -RemoteCommand "tail /cygdrive/c/Users/Administrator/Desktop/vdbench/output/logfile.html"
        foreach ($line in $response.Split("`n"))
        {
            log -Debug " | $line"
        }
    }
}
log
disconnect-viserver -server * -force -confirm:$false | out-null
