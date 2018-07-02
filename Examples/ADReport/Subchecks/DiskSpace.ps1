#Do checks
$Warnings =0;
$Criticals =0;
$WarningThreshold = 5; #%
$CriticalThreshold = 2;#%
# Get computer list to check disk space
$excludedOS = @("unknown", "OnTap")
$computers = @()
$computers += Get-ADComputer -Filter {operatingSystem -like "*server*"} -Properties OperatingSystem | Where-Object {$_.OperatingSystem -notin $excludedOS} | ForEach-Object {$_.Name};
$TechSummary = @()
foreach($computer in $computers)
{	
    Write-Host "Checking $computer"
    if (Test-Connection -ComputerName $computer -Count 1 -Quiet)
    {
	    $disks = Get-WmiObject -ComputerName $computer -Class Win32_LogicalDisk -Filter "DriveType = 3"
	    $computer = $computer.toupper()	
        foreach($disk in $disks)
	    {        
		    $deviceID = $disk.DeviceID;
            $volName = $disk.VolumeName;
		    [float]$size = $disk.Size;
		    [float]$freespace = $disk.FreeSpace; 
		    $percentFree = [Math]::Round(($freespace / $size) * 100, 2);
		    $sizeGB = [Math]::Round($size / 1073741824, 2);
		    $freeSpaceGB = [Math]::Round($freespace / 1073741824, 2);
            $usedSpaceGB = $sizeGB - $freeSpaceGB;

            if($percentFree -le $CriticalThreshold)
            {
                $Criticals++;
            }  
	        elseif ($percentFree -lt $WarningThreshold)      
		    {
	            $Warnings++;
            }

            # Create table data rows if free space percentage is below critical threshold
            if ($percentFree -lt $WarningThreshold)
            {
                $TechSummary += New-Object -TypeName PSObject -Property @{"Computer"=$computer;"DeviceID"=$deviceID;"Volume"=$volName;"Size (GB)"=$sizeGB;"Used (GB)"=$usedSpaceGB;"Free (GB)"=$freeSpaceGB; "Free (%)"=$percentFree}
            }

            # Output to host to track progress on a manual run
            Write-Host -ForegroundColor DarkYellow "$computer $deviceID percentage free space = $percentFree";		
	    }
    }
}

#Create return object
$ToReturn = New-CheckStatus -Name "DiskSpace" -IsSuccess ($Criticals -eq 0) -TechnicalSummary $TechSummary -Summary "$Warnings Warnings and $Criticals Criticals" -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn