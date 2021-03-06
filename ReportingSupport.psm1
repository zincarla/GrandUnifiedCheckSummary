Add-Type -Assembly System.Drawing
#region Images
<#
.SYNOPSIS
Encodes an image into Base64

.DESCRIPTION
Encodes an image into Base64

.PARAMETER Image
The image to base-64-ify

.EXAMPLE
Convert-ImageToSVG -Image ([System.Drawing.Image]::FromFile($PathToImage))
#>
function Convert-ImageToHTML
{
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][System.Drawing.Image]
        $Image
    )
    $EmbedString = ""
	try
	{
		$MS = New-Object -TypeName System.IO.MemoryStream
		$Image.Save($MS, [System.Drawing.Imaging.ImageFormat]::Png);
		$EmbedString += "<img src=`"data:image/png;base64," + [System.Convert]::ToBase64String($MS.ToArray()) + "`" alt=`"EmbeddedImage`" />" 
        $MS.Dispose()
        return $EmbedString
	}
	catch 
    { 
        Write-Warning ("Warning, will continue without Image. " + $_.ToString()); 
    }
    return $null;
}

<#
.SYNOPSIS
Loads an SVG file into a string

.DESCRIPTION
Loads an SVG file into a string, ready to be injected into an HTML file

.PARAMETER Image
The SVG image to load

.EXAMPLE
Import-SVG -PathToImage "C:\Users\Reports\myimage.svg"
#>
function Import-SVG
{
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]
        $PathToImage
    )
    $EmbedString = ""
	$FI = [System.IO.FileInfo] $PathToImage;
	if ($FI.Extension.ToLower() -eq ".svg")
	{
        #Assuming the image is an svg based on exstention
        #Grab the SVG code and embed it directly in the html
		try
		{
			$SR = [System.IO.StreamReader]$PathToImage
				    
			$Results = $SR.ReadToEnd().Split(@("<svg"), 2, [StringSplitOptions]::None);
			if ($Results.Length -eq 2)
			{
				$EmbedString += "<svg " + $Results[1];
			}
				
            $SR.Close()
            return $EmbedString
		}
		catch 
        { 
            Write-Warning ("Warning, will continue without Image. " + $_.ToString())
        }
	}
    return $null;
}
#endregion

#region Charts
<#
.SYNOPSIS
    Creates an SVG PieChart.

.PARAMETER DataPoints
    Your data set. Must be an array containing items with a string Name and Numerical Value. Such as @(@{Name="Test Point";Value=14},@{Name="Test Point2";Value=24})

.PARAMETER Colors
    An array of colors in HEX format. These are used as the colors in the pie chart. If null, colors will be auto-selected. @("#000000", "#ffffff", "#FF2235").

.PARAMETER FontFolor
    Color of the text, must be a system.drawing.color object.

.PARAMETER Height
    Height of the SVG tag. 200 by default. Set to "auto" or "100%" to manipulate via CSS on parent element.

.PARAMETER Width
    Width of the SVG tag. 300 by default. Set to "auto" or "100%" to manipulate via CSS on parent element.
