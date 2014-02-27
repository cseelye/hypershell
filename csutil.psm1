

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
