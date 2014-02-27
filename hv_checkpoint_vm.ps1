Param(
    $MgmtServer = "scvmm.example.com",
    $ClusterName = "mscs.example.com",
    $VmName = "",
    $VmRegex = "",
    $VmCount = 0,
    $Username = "",
    $Password = "",
    [Switch] $Csv,
    [Switch] $Bash
)
$ScvmmModulePath = 'C:\Program Files\Microsoft System Center 2012 R2 \Virtual Machine Manager\bin\psModules\virtualmachinemanager\virtualmachinemanager.psd1'

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

    $count = 0
    $joblist = @()
    foreach ($vm in $vms)
    {
        Log-Info "Creating a Checkpoint for $($vm.Name)"
        $job = ""
        New-SCVMCheckpoint -VM $vm -RunAsynchronously -JobVariable "job"
        $joblist += $job
        $count++
        if ($VmCount -gt 0 -and $count -ge $VmCount)
        {
            break
        }
    }

    # Wait for all jobs to finish
    while ($true)
    {
        $finished = $true
        foreach ($job in $joblist)
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

