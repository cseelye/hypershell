Param(
  $VcServer = "192.168.0.0",
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


# Use in ISE debugger or standard PS shell (not in PowerCLI shell)
#Add-PSSnapin "Vmware.VimAutomation.Core"

. ./libcs.ps1
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"
log
log -Info "Connecting to $VcServer"
$viserver = connect-viserver -server $VcServer -user $Username -password $Password
$destination = Get-VMHost -name $DestinationHost
$datastore = Get-Datastore -Name $DestinationDatastore
try
{
    Remove-OSCustomizationSpec -OSCustomizationSpec temp -Confirm:$false
}
catch {}
$CustomizationSpec_obj = new-oscustomizationspec -oscustomizationspec $CustomizationSpec -type NonPersistent -name temp
log
log -Info "Cloning '$SourceVm' $CloneCount times to datastore '$DestinationDatastore'"
$start_time = get-date
log -Info "Starting clones at $start_time"
log
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
    
    log -Color Cyan "Starting clone '$clone_name' : $ip1 : $ip2"
    $clone_task = new-vm -vm $SourceVm -datastore $datastore -VMHost $destination -oscustomizationspec $CustomizationSpec_obj -name $clone_name -runasync
    $clone_tasks[$clone_name] = $clone_task
    $ip1_num++
    $ip2_num++
}
log
log -Info "Waiting for all clones to complete..."
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
            log -Color Green "    Clone '$clone_name' complete"
            $clone_tasks.Remove($clone_name)
            
            # boot the VM
            log -Info "    Powering on '$clone_name'..."
            $start_task = get-vm -name $clone_name | start-vm -runasync
        }
        elseif ($state -eq "Error")
        {
            log -Error ("    Clone '$clone_name' failed: " + $clone_task.extensiondata.info.error.localizedMessage)
            $clone_tasks.Remove($clone_name)
        }
    }
    if ($clone_tasks.Count -gt 0)
    {
        Start-Sleep -Seconds 15
    }
}
log
$end_time = get-date
$elapsed = $end_time - $start_time
$elapsed_str = ("{0}-{1}:{2}:{3}.{4}" -f $elapsed.Days,$elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds,$elapsed.Milliseconds)
log -Info "Cloning finished at $end_time ($elapsed_str)"
log
disconnect-viserver -server * -force -confirm:$false | out-null








