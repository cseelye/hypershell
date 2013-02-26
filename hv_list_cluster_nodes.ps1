Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    [System.String] $Username = "",
    [System.String] $Password = "",
    [Switch] $Csv,
    [Switch] $Bash
)
$ScvmmModulePath = 'C:\Program Files\Microsoft System Center 2012\Virtual Machine Manager\bin\psModules\virtualmachinemanager\virtualmachinemanager.psd1'

Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    # Make sure the CWD is the same as the location of this script file
    Split-Path ((Get-Variable MyInvocation -Scope 0).Value).MyCommand.Path | Set-Location
    Import-Module $ScvmmModulePath | Out-Null
    Import-Module -DisableNameChecking .\csutil.psm1

    if ($Csv -or $Bash)
    {
        Silence-Log
    }

    $pw = convertto-securestring -String $Password -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $pw
    Log-info "Connecting to $MgmtServer"
    $vmm = Get-SCVMMServer -ComputerName $MgmtServer -Credential $cred

    Log-Info "Finding nodes in cluster $ClusterName"
    $cluster = Get-SCVMHostCluster -VMMServer $vmm -Name $ClusterName
    $host_list = @()
    foreach ($vmhost in $cluster | Get-SCVMHost)
    {
        $host_list += $vmhost.FullyQualifiedDomainName
    }

    if ($Csv -or $Bash)
    {
        $separator = ","
        if ($Bash) { $separator = " " }

        Write-Host ([System.String]::Join($separator, $host_list))
    }
    else
    {
        foreach ($hostname in $host_list)
        {
            Log-Info ("  " + $hostname)
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

