Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VmName = "",
    $VmRegex = "",
    $VmCount = 0,
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


    if($VmName)
	{
        $vms = Get-SCVirtualMachine -VMMServer $vmm | Where {$_.Name -eq $VmName} | Where {$_.Status -eq "PowerOff"}
    }
    else
	{
        $vms = Get-SCVirtualMachine -VMMServer $vmm | Where {$_.Status -eq "PowerOff"} | Where { $_.Name -match $VmRegex }
    }
    
    $count = $vms.Count
    if ($VmCount -gt 0 -and $count -gt $VmCount)
    {
        $count = $VmCount
    }
    if ($count -gt 1)
    {
        Log-info "Powering on $count VMs"
    }
    foreach ($vm in $vms)
    {
        Log-info "Powering on $vm"
        if($vm.Status -eq "Running")
        {
            Log-Info "$vm is already powered on"
        }
        else
        {
            Start-VM -VM $vm | Out-Null

            if($vm.Status -eq "Running")
            {
                Log-Info "$vm has powered on"
            }
            else
            {
                Log-Error "Error powering on VM $vm: $($vm.Status)"
            }
        }
        $count--
        if ($count -le 0)
        {
            break
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

