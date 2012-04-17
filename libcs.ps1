
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

Function ssh-command()
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

Function scp-upload()
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















