#This script will make a clone of a VM
#If the host is not provided then a random one will be picked
#If the path is not provided then it will be cloned to the same place as the original

Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VmName = "",
    $CloneName = "",
    $PathName = "",
    $VMHost = "",
    [Switch] $Start,
    $Username = "",
    $Password = ""
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
    
    if($CloneName.Length -eq 0){
        Log-Error "You must provide a clone name"
        exit 1
    }

    $pw = convertto-securestring -String $Password -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $pw
    Log-info "Connecting to $MgmtServer"
    $vmm = Get-SCVMMServer -ComputerName $MgmtServer -Credential $cred
    $cluster = Get-SCVMHostCluster -VMMServer $vmm -Name $ClusterName

    $vms = Get-SCVirtualMachine -VMMServer $vmm | Where {$_.Name -eq $VmName}
    if($vms.Length -gt 0)
    {
        $vm = $vms[0]
        if($vm.Status -ne "PowerOff")
        {
            Log-Error "$VmName must be powered off to clone"
            exit 1
        }
        # If the path is not provided then get the current path of the vm being cloned
        if($PathName.Length -eq 0)
        {
            $path = $vm.VMCPath
            # Get the index of the VM name so we can put the clone in the same directory
            $index_path = $path.LastIndexOf($vm.Name)
            $PathName = $path.Substring(0,$index_path)
        }

        # If the vmhost is not provided then get a random host from the cluster
        if($VMHost.Length -eq 0)
        {
            $VMHost = Get-SCVMHost
            $index = Get-Random -Minimum 0 -Maximum ($VMHost.Length - 1)
            $VMHost = $VMHost[$index]            
        }

        # Clone the VM
        if($Start)
        {
            New-SCVirtualMachine -Name $CloneName -VM $vm -VMHost $VMHost -Path $PathName -StartVM | Out-Null
        }
        else
        {
            New-SCVirtualMachine -Name $CloneName -VM $vm -VMHost $VMHost -Path $PathName | Out-Null
        }
    }
    else
    {
        Log-Error "Could not find a matching VM"
        exit 1
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

