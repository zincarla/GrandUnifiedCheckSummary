#Do checks
$Memory = @()+(Get-WmiObject -Class Win32_PhysicalMemory)
$TechSummary = @()

foreach ($Stick in $Memory) {
    $TechSummary += New-Object -TypeName PSObject -Property @{Manufacaturer=$Stick.Manufacturer;Bank=$Stick.BankLabel;Speed=$Stick.Speed;"Capacity (GB)"=$Stick.Capacity/1024/1024/1024}
}

#Create return object
$ToReturn = New-CheckStatus -Name "Memory" -IsSuccess $true -TechnicalSummary $TechSummary -Summary $null -IsTechnicalHTML $false -IsSummaryHTML $false -Priority 0
return $ToReturn