#>
function New-PieChart 
{
    Param($DataPoints,$Height=200, $Width=1.5*$Height, $Colors, [System.Drawing.Color]$FontColor=[System.Drawing.Color]::FromArgb(0,0,0))
    if ($ColorList -ne $null -and $ColorList.Length -ne $DataPoints.Length) {
        Write-Warning "Color list length does not match length of datapoints. Defaulting to normal spread."
        $ColorList = $null
    }
    if ($FontColor -eq $null) {
        $FontColor = [System.Drawing.Color]::FromArgb(0,0,0)
    }
    $SVG = "<svg viewBox=`"0 0 300 200`" height=`"$Height`" width=`"$Width`">`r`n"
    #Change dimension to viewbox dimensions for rest of code
    $Height = 200;
    $Width = 300;

    $Total = 0
    foreach ($DataPoint in $DataPoints) {
        $Total += $DataPoint.Value
    }

    #Generate a Spread of Colors
    if ($Colors -eq $null) {
        $Colors = Get-ColorSpread -Amount $DataPoints.Length | Get-HexColor
    }

    #Draw Pie
    $CurrentPercent = 0;
    #Center of circle
    $OriginX = $Width/3
    $OriginY = $Height /2
    $Radius = $OriginX #In this case, same as OriginX
    $I =0;

   #Edge Case, if there is only 1 data point with values, just draw a circle.
    #PowerShell, STOP HELPING, I want an array! If you don't manually cast this, powershell decides to be "helpful" and just returns the object.
    if ((@()+($DataPoints | Where-Object {$_.Value -gt 0})).Length -eq 1) {
        for ($I=0;$I-lt $DataPoints.Length; $I++) {
            #Even though we only have on point with value, loop through all to ensure color match
            $DataPoint = $DataPoints[$I]
            if ($DataPoint.Value -gt 0) {
                #GetPercentage
                $Percentage = $DataPoint.Value / $Total
                $SVG += "`t<circle cx=`"$($OriginX)`" cy=`"$($OriginY)`" r=`"$Radius`" fill=`"$($Colors[$I])`"><title>$($DataPoint.Name): $($DataPoint.Value) ($(($Percentage*100).ToString("N2"))%)</title></circle>"
                break;
            }
        }
    }elseif ((@()+($DataPoints | Where-Object {$_.Value -gt 0})).Length -eq 0) {
        #Edge case, No data
        $SVG+="`t<text x=`"$OriginX`" text-anchor=`"middle`" y=`"$OriginY`" fill=`"#999999`">No Data</text>`r`n"
    } else {
        for ($I=0;$I-lt $DataPoints.Length; $I++) {
            $DataPoint = $DataPoints[$I]
            $SVG +="`t<path d=`""
            #GetPercentage
            $Percentage = $DataPoint.Value / $Total

            $M = "$($OriginX),$($OriginY)" #Start Point is always center of Pie
            #Next line to current point on circle
            $Angle = $CurrentPercent * (2*[Math]::PI)
            $PX = $OriginX + $Radius * [Math]::Cos($Angle)
            $PY = $OriginY + $Radius * [Math]::Sin($Angle)
            $L = "$PX,$PY"
            #Next Arc to other point
            $CurrentPercent += $Percentage
            $Angle = $CurrentPercent * (2*[Math]::PI)
            $PX = $OriginX + $Radius * [Math]::Cos($Angle)
            $PY = $OriginY + $Radius * [Math]::Sin($Angle)
            $LA = 0
            if (($Percentage * (2*[Math]::PI)) -gt [math]::PI) {
                $LA=1
            }
            $A = "$OriginX,$OriginY 0,$LA,1 $PX,$PY"
        
            $SVG += "M $M L $L A $A Z`" fill=`"$($Colors[$I])`"><title>$($DataPoint.Name): $($DataPoint.Value) ($(($Percentage*100).ToString("N2"))%)</title></path>`r`n"
        }
    }

    #Draw Legend
    $CRadius = 8
    $Buffer = $CRadius/2

    $OriginX = $Width*2/3+$CRadius+$Buffer
    $CY = $CRadius + $Buffer
    $FontColor = $FontColor | Get-HexColor
    for ($I=0;$I-lt $DataPoints.Length; $I++) {
        $DataPoint = $DataPoints[$I]
        $Percentage = $DataPoint.Value / $Total
        $SVG += "`t<circle cx=`"$OriginX`" cy=`"$CY`" r=`"$CRadius`" fill=`"$($Colors[$I])`"><title>$($DataPoint.Name): $($DataPoint.Value) ($(($Percentage*100).ToString("N2"))%)</title></circle>`r`n"
        $SVG += "`t<text x=`"$($OriginX + $CRadius + $Buffer)`" y=`"$($CY+($CRadius/2))`" fill=`"$FontColor`">$($DataPoint.Name)<title>$($DataPoint.Name): $($DataPoint.Value) ($(($Percentage*100).ToString("N2"))%)</title></text>`r`n"
        $CY += $Buffer + $CRadius*2
    }

    $SVG += "</svg>"
    return $SVG
}

<#
.SYNOPSIS
    Creates an SVG LineChart or BarChart.

.PARAMETER DataPoints
    Your data set. Must be a hashtable containing items with a string Name key and Numerical Value. Such as @{"Test Point"=14;"Test Point2"=24}

.PARAMETER Colors
    An array of colors in HEX format. These are used as the colors in the chart. If null, colors will be auto-selected. @("#000000", "#ffffff", "#FF2235").

.PARAMETER FontFolor
    Color of the text in hex format

.PARAMETER Height
    Height of the SVG tag. 100% by default. Set to "auto" or "100%" to manipulate via CSS on parent element.

.PARAMETER Width
    Width of the SVG tag. 100% by default. Set to "auto" or "100%" to manipulate via CSS on parent element.

.PARAMETER ChartPadding
	 Padding between edge of view port and chart. defaults to 4

.PARAMETER XAxisLabel
	 Label for the X Axis, defaults to "X-Axis"

.PARAMETER YAxisLabel
	 Label for the Y Axis, defaults to "Y-Axis"

.PARAMETER LabelPadding
	 Padding between labels, defaults to 10

.PARAMETER Line
    Switch, draw a line chart

.PARAMETER Bar
    Switch, draw a bar chart

.PARAMETER FontColor
	 Color of all font, defaults to "#000000"

.PARAMETER MaxYAxisValue
	 Max value for the Y axis, defaults to Max value of your data points

.PARAMETER MinYAxisValue
	 Min value for the Y axis, defaults to 0

.PARAMETER YAxisValueLabelCount
	 Number of y axis value markers to draw, defaults to 4+(($DataPoints.Count-4)/2))

.PARAMETER BackgroundColor
	 Color of the chart background, defaults to "#FFFFFF"

.PARAMETER AxisColor
	 Color of the Axis lines, defaults to "#000000"

.PARAMETER MainLineColor
	 Color of the data line for a line chart, defaults to "#000000"

.PARAMETER Dots
    Draw dots, combine with Line parameter for most readability

.PARAMETER DotRadius
	 Size of the dots to draw, defaults to 6

.EXAMPLE
    $DataPoints = @{"Test1"=35; "Test2"=53;"Test3"=70;"Test4"="18"}; New-LineBarChart -DataPoints $DataPoints -Bar

.EXAMPLE
    New-LineBarChart -DataPoints $DataPoints -BackgroundColor "#FFFFFF99" -FontColor "#000000" -AxisColor "#000000" -Line -MainLineColor "#333333"
#>
function New-LineBarChart {
    Param(
        $Width="100%",
        $Height="100%",
        $ChartPadding=4,
        $DataPoints,
        $XAxisLabel="X-Axis",
        $YAxisLabel="Y-Axis",
        $LabelPadding =5,
        [switch]$Line,
        [switch]$Bar,
        $Colors,
        $FontColor="#000000",
        $MaxYAxisValue = ($DataPoints.Values | Sort-Object -Descending)[0],
        $MinYAxisValue = 0,
        $YAxisValueLabelCount = [System.Math]::Floor( 4+(($DataPoints.Count-4)/2)),
        $BackgroundColor = "#FFFFFF",
        $AxisColor = "#000000",
        $MainLineColor = "#000000",
        [switch]$Dots,
        $DotRadius=6,
        $ManualXLabelPadding=0,
        $ManualYLabelPadding=0
    )
    if ($YAxisValueLabelCount -lt 2) {
        $YAxisValueLabelCount = 2;
    }

    #Calculate Y Axis Labels
    $YAxisLabels = @([double]$MinYAxisValue)
    if ($YAxisValueLabelCount -gt 2) {
        $YSpread = ($MaxYAxisValue - $MinYAxisValue) / ($YAxisValueLabelCount-1)
        for ($I=0; $I -lt $YAxisValueLabelCount-2; $I++) {
            $YAxisLabels += @($YAxisLabels[$YAxisLabels.Length-1]+$YSpread)
        }
    }
    $YAxisLabels += @([double]$MaxYAxisValue)
    $YAxisLabels = $YAxisLabels | Sort-Object -Descending

    #General Chart Sizing

    $FontHeight = 14 #Assumed guess
    $FontWidth = 8.2 #Assumed guess

    $AxisLinePadding=10
    $XAxisLabelPadding=$FontHeight*2+$LabelPadding*3+$ManualXLabelPadding
    

    $DataKeys = $DataPoints.Keys | Sort-Object
    $MaxXAxisLabelLength = ($DataKeys | Sort-Object -Property Length -Descending)[0].Length
    $MaxYAxisLabelLength = (($YAxisLabels | foreach-object {$_.ToString("N0").Length}) | Sort-Object -Descending)[0]
    $YAxisLabelPadding= $MaxYAxisLabelLength*$FontWidth+$LabelPadding*2+$ManualYLabelPadding+$FontHeight

    $ViewBoxWidth = $ChartPadding+$AxisLinePadding+$YAxisLabelPadding+($DataPoints.Keys.Count)*($MaxXAxisLabelLength*$FontWidth+$LabelPadding)
    $ViewBoxHeight = $ChartPadding+$AxisLinePadding+$XAxisLabelPadding+($LabelPadding+$FontHeight)*$YAxisValueLabelCount

    #Important Measurements
    $ChartAreaHeight = $ViewBoxHeight-$ChartPadding-$AxisLinePadding-$XAxisLabelPadding
    $ChartAreaWidth = $ViewBoxWidth-$ChartPadding-$AxisLinePadding-$YAxisLabelPadding

    #Generate a Spread of Colors
    if ($Colors -eq $null -or $Colors.Count -lt $DataPoints.Count) {
        if ($Colors -ne $null -and $Colors.Count -lt $DataPoints.Count) {
            Write-Warning "Not enough colors provided. Colors will be auto-generated."
        }
        $Colors = Get-ColorSpread -Amount $DataPoints.Count | Get-HexColor
    }

    $HTMLDimensions = ""
    if ($Height -ne $null) {
        $HTMLDimensions = " height=`"$Height`""
    }
    if ($Width -ne $null) {
        $HTMLDimensions += " width=`"$Width`""
    }

    $SVG = "<svg viewBox=`"0 0 $ViewBoxWidth $ViewBoxHeight`"$HTMLDimensions>`r`n"

    #Draw BG
    $SVG += "`t<rect x=`"$($ChartPadding/2)`" y=`"$($ChartPadding/2)`" width=`"$($ViewBoxWidth-$ChartPadding)`" height=`"$($ViewBoxHeight-$ChartPadding)`" style=`"fill:$BackgroundColor;stroke-width:1;`" />`r`n"

    #Draw Y Axis Scale Lines and Labels
    
    $CurrentX = $YAxisLabelPadding+$($ChartPadding/2)
    $CurrentY = $AxisLinePadding+$ChartPadding/2
    $EndX = $CurrentX+$ChartAreaWidth
    $Spacing = $ChartAreaHeight / ($YAxisLabels.Count-1)
    for ($I=0; $I-lt $YAxisLabels.Count; $I++) {
        $LabelText = $YAxisLabels[$I].ToString("N0")
        $SVG += "`t<line x1=`"$CurrentX`" y1=`"$CurrentY`" x2=`"$EndX`" y2=`"$CurrentY`" style=`"stroke:$AxisColor;stroke-width:1;stroke-dasharray:5;`" />`r`n"
        $SVG += "`t<text x=`"$($CurrentX-$LabelPadding)`" text-anchor=`"end`" y=`"$($CurrentY+$FontHeight/2)`" fill=`"$FontColor`">$LabelText</text>`r`n"
        
        $CurrentY+=$Spacing
    }

    #Draw X Axis Scale Labels

    $CurrentY = $AxisLinePadding+$ChartPadding+$ChartAreaHeight+$LabelPadding+$FontHeight
    for ($I=0; $I -lt $DataKeys.Count; $I++) {
        #XAxisStartX+(XAxisWidth/XLabelCount/2)+(XAxisWidth/XLabelCount)*ItemIndex
        $CurrentX = $YAxisLabelPadding+$($ChartPadding/2)+($ChartAreaWidth/$DataKeys.Count/2)+($ChartAreaWidth/$DataKeys.Count)*$I
        $SVG+="`t<text x=`"$CurrentX`" text-anchor=`"middle`" y=`"$CurrentY`" fill=`"$FontColor`">$($DataKeys[$I])<title>$($DataPoints[$DataKeys[$I]])</title></text>`r`n"
    }

    #Draw Main Chart Labels

	$SVG+="`t<text x=`"$($LabelPadding+$ChartPadding+$FontHeight)`" y=`"$($ViewBoxHeight/2+$YAxisLabel.Length*$FontWidth/2)`" fill=`"$FontColor`" transform=`"rotate(270 $($LabelPadding+$ChartPadding+$FontHeight),$($ViewBoxHeight/2+$YAxisLabel.Length*$FontWidth/2))`">$YAxisLabel</text>`r`n"
	$SVG+="`t<text x=`"$($ViewBoxWidth/2-$XAxisLabel.Length*$FontWidth/2)`" y=`"$($ViewBoxHeight-$ChartPadding/2-$LabelPadding)`" fill=`"$FontColor`">$XAxisLabel</text>`r`n"

    #Draw Bars if requested
    if ($Bar) {
        $BarWidth = $ChartAreaWidth/$DataKeys.Length
        for ($I=0; $I-lt $DataKeys.Length; $I++) {
            $OutLineColor = Get-ColorFromHex -Color $Colors[$I]
            $OutLineColor = Get-HexColor -Color ([System.Drawing.Color]::FromArgb(255,$OutLineColor.R/2, $OutLineColor.G/2, $OutLineColor.B/2))
            $BarHeight = ($DataPoints[$DataKeys[$I]]-$MinYAxisValue)*($ChartAreaHeight/($MaxYAxisValue-$MinYAxisValue))
            if ($BarHeight -lt 0) {
                $BarHeight = 1;
                Write-Warning "Chart scale is incorrect. Please select a minimum Y axis that can support $DataKeys[$I]"
            }
            if ($BarHeight -gt ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)) {
                $BarHeight = ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight);
                Write-Warning "Chart scale is incorrect. Please select a maximum Y axis that can support $DataKeys[$I]"
            }
            $SVG+="`t<rect x=`"$($YAxisLabelPadding+$($ChartPadding/2)+$BarWidth*$I)`" y=`"$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight-$BarHeight)`" width=`"$BarWidth`" height=`"$BarHeight`" style=`"fill:$($Colors[$I]);stroke-width:1;stroke:$OutLineColor`"><title>$($DataPoints[$DataKeys[$I]])</title></rect>`r`n"
        }
    }

    #Draw Line if requested
    if ($Line -or $Dots) {
        $LineCircleLocations = @()
        $I=0;
        $BarHeight = ($DataPoints[$DataKeys[$I]]-$MinYAxisValue)*($ChartAreaHeight/($MaxYAxisValue-$MinYAxisValue))
        if ($BarHeight -lt 0) {
                $BarHeight = 1;
                Write-Warning "Chart scale is incorrect. Please select a minimum Y axis that can support $DataKeys[$I]"
            }
            if ($BarHeight -gt ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)) {
                $BarHeight = ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight);
                Write-Warning "Chart scale is incorrect. Please select a maximum Y axis that can support $DataKeys[$I]"
            }
        $CurrentX = $YAxisLabelPadding+$($ChartPadding/2)+($ChartAreaWidth/$DataKeys.Count/2)+($ChartAreaWidth/$DataKeys.Count)*$I
        $FullLinePath = "M $CurrentX,$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight-$BarHeight)"
        $LineCircleLocations +=@{X=$CurrentX;Y=$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight-$BarHeight)}
        for ($I=1; $I -lt $DataKeys.Length; $I++) {
            $BarHeight = ($DataPoints[$DataKeys[$I]]-$MinYAxisValue)*($ChartAreaHeight/($MaxYAxisValue-$MinYAxisValue))
            if ($BarHeight -lt 0) {
                $BarHeight = 1;
                Write-Warning "Chart scale is incorrect. Please select a minimum Y axis that can support $DataKeys[$I]"
            }
            if ($BarHeight -gt ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)) {
                $BarHeight = ($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight);
                Write-Warning "Chart scale is incorrect. Please select a maximum Y axis that can support $DataKeys[$I]"
            }
            $CurrentX = $YAxisLabelPadding+$($ChartPadding/2)+($ChartAreaWidth/$DataKeys.Count/2)+($ChartAreaWidth/$DataKeys.Count)*$I
            $FullLinePath+= " L $CurrentX,$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight-$BarHeight)"
            $LineCircleLocations +=@{X=$CurrentX;Y=$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight-$BarHeight)}
        }
        if ($Line) {
            $SVG+="`t<path d=`"$FullLinePath`" style=`"fill:none;stroke-width:2;stroke:$MainLineColor`" />`r`n"
        }
    }
    #Draw Main Chart Axis Boundary Lines
    
	$SVG+="`t<line x1=`"$($YAxisLabelPadding+$ChartPadding/2)`" y1=`"$($ChartPadding/2+$AxisLinePadding)`" x2=`"$($YAxisLabelPadding+$ChartPadding/2)`" y2=`"$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)`" style=`"stroke:$AxisColor;stroke-width:3`" />`r`n"
	$SVG+="`t<line x1=`"$($YAxisLabelPadding+$ChartPadding/2)`" y1=`"$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)`" x2=`"$($YAxisLabelPadding+$ChartPadding/2+$ChartAreaWidth)`" y2=`"$($ChartPadding/2+$AxisLinePadding+$ChartAreaHeight)`" style=`"stroke:$AxisColor;stroke-width:3`" />`r`n"

    #If draw dots
    if ($Dots) {
        $I=0;
        for ($I=0; $I -lt $DataKeys.Count; $I++) {
            $OutLineColor = Get-ColorFromHex -Color $Colors[$I]
            $OutLineColor = Get-HexColor -Color ([System.Drawing.Color]::FromArgb(255,$OutLineColor.R/2, $OutLineColor.G/2, $OutLineColor.B/2))
            $SVG+="`t<circle cx=`"$($LineCircleLocations[$I].X)`" cy=`"$($LineCircleLocations[$I].Y)`" r=`"$DotRadius`" stroke=`"$OutLineColor`" stroke-width=`"1`" fill=`"$($Colors[$I])`"><title>$($DataPoints[$DataKeys[$I]])</title></circle>`r`n"
        }
        
    }


    $SVG += "</svg>"
    return $SVG
}
#endregion

