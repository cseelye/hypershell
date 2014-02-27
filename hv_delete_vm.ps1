Param(
    [System.String] $MgmtServer = "scvmm.example.com",
    [System.String] $ClusterName = "mscs.example.com",
    [System.String] $VmName = "",
    [System.String] $VmRegex = "",
    [System.Int32]  $VmCount = 0,
    [System.String] $Username = "",
    [System.String] $Password = ""
)
$ScvmmModulePath = 'C:\Program Files\Microsoft System Center 2012\Virtual Machine Manager\bin\psModules\virtualmachinemanager\virtualmachinemanager.psd1'

Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

if (-not $VmRegex -and -not $VmName)
{
    Log-Info "Please enter either VmName or VmRegex"
    exit 1
}

try
{
    # Make sure the CWD is the same as the location of this script file
    Split-Path ((Get-Variable MyInvocation -Scope 0).Value).MyCommand.Path | Set-Location
    Import-Module $ScvmmModulePath | Out-Null
    Import-Module -DisableNameChecking .\csutil.psm1

    $pw = convertto-securestring -String $Password -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $pw
    Log-info "Connecting to $MgmtServer"
    $vmm = Get-SCVMMServer -ComputerName $MgmtServer -Credential $cred
    
    if ($VmName)
    {
        Log-Info "Searching for VM $VmName on $MgmtServer"
        $vm = Get-SCVirtualMachine -VMMServer $vmm | where { $_.Name -eq $VmName }
        if (-not $vm)
        {
            Log-Error "Could not find VM named $VmName"
            exit 1
        }
        Log-Info "Deleting $vm"
        Remove-SCVirtualMachine -VM $vm | Out-Null
    }
    else
    {
        Log-Info "Searching for VMs that match '$VmRegex' on $MgmtServer"
        $vm_list = @(Get-SCVirtualMachine -VMMServer $vmm | where { $_.Name -match $VmRegex }) | Sort-Object "Name"
        if ($vm_list.Length -le 0)
        {
            Log-Error "No VMs matched $VmRegex"
            exit 1
        }
        $count = 0
        foreach ($vm in $vm_list)
        {
            Log-Info "  Deleting $vm"
            Remove-SCVirtualMachine -VM $vm | Out-Null
            $count++
            if ($VmCount -gt 0 -and $count -ge $VmCount)
            {
                break
            }
        }
    }
    exit 0
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
