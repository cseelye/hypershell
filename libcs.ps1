
Function log()
{
    Param(
        [parameter(Position=1)]
        [System.String]$Message,
        $Color,
        [switch] $Deb,
        [switch] $Info,
        [switch] $Warn,
        [switch] $Error
    )
    
    if (-not $Message)
    {
        Write-Host
        return
    }
    
    if ($Deb) { $fg = "Gray" }
    elseif ($Info) { $fg = "White" }
    elseif ($Warn) { $fg = "Yellow" }
    elseif ($Error) { $fg = "Red" }
    else { $fg = "White" }
    
    if ($Color)
    {
        $fg = $Color
    }
    
    $datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Message = $Message.Replace("`r`n", "`n")
    foreach ($line in $Message.Split("`n"))
    {
        Write-Host -ForegroundColor $fg "$datestamp $line"
    }
}

Function Ssh-Command()
{
    Param(
        $Hostname,
        $RemoteCommand,
        $Username = "root",
        $Password = "password"
    )
    
    [reflection.assembly]::LoadFrom((Resolve-Path "Renci.SshNet.dll")) | Out-Null
    $ssh = New-Object -TypeName Renci.SSHNet.SSHClient -ArgumentList $Hostname, $Username, $Password 
    $ssh.Connect()
    $cmd = $ssh.RunCommand($RemoteCommand)
    $response = $cmd.Result
    $ssh.Disconnect()
    return $response
}

Function Scp-Upload()
{
    Param(
        $Hostname,
        $LocalFile,
        $RemoteFile,
        $Username = "root",
        $Password = "password"        
    )

    [reflection.assembly]::LoadFrom((Resolve-Path "Renci.SshNet.dll")) | Out-Null
    # A bug in this SSH library limits SCP uploads to the user's home directory
    # So we SCP it there, then use SSH to move it to where the user requested

    $file = New-Object -TypeName System.IO.FileInfo -ArgumentList $LocalFile
    $scp = New-Object -TypeName Renci.SSHNet.ScpClient -ArgumentList $Hostname, $Username, $Password
    $scp.Connect()
    $scp.Upload($file, $file.Name)
    $scp.Disconnect()
    
    ssh-command -Hostname $Hostname -Username $Username -Password $Password -RemoteCommand ("mv -f " + $file.Name + " $RemoteFile")
}

Function Add-AllIscsiDatastores
{
    Param(
        $VmHost,
        $Rescan = $true,
        $Vendor = ""
    )

    log -Info "Rescanning iSCSI on $VmHost"
    $iscsi_hba = Get-VMHostHba -Type iscsi -VMHost $VmHost
    Get-VMHostStorage -VMHost $VmHost -RescanAllHba -RescanVmfs | Out-Null

    # Get a list of iSCSI volumes
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
            $volume_name = $pieces[4]
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

    return $new_ds
}








