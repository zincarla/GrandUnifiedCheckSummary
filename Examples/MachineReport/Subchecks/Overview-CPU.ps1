#Do checks
$CPU = (Get-WmiObject win32_processor)
$Properties = @("Name", "LoadPercentage","NumberOfLogicalProcessors", "NumberOfCores", "MaxClockSpeed")
$TechSummary = @()

foreach ($Property in $Properties) {
    $TechSummary += New-Object -TypeName PSObject -Property @{Name=$Property;Value=$CPU.$Property}
}

#Create return object
$ToReturn = New-CheckStatus -Name "Processor" -IsSuccess $true -TechnicalSummary $TechSummary -Summary $null -IsTechnicalHTML $false -IsSummaryHTML $false -Priority 0
return $ToReturn