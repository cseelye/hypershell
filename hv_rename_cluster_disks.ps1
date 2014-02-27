Param(
    $ClusterName = "mscs.example.com"
)
Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    # Make sure the CWD is the same as the location of this script file
    Split-Path ((Get-Variable MyInvocation -Scope 0).Value).MyCommand.Path | Set-Location
    Import-Module FailoverClusters
    Import-Module -DisableNameChecking .\csutil.psm1

    # Rename cluster resources to match disk volume labels
    Log-Info "Renaming disk resources to match volume names"
    foreach ($cluster_disk in Get-ClusterResource -Cluster $ClusterName | Where-Object {$_.OwnerGroup -eq "Available Storage"})
    {
        # Get the disk signature
        $disk_sig = ($cluster_disk | Get-ClusterParameter -Name DiskSignature).Value
        # Convert signature from hex (0xABCD1234) to decimal (2882343476) - the cluster commands use hex but the WMI objects use dec
        $disk_sig = [Convert]::ToUInt32($disk_sig, 16)
    
        # Get the volume label
        $disk_wmi = Get-WmiObject -Query "SELECT * FROM MSCluster_Disk WHERE Signature=$disk_sig" -Namespace root/MSCluster -ComputerName $ClusterName -Authentication PacketPrivacy
        $partition_wmi =  Get-WmiObject -Query "ASSOCIATORS OF {$disk_wmi} WHERE ResultClass=MSCluster_DiskPartition" -Namespace root/MSCluster -ComputerName $ClusterName -Authentication PacketPrivacy

        # Set the name of the cluster resource to be the volume label
        if ($cluster_disk.Name -ne $partition_wmi.VolumeLabel)
        {
            Log-Info ("  Renaming " + $cluster_disk.Name + " to " + $partition_wmi.VolumeLabel)
            $cluster_disk.Name = $partition_wmi.VolumeLabel
        }
    }

    # Rename CSV mount points to match the volume name
    Log-Info "Checking for CSV mount points that need to be renamed"
    foreach ($csv in Get-ClusterSharedVolume -Cluster $ClusterName)
    {
        $csv_path = $csv.SharedVolumeInfo.FriendlyVolumeName
        if ($csv_path -notlike ("*" + $csv.Name))
        {
            $new_csv_path = "C:\ClusterStorage\" + $csv.Name
            Log-Info ("Renaming CSV mount point " + $csv_path + " to " + $new_csv_path)
        
            # Rename the mount folder to match the volume name
            # Use powershell remoting to execute the command on the remote system
            Invoke-Command -ComputerName $ClusterName -ScriptBlock { Rename-Item -Path $args[0] -NewName $args[1] } -Args $csv_path,$new_csv_path
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
