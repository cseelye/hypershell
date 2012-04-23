Param(
  $VcServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $VmHost = "192.168.0.0",
  $Vendor = ""
)

# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

. ./libcs.ps1
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
log
log -Info "Connecting to vSphere"
$viserver = connect-viserver -server $VcServer -user $Username -password $Password

# Rescan
log -Info "Rescanning HBAs on $VmHost..."
$iscsi_hba = Get-VMHostHba -Type iscsi -VMHost $VmHost
Get-VMHostStorage -VMHost $VmHost -RescanAllHba -RescanVmfs | Out-Null

# Get a list of iSCSI volumes
log -Info "Finding all iSCSI volumes on $VmHost..."
$luns = Get-ScsiLun -Hba $iscsi_hba
$iqn2volume = @{}
$volume2lun = @{}
foreach ($iscsi_lun in $luns)
{
    $path_info = Get-ScsiLunPath -ScsiLun $iscsi_lun
    $iqn = $path_info.SanID
    $volume_name = $iqn
    if ($Vendor -eq "SolidFir")
    {
        $pieces = $iqn.split(".")
        $volume_name = $pieces[4] + "." + $pieces[5]
        if ($volume2lun.ContainsKey($volume_name))
        {
            log -Error "Duplicate volume name detected.  This script cannot handle that case."
            exit
        }
    }
    $iqn2volume[$iqn] = $volume_name
    $volume2lun[$volume_name] = $iscsi_lun.CanonicalName
}

# Find the datastore for each LUN
$host_obj = Get-VMHost -Name $VmHost | Get-View
$all_luns = $host_obj.Config.StorageDevice.ScsiLun | ?{$_.vendor -match $Vendor}
$all_datastores = $host_obj.Config.FileSystemVolume.MountInfo
$lun2ds = @{}
foreach ($ds in $all_datastores | ?{$_.Volume.Extent.Count -gt 0})
{
    $name = $ds.Volume.Extent[0].DiskName
    foreach ($lun in $all_luns)
    {
        if ($lun.CanonicalName -eq $name)
        {
            $lun2ds[$name] = $ds.Volume.Name
        }
    }
}

# Create datastores for LUNs
$new_ds = $false
foreach ($iqn in $iqn2volume.keys | Sort-Object)
{
    $volume = $iqn2volume[$iqn]
    $lun = $volume2lun[$volume]
    if ($lun2ds.ContainsKey($lun))
    {
        $ds = $lun2ds[$lun]
        #log -Debug "    $iqn -> $volume -> $lun -> $ds"
    }
    else
    {
        log -Info "Creating new datastore '$volume' with iSCSI volume $iqn..."
        New-Datastore -VMHost $VmHost -Name $volume -Path $lun -Vmfs | Out-Null
        $new_ds = $true
    }
}

# If the host is part of a cluster, rescan the other cluster members
if ($new_ds)
{
    $host_obj = Get-VMHost -Name $VmHost
    if (-not $host_obj.IsStandalone)
    {
        $cluster_name = $host_obj.Parent.Name
        log -Info "Rescanning all members of cluster $cluster_name"
        Get-Cluster -Name $cluster_name | Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null
        
    }
}
else
{
    log -Info "No new volumes found"
}

log
disconnect-viserver -server * -force -confirm:$false | out-null









