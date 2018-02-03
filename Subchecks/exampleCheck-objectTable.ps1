#Do checks
#Create return object
$ToReturn = New-CheckStatus -Name "Example by array objects (Table)" -IsSuccess $true -TechnicalSummary @((New-Object -TypeName PSObject -Property @{UserName="John.Doe"; Status="Good"}), (New-Object -TypeName PSObject -Property @{UserName="John.Doe"; Status="Good"})) -Summary @((New-Object -TypeName PSObject -Property @{All="Good"})) -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn