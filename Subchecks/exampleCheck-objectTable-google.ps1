#Do checks
$err="";
try {
    $result = Test-Connection "google.com" -ea stop
}catch {
    $err = $_.ToString();
}
$IsGood = $false;
$Summary = "We did not reach google"
if ($result) {
    $IsGood = $true
    $Summary = "We reached google"
} else {
    $result = $err;
}
#Create return object
$ToReturn = New-CheckStatus -Name "Example by array objects google" -IsSuccess $IsGood -TechnicalSummary $result -Summary $Summary -IsTechnicalHTML $false -IsSummaryHTML $false
return $ToReturn