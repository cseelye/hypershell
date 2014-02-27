Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VMPrefix = "",
    $Username = "",
    $Password = "",
    [Switch] $Csv,
    [Switch] $Bash
)
$ScvmmModulePath = 'C:\Program Files\Microsoft System Center 2012 R2\Virtual Machine Manager\bin\psModules\virtualmachinemanager\virtualmachinemanager.psd1'

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

    Log-Info "Finding VMs in cluster $ClusterName that match $VMPrefix"
    $vms = Get-SCVirtualMachine -VMMServer $vmm | Where { $_.Name -match $VMPrefix }

    if($vms.Length -le 0)
    {
        Log-Error "There are no matching VMs"
        exit 1
    }

    # Sort the VMs by name the highest number should be on top
    $vms = $vms | Sort-Object -Property Name -Descending
    $top = $vms[0]
    # Use a regex to grab the number from the end of the name
    [regex]$regex = '0*(\d+)$'
    $number = $regex.Matches($top.Name).Value -as [int]
    $number++

    if ($Csv -or $Bash)
    {
        Write-Host $number
    }
    else
    {
        Log-Info "The next number is $number"
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