#region Table functions
<#
.SYNOPSIS
Returns an HTML table by array.

.DESCRIPTION
Takes an array parameter and automatically formats a HTML <table> out of it.

.PARAMETER Items
An array of items to add to the <table>. The first elements of the array are column headers. The amount of headers and the amount of items in each row is determined by "NumberOfHeaders".

.PARAMETER NumberOfHeaders
The number of headers to add to the <table>. The first NumberOfHeaders items in the array are added as headers. Each successive NumberOfHeaders amount of items make up the rows.

.EXAMPLE
Convert-ToArrayTable -Items @("Name","Favorite Color","John","Blue") -NumberOfHeaders 2

.EXAMPLE
Convert-ToArrayTable -Items @("Name","Favorite Color","Age","John","Blue","32") -NumberOfHeaders 3
#>
function Convert-ToArrayTable
{
	Param
    (
        [Parameter(Mandatory=$true)]
        [System.Object[]] $Items, 
        [Parameter(Mandatory=$true)]
        [int] $NumberOfHeaders
    )
    $ToReturn = "";
	if ($NumberOfHeaders -lt $Items.Length)
	{
		$ToReturn+="<table class=`"ArrayTable`">";
		for ($I = 0; $I -lt $Items.Length; $I++)
		{
			if ($I -eq 0)
			{
				$ToReturn+="<tr>";
			}
			elseif ($I % $NumberOfHeaders -eq 0)
			{
				$ToReturn += "</tr>";
				$ToReturn+="<tr>";
			}
			
            if ($I -lt $NumberOfHeaders)
            {
                $ToReturn+= "<th>"
            }
            else
            {
                $ToReturn+="<td>"
            }
            $ToReturn+= [System.Web.HttpUtility]::HtmlEncode($Items[$I].ToString())
            if ($I -lt $NumberOfHeaders)
            {
                $ToReturn+= "</th>"
            }
            else
            {
                $ToReturn+="</td>";
            }
		}
		$ToReturn+="</tr>";
		$ToReturn += "</table>";
        return $ToReturn;
	}
    else
    {
        Write-Warning "The number of column headers out-numbers the items"
        
    }
    return $null;
}

<#
.SYNOPSIS
Returns an HTML table by array of objects.

.DESCRIPTION
Takes an array parameter containing objects and automatically formats an HTML <table> out of it.

.PARAMETER Objects
An array of items to add to the <table>.

.PARAMETER Properties
If null, the table will contain all properties of the objects in the table otherwise the table will contain only those properties in this parameter in order.

.EXAMPLE
Convert-ToObjArrayTable -Items @((New-Object -TypeName PSObject -Property @{Name="Test1";Status="Up";GUID="000-00-000"}), (New-Object -TypeName PSObject -Property @{Name="Test2";Status="Down";GUID="000-00-000"}))

.EXAMPLE
Convert-ToObjArrayTable -Items @((New-Object -TypeName PSObject -Property @{Name="Test1";Status="Up";GUID="000-00-000"}), (New-Object -TypeName PSObject -Property @{Name="Test2";Status="Down";GUID="000-00-000"})) -Properties @("Name", "Status")
#>
function Convert-ToObjArrayTable {
    Param([Array]$Objects, $Properties, $Depth=0)
    if ($Properties -eq $null) {
        $Properties = ($Objects[0] | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" -and $_.Name -notlike "__*"}).Name
    }
    $Headers = $Properties
    $NewTable = @{"Headers"=$Headers}
    $KeyI = 1
    foreach ($Item in $Objects) {
        $Props = @()
        for ($I=0;$I-lt $Headers.Length;$I++) {
            $Header = $Headers[$I]
            if ($Item.$Header -ne $null) {
                $Props += , $Item.$Header #Oh my god PowerShell... STOP HELPING
            } else {
                $Props += "[No information]"
            }
        }
        $NewTable += @{"Row$KeyI"=$Props}
        $KeyI++;
    }
    return Convert-ToHashRowTable -Table ($NewTable) -HeadersKey "Headers" -Depth $Depth
}

<#
.SYNOPSIS
Returns an HTML table by hashtable.

.DESCRIPTION
Takes a hashtable parameter and automatically formats a HTML <table> out of it.

.PARAMETER Table
A hashtable of items to add to the <table>. The keys of the hashtable are column headers. The values of the keys should be arrays. Each item in the array represents the values of the cells in that column.

.EXAMPLE
Add-HashColumnTable -InputObject $MyReport -Table @{"Name"=@("John","Jack");"Favorite Color"=@("Red","Green")}

.EXAMPLE
$MyReport | Add-HashColumnTable -Table @{"Name"=@("John","Jack");"Favorite Color"=@("Red","Green"); "Age"=@("23","42")}
#>
function Convert-ToHashColumnTable
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [hashtable] $Table
    )
    $ToReturn = ""
	if ($Table.Keys.Count -gt 0)
	{
		$ToReturn+="<table class=`"HashColumnTable`">";

		$Iterations = 0;

		#region Table Headers
		$ToReturn+="<tr>";

		foreach ($Key in $Table.Keys)
		{
			$ToReturn+="<th>" + [System.Web.HttpUtility]::HtmlEncode($Key.ToString()) + "</th>";
			if ($Table[$Key].Length -gt $Iterations)
			{
				$Iterations = $Table[$Key].Length;
			}
		}

		$ToReturn+="</tr>";
		#endregion

		#region Table Info
		for ($I = 0; $I -lt $Iterations; $I++)
		{
			$ToReturn+="<tr>";
			foreach ($Key in $Table.Keys)
			{
				if ($Table[$Key].Length -gt $I)
				{
					$ToReturn+="<td>" + [System.Web.HttpUtility]::HtmlEncode($Table[$Key][$I].ToString()) + "</td>";
				}
				else
				{
					$ToReturn+="<td></td>";
				}
			}
			$ToReturn+="</tr>";
		}
		#endregion

		$ToReturn+="</table>";
        return $ToReturn
	}
    else
    {
        Write-Warning "Hashtable does not have enough keys"
    }
    return $null
}

