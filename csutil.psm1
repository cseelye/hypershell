
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

Function SetModuleData($Name, $Value)
{

    if ($MyInvocation.MyCommand.Module.PrivateData -eq $null)
    {
        $MyInvocation.MyCommand.Module.PrivateData = @{}
    }
    $MyInvocation.MyCommand.Module.PrivateData[$Name] = $Value
}
Function GetModuleData($Name)
{
    if ($MyInvocation.MyCommand.Module.PrivateData -eq $null)
    {
        $MyInvocation.MyCommand.Module.PrivateData = @{}
    }
    if (-not $MyInvocation.MyCommand.Module.PrivateData.ContainsKey($Name))
    {
        return $null
    }
    return $MyInvocation.MyCommand.Module.PrivateData[$Name]
}

#region Logging functions
Function Silence-Log
{
    SetModuleData "silenceLog" $true
}
Function Reinstate-Log
{
    SetModuleData "silenceLog" $false
}

Function Log
{
    Param(
        [parameter(Position=1)]
        [System.String] $Message,
        $Color,
        [switch] $Deb,
        [switch] $Info,
        [switch] $Warn,
        [switch] $Error
    )

    if (GetModuleData "silenceLog" -eq $true)
    {
        return
    }
    
    if (-not $Message)
    {
        Write-Host
        return
    }
    
    $sev = "INFO "
    if ($Deb)
    {
        $fg = "Gray"
        $sev = "DEBUG"
    }
    elseif ($Info)
    {
        $fg = "White"
        $sev = "INFO "
    }
    elseif ($Warn)
    {
        $fg = "Yellow"
        $sev = "WARN "
    }
    elseif ($Error)
    {
        $fg = "Red"
        $sev = "ERROR"
    }
    else
    {
        $fg = "White"
        $sev ="INFO "
    }
    
    if ($Color)
    {
        $fg = $Color
        $sev ="INFO "
    }
    
    $datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Message = $Message.Replace("`r`n", "`n")
    foreach ($line in $Message.Split("`n"))
    {
        Write-Host -ForegroundColor $fg ("$datestamp" + ": $sev  $line")
    }
}

Function Log-Info
{
    Param(
        [parameter(Position=1)]
        [System.String]$Message
    )

    Log -Info $Message
}
Function Log-Warn
{
    Param(
        [parameter(Position=1)]
        [System.String]$Message
    )

    Log -Warn $Message
}
Function Log-Error
{
    Param(
        [parameter(Position=1)]
        [System.String]$Message
    )

    Log -Error $Message
}
Function Log-Debug
{
    Param(
        [parameter(Position=1)]
        [System.String]$Message
    )

    Log -Deb $Message
}
Function Log-Color
{
    Param(
        [parameter(Position=1)]
        $Color,
        [parameter(Position=2)]
        [System.String]$Message
    )

    Log -Color $Color $Message
}
#endregion










Export-ModuleMember '*-*'
Export-ModuleMember 'Log'
