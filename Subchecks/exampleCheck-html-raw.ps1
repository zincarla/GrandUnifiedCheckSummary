#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Example by html (raw)" -IsSuccess $true -TechnicalSummary "Its <b>all</b> <i>Go<b>o</b>d</i>" -Summary "Its <b>all</b> <i>Good</i>" -IsTechnicalHTML $true -IsSummaryHTML $true
return $ToReturn