<#
.SYNOPSIS
Returns an html table by hashtable.

.DESCRIPTION
Takes a hashtable parameter and automatically formats a HTML <table> out of it.

.PARAMETER Table
A hashtable of items to add to the <table>. The hashtable should contain arrays as values. The HeadersKey parameter determines which Key's value is used as column headers. Every other Key/Value pair represents a new row in the table.

.PARAMETER HeadersKey
An object that relates to one of the keys in the Table parameter. It specifies which Key/Value is to be used for the table headers.

.EXAMPLE
Convert-ToHashRowTable -Table @{"Headers"=@("Name","Favorite Color");"JacksRow"=@("Jack","Red")} -HeadersKey "Headers"

.EXAMPLE
Convert-ToHashRowTable -Table @{"Headers"=@("Name","Favorite Color","Age");"JacksRow"=@("Jack","Red","23");"JohnsRow"=@("John","Green","42")} -HeadersKey "Headers"
#>
function Convert-ToHashRowTable
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [hashtable] $Table, 
        [Parameter(Mandatory=$true)]
        $HeadersKey,
        $Depth = 0
    )
    $ToReturn = ""
	if ($Table.Keys.Count -gt 0 -and $Table.ContainsKey($HeadersKey))
	{
		$ToReturn+="<table class=`"HashRowTable`">";

		$Iterations = $Table[$HeadersKey].Count;

        $ToReturn+="<tr>";
        foreach($Value in $Table[$HeadersKey])
        {
            $ToReturn+="<th>" + [System.Web.HttpUtility]::HtmlEncode($Value.ToString()) + "</th>";
        }
        $ToReturn+="</tr>";

        foreach ($Key in $Table.Keys)
        {
            if ($Key -ne $HeadersKey)
            {
                $Count = 0;
                $ToReturn+="<tr>";
                foreach($Value in $Table[$Key])
                {
                    if ($Count -lt $Iterations)
                    {
                        if ($Value.GetType().BaseType.Name -eq "Array" -and $Depth -gt 0) {
                            $ToReturn += "<td>" + (Convert-ToObjArrayTable -Objects $Value -Depth ($Depth-1)) + "</td>";
                        }else {
                            $ToReturn+="<td>" + [System.Web.HttpUtility]::HtmlEncode($Value.ToString()) + "</td>";
                        }
                        $Count++
                    }
                    else
                    {
                        break
                    }
                }
                $ToReturn+="</tr>";
            }
        }

		$ToReturn+="</table>";
        return $ToReturn;
	}
    else
    {
        Write-Warning "Hashtable does not have enough keys"
    }
    return $null;
}
#endregion

#region Colors
<#
.SYNOPSIS
Gets the 3 color components of a color as a string for HTML use

.PARAMETER Color
Color to get String

.EXAMPLE
Convert-ToHTMLColorString -Color $MyColor
#>
function Convert-ToHTMLColorString
{
    Param
    (
        [System.Drawing.Color]$Color
    )
    return $Color.R.ToString()+" , "+$Color.G.ToString()+" , "+$Color.B.ToString()
}

<#
.SYNOPSIS
    Converts a .NET Color object to hex format (ex, #FFaa13)

.PARAMETER Color
    Color to get Hex

.PARAMETER IncludeAlpha
    Includes the alpha value at the end of the hex (#000000FF)
#>
function Get-HexColor {
    Param
    (
        [parameter(ValueFromPipeline,Mandatory=$true)][System.Drawing.Color[]]$Color, [switch]$IncludeAlpha
    )
    begin
    {
        $ToReturn = @()
    }
    Process
    {
        foreach ($ToProcess in $Color) 
        {
            $ToReturn += ("#"+$ToProcess.R.ToString("x2")+$ToProcess.G.ToString("x2")+$ToProcess.B.ToString("x2"))
        }
    }
    end
    {
        return $ToReturn
    }
}

<#
.SYNOPSIS
    Converts a hex format color to a .net color object (ex, #FFaa13)

.PARAMETER Color
    Hex color to get color
#>
function Get-ColorFromHex {
    Param
    (
        [parameter(ValueFromPipeline,Mandatory=$true)][string[]]$Color
    )
    Process{
        $ToProcess = $null
        if ($_){
            $ToProcess = $_
        } else {
           $ToProcess = $Color[0] 
        }
        if ($ToProcess -match "^\#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$") {
            return [System.Drawing.Color]::FromArgb(255,[Int]::Parse($Matches[1], [System.Globalization.NumberStyles]::HexNumber), 
                [Int]::Parse($Matches[2], [System.Globalization.NumberStyles]::HexNumber),
                [Int]::Parse($Matches[3], [System.Globalization.NumberStyles]::HexNumber))
        } elseif ($ToProcess -match "^\#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$") {
            return [System.Drawing.Color]::FromArgb([Int]::Parse($Matches[4], [System.Globalization.NumberStyles]::HexNumber),
                [Int]::Parse($Matches[1], [System.Globalization.NumberStyles]::HexNumber), 
                [Int]::Parse($Matches[2], [System.Globalization.NumberStyles]::HexNumber),
                [Int]::Parse($Matches[3], [System.Globalization.NumberStyles]::HexNumber))
        } else {
            Write-Error "$ToProcess is not a valid hex color (#AA22FF format)"
        }
    }
}

#Helper Function
function Get-CorrectedHue {
    Param([float]$Hue)
    if ($Hue -lt 0 -or $Hue -gt 360 ) {
		$Hue = $Hue%360
        if ($Hue -lt 0) {
            $Hue += 360
        }
	}
    return $Hue
}

<#
.SYNOPSIS
    Selects several colors that are spread accross the spectrum evenly.

.PARAMETER Amount
    Number of colors to generate
#>
function Get-ColorSpread {
    Param($Amount, $HueOrigin=0, $HueSpread = 180, $HueStep = 45, [switch]$EvenSpread)
    $HueMin = Get-CorrectedHue -Hue ($HueOrigin - $HueSpread)

    $MaxOriginColors = $HueSpread*2/$HueStep

    if ($HueSpread*2 -ge 360) {
        $MaxOriginColors -=1 #Since it loops, we eliminate one color which would have been a duplicate
    }

    if ($MaxOriginColors -lt 1) {
        $MaxOriginColors = 1
    }
    $MaxSatValColors = $MaxOriginColors * 7

    $ToReturn = @()
    #Failover if we cant match colors with limited hue scope w/ sat and val
    if ($MaxSatValColors -lt $Amount -or $EvenSpread) {
        $Amount++ #We increment by one, but don't return the last color since HSV loops. (0 is pretty much the same as 360)
        for ($i=0;$i-lt $Amount-1;$i++) {
            $ToReturn += ConvertFrom-HSV -HSVColor @{H=360/$Amount*$I; S=.8; V=.8}
        }
    } else {
        $Accounted =0;
        $SatValPairs = @(@{Sat=.8;Val=.8},@{Sat=1;Val=.8},@{Sat=.8;Val=1},@{Sat=1;Val=1},@{Sat=.6;Val=.8},@{Sat=.8;Val=.6},@{Sat=.6;Val=.6})
        foreach ($SVPair in $SatValPairs) {
            for ($i=0;$i-lt $MaxOriginColors;$i++) {
                $HueI = Get-CorrectedHue -Hue ($HueMin+($HueSpread*2/$MaxOriginColors*$i))

                $ToReturn += ConvertFrom-HSV -HSVColor @{H=$HueI; S=$SVPair.Sat; V=$SVPair.Val}
                $Accounted++;
                if ($Accounted -eq $Amount) {
                    return $ToReturn;
                }
            }
        }
    }
    return $ToReturn
}

<#
.SYNOPSIS
    Converts an HSV to a .NET Color Object (HSV->RGB)

.PARAMETER HSVColor
    Color in HSV format (Such as @{H=60;S=1;V=1})
#>
function ConvertFrom-HSV {
    Param($HSVColor)
    if ($HSVColor.S -lt 0 -or $HSVColor.S -gt 1 -or $HSVColor.V -lt 0 -or $HSVColor.V -gt 1) {
        Write-Error "S and V should be 0-1. Values provided are outside of bounds"
        return
    }
    $ToReturn = @{R=0;G=0;B=0}
	$C = $HSVColor.S * $HSVColor.V
	$X = $C  * (1-[Math]::Abs((($HSVColor.H/60) % 2)-1))
	$m = $HSVColor.V - $C
    #Fix hue to be 0-360
	if ($HSVColor.H -lt 0 -or $HSVColor.H -gt 360 ) {
		$HSVColor.H = $HSVColor.H%360
        if ($HSVColor.H -lt 0) {
            $HSVColor.H += 360
        }
	}
	if (0-le $HSVColor.H -and $HSVColor.H -lt 60 ) {
		$ToReturn.R = $C
		$ToReturn.G = $X
		$ToReturn.B = 0
	} elseif (60-le $HSVColor.H -and $HSVColor.H -lt 120 ) {
		$ToReturn.R = $X
		$ToReturn.G = $C
		$ToReturn.B = 0
	} elseif (120-le $HSVColor.H -and $HSVColor.H -lt 180 ) {
		$ToReturn.R = 0
		$ToReturn.G = $C
		$ToReturn.B = $X
	} elseif (180-le $HSVColor.H -and $HSVColor.H -lt 240 ) {
		$ToReturn.R = 0
		$ToReturn.G = $X
		$ToReturn.B = $C
	} elseif (240-le $HSVColor.H -and $HSVColor.H -lt 300 ) {
		$ToReturn.R = $X
		$ToReturn.G = 0
		$ToReturn.B = $C
	} else {
		$ToReturn.R = $C
		$ToReturn.G = 0
		$ToReturn.B = $X
	}
	$ToReturn.R=($ToReturn.R + $m) * 255
	$ToReturn.G=($ToReturn.G + $m) * 255
	$ToReturn.B=($ToReturn.B + $m) * 255
	return [System.Drawing.Color]::FromArgb(255, $ToReturn.R, $ToReturn.G, $ToReturn.B)
}
#endregion

#region ReportBuildingOptions
<#
.SYNOPSIS
Attempts to get an HTML string based on the summary output. To be used by the RunChecks.ps1 script

.PARAMETER Summary
The Summary to get HTML from

.PARAMETER IsSuccess
Whether the summary represents a passing check

.PARAMETER Name
Name of the check

.PARAMETER IsHTML
Whether the Summary should be treated as raw HTML. (Prevents smart conversions to tables or lists)

.PARAMETER NoSubresultDIV
If set, a SubResult DIV will not be wrapped around the converted summary. 

.NOTES
Intended to be used on output of New-CheckStatus

.EXAMPLE
Convert-SummaryToHTML -Summary $Result.Summary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsHTML
#>
function Convert-SummaryToHTML {
    Param($Summary, $IsSuccess, $Name, $IsHTML, [switch]$NoSubresultDIV)
    $Class="Warning"
    if ($IsSuccess) {
        $Class = "StatusSuccess"
    } else {
        $Class = "StatusFailure"
    }
    $ToReturn = ""
    if (-not $NoSubresultDIV) {
        $ToReturn += "<div class=`"SubResult $Class $($Name -Replace "\W","_")`">`r`n"
    }
    if ($Summary -eq $null) {
        #If no summary information, return null.
        return $null;
    } elseif ($IsHTML) {
        #If explicitly set to HTML
        $ToReturn+= $Summary.ToString();
    } elseif ($Summary.GetType().Name -eq "Object[]" -and $Summary.Length -gt 0 -and $Summary[0].GetType().Name -eq "String") {
        #If an array of strings
        $ToReturn+="<ul>"
        foreach ($Item in $Summary) {
            $ToReturn += "<li>"+[System.Web.HttpUtility]::HtmlEncode($Item)+"</li>"
        }
        $ToReturn+="</ul>"
    } elseif ($Summary.GetType().Name -eq "Hashtable" -and $Summary.Keys.Length -gt 0) {
        #If a hashtable
        if ($Summary.ContainsKey("Headers")) {
            $ToReturn += Convert-ToHashRowTable -Table $Summary
        } else {
            $ToReturn += Convert-ToHashColumnTable -Table $Summary
        }
    } elseif ($Summary.GetType().Name -eq "Object[]" -and $Summary.Length -gt 0) {
        #If an array of objects
        $ToReturn += Convert-ToObjArrayTable -Objects $Summary
    } elseif ($Summary.GetType().Name -eq "Object[]" -and $Summary.Length -le 0) {
        #If an array of objects
        $ToReturn+= "<p>"+[System.Web.HttpUtility]::HtmlEncode("No Results")+"</p>";
    }
    else {
        #Any other object, try and get string.
        $ToReturn+= "<p>"+[System.Web.HttpUtility]::HtmlEncode($Summary.ToString())+"</p>";
    }
    if (-not $NoSubresultDIV) {
        $ToReturn+="</div>";
    }
    return $ToReturn;
}

