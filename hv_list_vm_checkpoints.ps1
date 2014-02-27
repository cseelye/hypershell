Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VmName = "",
    $VmRegex = "",
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


    if($VmName)
    {
        $vms = Get-SCVirtualMachine -VMMServer $vmm | Where {$_.Name -eq $VmName}
    }
    else
    {
        $vms = Get-SCVirtualMachine -VMMServer $vmm | Where {$_.Name -match $VmRegex}
    }

    $output = @()
    foreach ($vm in $vms)
    {
        $checkpoints = $vm.VMCheckpoints
        foreach ($check in $checkpoints)
        {
            if($check.Name -match $vm.Name)
            {
                if($Csv -or $Bash)
                {
                    $output += $check.Name
                }
                else
                {
                    Log-Info "$($check.Name)"
                 }
            }
        }   
    }
    if($Csv -or $Bash)
    {
        $separator = ","
        if ($Bash) { $separator = " " }
        Write-Host ([System.String]::Join($separator, $output))
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

