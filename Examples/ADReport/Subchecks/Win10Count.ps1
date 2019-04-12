#Cache all machines
$Machines = Get-ADComputer -SearchScope Subtree -Filter * -Properties OperatingSystem,OperatingSystemVersion | Where-Object {$_.OperatingSystemVersion -like "10*" -and $_.OperatingSystem -like "Windows 10*"}

#This must be updated for each new windows 10 build. Note that the OperatingSystemVersion is based on NT Version
$Builds =  @()
$Builds+=New-Object -TypeName PSObject -Property @{Name="1607";Value=($Machines | Where-Object -FilterScript {$_.OperatingSystemVersion -like "*14393*"}).Length;}
$Builds+=New-Object -TypeName PSObject -Property @{Name="1703";Value=($Machines | Where-Object -FilterScript {$_.OperatingSystemVersion -like "*15063*"}).Length;}
$Builds+=New-Object -TypeName PSObject -Property @{Name="1709";Value=($Machines | Where-Object -FilterScript {$_.OperatingSystemVersion -like "*16299*"}).Length;}
$Builds+=New-Object -TypeName PSObject -Property @{Name="1803";Value=($Machines | Where-Object -FilterScript {$_.OperatingSystemVersion -like "*17134*"}).Length;} 
$Builds+=New-Object -TypeName PSObject -Property @{Name="1809";Value=($Machines | Where-Object -FilterScript {$_.OperatingSystemVersion -like "*17763*"}).Length;} 

$SVGChart=New-PieChart -DataPoints $Builds -Height 200

$ToReturn = New-CheckStatus -Name "Windows10CountChart" -IsSuccess $true -TechnicalSummary $Builds -Summary $SVGChart -IsTechnicalHTML $false -IsSummaryHTML $true
return $ToReturn