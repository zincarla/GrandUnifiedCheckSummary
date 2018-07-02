#From Brian Wilhite (https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542)
Function Get-PendingReboot
{
    
    [CmdletBinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [Alias("CN","Computer")]
        [String[]]$ComputerName="$env:COMPUTERNAME",
        [String]$ErrorLog
        )

    Begin
    {
        #Adjusting ErrorActionPreference to stop on all errors
        $TempErrAct = $ErrorActionpreference
        $ErrorActionPreference = "Stop"
    } #End Begin Script Block

    Process
    {
        Foreach ($Computer in $ComputerName)
        {
            $Computer = $Computer.ToUpper().Trim()
            Try
            {
                #Setting pending values to false
                $CBS,$WUAU,$PendFileRename,$Pending = $false, $false, $false, $false

                #Querying WMI for build version
                $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer

                #Making registry connection to the local/remote computer
                $RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer)

                #If Vista/2008 or above, query the CBS Reg Key
                if ($WMI_OS.BuildNumber -ge 6001)
                {
                    $RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames()
                    $CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"
                    if ($CBSRebootPend)
                    {
                        $CBS = $true
                    } #End if ($CBSRebootPend)
                } #End if ($WMI_OS.BuildNumber -ge 6001)

                #Query WUAU from the registry
                $RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
                $RegWUAURebootReq = $RegWUAU.GetSubKeyNames()
                $WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired"

                #Query PendingFileRenameOperations from the registry
                $RegSubKeySM = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\")
                $RegValuePFRO = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null)

                #Close registry connection
                $RegCon.Close()

                #Check values grabbed and modify output accordingly

                if ($WUAURebootReq)
                {
                    $WUAU = $true
                } #End if($WUAURebootReq)

                if ($RegValuePFRO)
                {
                    $PendingFileRename = $true
                } #End if ($RegValuePFRO)

                if ($CBS -or $WUAU -or $PendFileRename)
                {
                    $Pending = $true
                } #End if ($CBS -or $WUAU -or $PendFileRename)

                #Creating $data custom PSObject
                $Data = New-Object -TypeName PSObject -Property @{
                    Computer=$Computer
                    CBServicing=$CBS
                    WindowsUpdate=$WUAU
                    PendFileRename=$PendFileRename
                    RebootPending=$Pending
                    }

                $Data | Select-Object -Property Computer, CBServicing, WindowsUpdate, PendFileRename, RebootPending
           }

           Catch
           {
                Write-Warning "$Computer`: $_"
           } #End catch
        }
    }

    End
    {
        $ErrorActionPreference = $TempErrAct
    }
}
#Do checks
$computers = @()
$computers += Get-ADComputer -Filter {operatingSystem -like "*server*"}  | ForEach-Object {$_.Name}
$Summary = 0
$Results = @()
foreach ($computer in $computers)
{
    if(Test-Connection -ComputerName $computer -Count 1 -Quiet)
    {
        $pendingRestart = $null;
        $pendingRestart = Get-PendingReboot -ComputerName $computer

        if($pendingRestart.RebootPending)
        {
            $Results = "$computer"
            $Summary++;
        }
    }
}

#Create return object
$ToReturn = New-CheckStatus -Name "Network Metrics" -IsSuccess $true -TechnicalSummary $Results -Summary "$Summary" -IsTechnicalHTML $false -IsSummaryHTML $true
return $ToReturn