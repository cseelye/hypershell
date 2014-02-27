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

    $asyncJobs = @()
    foreach ($vm in $vms)
    {
        $checkpoints = Get-SCVMCheckpoint -VM $vm
        if($checkpoints.Length -gt 0)
        {
            #get the last checkpoint in the array
            $last_checkpoint = $checkpoints[-1]
            $job = ""
            Log-Info "Restoring $($vm.Name) to $($last_checkpoint.Name)"
            Restore-SCVMCheckpoint -VMCheckpoint $last_checkpoint -RunAsynchronously -JobVariable "job" | Out-Null
            $asyncJobs += $job
        }
    }

    while ($true)
    {
        $finished = $true
        foreach ($job in $asyncJobs)
        {
            if ($job.Status -ne "Done")
            {
                $finished = $false
                break
            }
        }
        if ($finished)
        {
            break
        }
        Start-Sleep 10
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

