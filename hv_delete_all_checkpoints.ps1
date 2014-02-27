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

    $failed_count = 0
    foreach ($vm in $vms)
    {
        Log-Info "Getting checkpoints for $($vm.Name)"    
        $checkpoints = Get-SCVMCheckpoint -VM $vm
        if($checkpoints.Length -eq 0)
        {
            Log-Info "The VM $($vm.Name) does not have any checkpoints"
        }
        foreach($check in $checkpoints)
        {
            Log-Info "Removing Checkpoint: $($check.Name)"
            $job = ""
            Remove-SCVMCheckpoint -VMCheckpoint $check -JobVariable "job" | Out-Null
            Log-Info "Checkpoint $($check.Name) Status: $($job.Status)"
            if($job.Status -ne "Completed")
            {
                $failed_count++
            }

        }
    }
    if($failed_count -gt 0)
    {
        Log-Error "Not all checkpoints could be removed"
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

