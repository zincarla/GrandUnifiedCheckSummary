#Do checks
Add-Type -AssemblyName "System.Drawing"
$Bitmap = [System.Drawing.Bitmap]::new(200,50)
$Drawing = [System.Drawing.Graphics]::FromImage($Bitmap)
$Drawing.FillRectangle([System.Drawing.Brushes]::Green,0,0,200,50)
$Drawing.DrawLine([System.Drawing.Pens]::Red,0,0,200,25);
$Drawing.DrawLine([System.Drawing.Pens]::Blue,0,25,200,50);
$Drawing.Dispose()

#Create return object
$ToReturn = New-CheckStatus -Name "Example by html-image (raw)" -IsSuccess $true -TechnicalSummary "<div class=`"CenterText`">$(Convert-ImageToHTML -Image $Bitmap)</div>" -Summary "All Good... I think, this is a terrible image in't it?" -IsTechnicalHTML $true -IsSummaryHTML $false
return $ToReturn