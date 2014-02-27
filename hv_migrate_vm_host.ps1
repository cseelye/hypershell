Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VmName = "",
    $VmRegex = "",
    $VMHost = "",
    $VMPath = "",
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

    foreach ($vm in $vms)
    {
        if($VMHost.Length -eq 0)
        {
            $VMHosts = Get-SCVMHost -VMMServer $vmm 
            $randIndex = Get-Random -Minimum 0 -Maximum $VMHosts.Length
            $VMHost = $VMHosts[$randIndex]
        }
        else
        {
            $VMHosts = Get-SCVMHost -VMMServer $vmm | Where {$_.Name -eq $VMHost}
            if($VMHosts.Length -eq 0)
            {
                Log-Error "Could not find the VM host $VMHost"
                exit 1
            }
            $VMHost = $VMHosts
        }

        Log-Info "Moving $($vm.Name) from $($vm.VMHost) to $($VMHost.Name)"
        Move-VM -VM $vm -VMHost $VMHost -Path $VMPath | Out-Null
        Log-Info "$($vm.Name) is now on host $($vm.VMHost)"
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

