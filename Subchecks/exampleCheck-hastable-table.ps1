#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Example by hashtable (table)" -IsSuccess $true -TechnicalSummary @{"Name"=@("John","Jack");"Favorite Color"=@("Red","Green"); "Age"=@("23","42")} -Summary "All Good" -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn