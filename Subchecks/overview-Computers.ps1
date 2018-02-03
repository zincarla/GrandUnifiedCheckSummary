#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Network Metrics" -IsSuccess $true -TechnicalSummary $null -Summary "<h3>Computers: </h3> 550" -IsTechnicalHTML $false -IsSummaryHTML $true -Priority 0
return $ToReturn