<#
.SYNOPSIS
Attempts to get a string based on the summary output. To be used by the RunChecks.ps1 script

.PARAMETER Summary
The Summary to get text from

.PARAMETER IsSuccess
Whether the summary represents a passing check

.PARAMETER Name
Name of the check

.PARAMETER IsHTML
Whether the Summary should be treated as raw HTML. (Prevents smart conversions to tables or lists)

.NOTES
Intended to be used on output of New-CheckStatus

.EXAMPLE
Convert-SummaryToHTML -Summary $Result.Summary -IsSuccess $Result.IsSuccess -Name $Result.Name -IsHTML $Result.IsHTML
#>
function Convert-SummaryToPlainText {
    Param($Summary, $IsSuccess, $Name, $IsHTML, $Indent = "`t`t")

    $ToReturn = ""
    $Success = "Success"
    if (-not $IsSuccess) {
        $Success = "Failure"
    }
    $ToReturn += "`t$Name ($Success)`r`n"

    if ($Summary -eq $null) {
        #If no summary information, return null.
        return $null;
    } elseif ($IsHTML) {
        #If explicitly set to HTML
        $ToReturn += "$Indent|-- Converted From HTML --`r`n"
        $ToReturn += $Indent+($Summary.ToString() -replace "<[^>]+>","")+"`r`n"
        $ToReturn += "$Indent|----`r`n"
    } elseif ($Summary.GetType().Name -eq "Object[]" -and $Summary.Length -gt 0 -and $Summary[0].GetType().Name -eq "String") {
        #If an array of strings
        foreach ($Item in $Summary) {
            $ToReturn += "$Indent- "+$Item+"`r`n"
        }
    } elseif ($Summary.GetType().Name -eq "Hashtable" -and $Summary.Keys.Length -gt 0) {
        #If a hashtable
        if ($Summary.ContainsKey("Headers")) {
            #$ToReturn += Convert-ToHashRowTable -Table $Summary
            $ToReturn += $Indent;
            for ($I =0; $I-lt $Summary["Headers"].Length;$I++) {
                $ToReturn += $Summary["Headers"][$I]+"`t"
            }
            $ToReturn += "`r`n"
            foreach ($Key in $Summary.Keys) {
                if ($Key -ne "Headers") {
                    $Line = "$Indent"
                    for ($I =0; $I-lt $Summary[$Key].Length;$I++) {
                        if ($Summary[$Key][$I] -ne $null) {
                            $Line += $Summary[$Key][$I].ToString()+"`t"
                        } else {
                            $Line += "<null>`t"
                        }
                    }
                    $ToReturn+=$Line+"`r`n"
                }
            }
        } else {
            #$ToReturn += Convert-ToHashColumnTable -Table $Summary
            $Keys = $Summary.Keys
            $ToReturn+=$Indent
            for ($I =0; $I-lt $Keys.Length;$I++)
		    {
			    $ToReturn+=$Keys[$I].ToString() + "`t";
		    }
            $ToReturn+="`r`n"
            for ($I =0; $I-lt $Summary[$Keys[0]].Length;$I++)
		    {
                $Line = $Indent
                for ($KeyIndex =0; $KeyIndex-lt $Keys.Length;$KeyIndex++)
		        {
                    $Line+=$Summary[$Keys[$KeyIndex]][$I].ToString()+"`t"
                }
			    $Line+="`r`n"
                $ToReturn+=$Line
		    }
        }
    } elseif ($Summary.GetType().Name -eq "Object[]" -and $Summary.Length -gt 0) {
        #If an array of objects
        $Headers = ($Summary[0] | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" -and $_.Name -notlike "__*"}).Name
        
        $ToReturn += $Indent;
        for ($I =0; $I-lt $Headers.Length;$I++) {
            $ToReturn += $Headers[$I]+"`t"
        }
        $ToReturn += "`r`n"
        foreach ($Item in $Summary) {
            $Line = "$Indent"
            for ($I =0; $I-lt $Headers.Length;$I++) {
                $Header = $Headers[$I]
                if ($Item.$Header -ne $null) {
                    $Line += $Item.$Header.ToString()+"`t"
                } else {
                    $Line += "<null>`t"
                }
            }
            $ToReturn+=$Line+"`r`n"
        }
    }
    else {
        #Any other object, try and get string.
        $ToReturn+= "$Indent|----`r`n"+$Summary.ToString()+"`r`n$Indent|----`r`n";
    }
    return $ToReturn;
}
#endregion

#region Subreport Helper Function s
#Functions that are intended to be called by child scripts
<#
.SYNOPSIS
Returns a PSObject with prefilled properties compliant with GUCS use

.PARAMETER IsSuccess
If true, then the result of the check is a pass

.PARAMETER TechnicalSummary
An object that provides details of the result

.PARAMETER Summary
An object that provides a short Executive Summary of the result

.PARAMETER Name
The name of this check/report

.PARAMETER IsTechnicalHTML
Is the outputted TechnicalSummary in raw HTML format

.PARAMETER IsSummaryHTML
Is the Executive summary in raw HTML format

.EXAMPLE
New-CheckStatus -IsSuccess $true -TechnicalSummary $Logs -Summary "Logs show success" -Name "Log compliancy" -IsTechnicalHTML $false -IsSummaryHTML $false
#>
function New-CheckStatus {
    Param($IsSuccess=$true, $TechnicalSummary = $null, $Summary = $null, $Name="", $IsTechnicalHTML=$false, $IsSummaryHTML=$false, $Priority=1000)
    return (New-Object -TypeName PSObject -Property @{IsSuccess=$IsSuccess;TechnicalSummary=$TechnicalSummary;Summary=$Summary;Name=$Name;IsTechnicalHTML=$IsTechnicalHTML;IsSummaryHTML=$IsSummaryHTML;Priority=$Priority});
}

<#
.SYNOPSIS
Converts any object to a PSObject

.DESCRIPTION
Converts any object to a PSObject using only the NoteProperty and Property members of the object. These can optionally be further restricted. This is best used when outputting an array of object, but you are only interested in a few properties of the objects.

.PARAMETER OriginalObject
The object to convert

.PARAMETER Properties
A list of all properties you want in the new object. If null, all NoteProperty and Property members are used.

.EXAMPLE
Convert-ToPSObject -OriginalObject (Test-Connect "google.com" -ea SilentlyContinue) -Properties @("ResponseTime", "Address")
#>
function Convert-ToPSObject {
    Param($OriginalObject, $Properties)
    if ($Properties -eq $null) {
        $Properties = ($OriginalObject | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty" -or $_.MemberType -eq "Property" -and $_.Name -notlike "__*"}).Name
    }
    $Props = @{}
    foreach ($Property in $Properties) {
        $Props += @{$Property=$OriginalObject.$Property}
    }
    return New-Object -TypeName PSObject -Property $Props
}

<#
.SYNOPSIS
Returns a string with html for a loading bar-style element

.PARAMETER Size
Size of bar fill in percentage 0-100

.PARAMETER Text
Text to place on bar

.EXAMPLE
New-HTMLBar -Size 50 -Text "50% Complete"
#>
function New-HTMLBar {
    Param([int]$Size=0, [string]$Text=$Size.ToString()+"%")
    $Amnt = [Math]::Floor($Size/10)
    return "<div class='barContainer barSize$Amnt'><div class='barFill barSize$Amnt' style='width:$Size%'></div><div class='barText barSize$Amnt'>$Text</div></div>"
}
#endregion

#Export Functions
Export-ModuleMember -Function Convert-ImageToHTML, Import-SVG, Convert-ToArrayTable, Convert-ToHashColumnTable, Convert-ToHashRowTable, Convert-ToHTMLColorString, 
 Convert-SummaryToHTML, New-CheckStatus, Convert-ToPSObject, Convert-ToObjArrayTable, New-HTMLBar, Get-HexColor, Get-ColorFromHex, Get-ColorSpread, ConvertFrom-HSV,
 New-PieChart, New-LineBarChart
