Param(
  $MgmtServer = "192.168.0.0",
  $Username = "script_user",
  $Password = "password",
  $SourceVm = "gold-lnx-esx",
  $CustomizationSpec = "ubuntu-scripted-clone",
  $DestinationDatastore = "datastore1",
  $DestinationHost = "192.168.0.0",
  $CloneCount = 100,
  $Ip1Base = "192.168.000.",
  $Ip1Start = 1,
  $Ip1Mask = "255.255.255.0",
  $Ip1Gw = "192.168.0.254",
  $Ip2Base = "10.10.0.",
  $Ip2Start = 1,
  $Ip2Mask = "255.255.255.0",
  $Ip2Gw = "0.0.0.0",
  $CloneNamePre = "clone-",
  $CloneNamePost = "-lnx",
  $CloneStartNum = 2001
)
Write-Host
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

try
{
    Add-PSSnapin "Vmware.VimAutomation.Core" | Out-Null
    Import-Module -DisableNameChecking .\csutil.psm1

    Write-Host
    Log-Info "Connecting to $MgmtServer"
    $viserver = connect-viserver -server $MgmtServer -user $Username -password $Password
    $destination = Get-VMHost -name $DestinationHost
    $datastore = Get-Datastore -Name $DestinationDatastore
    try
    {
        Remove-OSCustomizationSpec -OSCustomizationSpec temp -Confirm:$false
    }
    catch {}
    $CustomizationSpec_obj = new-oscustomizationspec -oscustomizationspec $CustomizationSpec -type NonPersistent -name temp
    Write-Host
    Log-Info "Cloning '$SourceVm' $CloneCount times to datastore '$DestinationDatastore'"
    $start_time = get-date
    Log-Info "Starting clones at $start_time"
    Write-Host
    $clone_tasks = @{}
    $ip1_num = $Ip1Start
    $ip2_num = $Ip2Start
    for ($clone_num = $CloneStartNum; $clone_num -lt ($CloneStartNum + $CloneCount); $clone_num++)
    {
        $clone_name = ("$CloneNamePre{0:000}$CloneNamePost" -f $clone_num)
        $ip1 = ("$Ip1Base{0}" -f $ip1_num)
        $ip2 = ("$Ip2Base{0}" -f $ip2_num)

        $CustomizationSpec_obj | get-oscustomizationnicmapping | where {$_.Position -eq 1} | set-oscustomizationnicmapping -ipmode usestaticip -ipaddress $ip1 -subnetmask $Ip1Mask -defaultgateway $Ip1Gw | out-null
        $CustomizationSpec_obj | get-oscustomizationnicmapping | where {$_.Position -eq 2} | set-oscustomizationnicmapping -ipmode usestaticip -ipaddress $ip2 -subnetmask $Ip2Mask -defaultgateway $Ip2Gw | out-null

        Log -Color Cyan "Starting clone '$clone_name' : $ip1 : $ip2"
        $clone_task = new-vm -vm $SourceVm -datastore $datastore -VMHost $destination -oscustomizationspec $CustomizationSpec_obj -name $clone_name -runasync
        $clone_tasks[$clone_name] = $clone_task
        $ip1_num++
        $ip2_num++
    }
    Write-Host
    Log-Info "Waiting for all clones to complete..."
    $clone_names = @()
    while ($clone_tasks.Count -gt 0)
    {
        $names = $($clone_tasks.keys)
        foreach ($clone_name in $names)
        {
            $clone_task = $clone_tasks[$clone_name]
            # refresh the status of the task
            $clone_task = get-task | where {$_.Id -eq $clone_task.Id}
            $state = $clone_task.State
            if ($state -eq "Success")
            {
                Log -Color Green "    Clone '$clone_name' complete"
                $clone_tasks.Remove($clone_name)

                # boot the VM
                Log-Info "    Powering on '$clone_name'..."
                $start_task = get-vm -name $clone_name | start-vm -runasync
            }
            elseif ($state -eq "Error")
            {
                Log-Error ("    Clone '$clone_name' failed: " + $clone_task.extensiondata.info.error.localizedMessage)
                $clone_tasks.Remove($clone_name)
            }
        }
        if ($clone_tasks.Count -gt 0)
        {
            Start-Sleep -Seconds 15
        }
    }
    Write-Host
    $end_time = get-date
    $elapsed = $end_time - $start_time
    $elapsed_str = ("{0}-{1}:{2}:{3}.{4}" -f $elapsed.Days,$elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds,$elapsed.Milliseconds)
    Log-Info "Cloning finished at $end_time ($elapsed_str)"
    Write-Host
    disconnect-viserver -server * -force -confirm:$false | out-null
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
