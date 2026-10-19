Add-Type -AssemblyName System.Drawing

function New-GraphicsPath-RoundRect($rect, $r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Build-MultiResIco($bitmaps, $outputPath) {
    $entries = @()
    $payloads = @()
    
    foreach ($bmp in $bitmaps) {
        $ms = New-Object System.IO.MemoryStream
        $hIcon = $bmp.GetHicon()
        $ico = [System.Drawing.Icon]::FromHandle($hIcon)
        $ico.Save($ms)
        $ico.Dispose()
        
        $raw = $ms.ToArray()
        $dirEntry = [byte[]]::new(16)
        [Array]::Copy($raw, 6, $dirEntry, 0, 16)
        
        $dataLen = [BitConverter]::ToUInt32($dirEntry, 8)
        $dataOffset = [BitConverter]::ToUInt32($dirEntry, 12)
        
        $payload = [byte[]]::new($dataLen)
        [Array]::Copy($raw, $dataOffset, $payload, 0, $dataLen)
        
        $entries += ,$dirEntry
        $payloads += ,$payload
    }
    
    $outMs = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $outMs
    
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$entries.Count)
    
    $currentOffset = 6 + (16 * $entries.Count)
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entry = $entries[$i]
        $payload = $payloads[$i]
        
        $offsetBytes = [BitConverter]::GetBytes([uint32]$currentOffset)
        [Array]::Copy($offsetBytes, 0, $entry, 12, 4)
        
        $bw.Write($entry, 0, 16)
        $currentOffset += $payload.Length
    }
    
    foreach ($p in $payloads) {
        $bw.Write($p, 0, $p.Length)
    }
    
    [System.IO.File]::WriteAllBytes($outputPath, $outMs.ToArray())
}

function Resize-Bitmap($source, $targetSize) {
    $dest = New-Object System.Drawing.Bitmap $targetSize, $targetSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($source, 0, 0, $targetSize, $targetSize)
    $g.Dispose()
    return $dest
}

function Create-ProcessSpyIcon() {
    $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # 1. Tile Base
    $rect = New-Object System.Drawing.Rectangle 12, 12, 232, 232
    $path = New-GraphicsPath-RoundRect $rect 48
    $baseBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 20, 22, 27))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 42, 47, 56)), 3
    $g.FillPath($baseBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # 2. Cyan Header Accent
    $cyanAccent = [System.Drawing.Color]::FromArgb(255, 0, 210, 255)
    $accentBrush = New-Object System.Drawing.SolidBrush $cyanAccent
    $pillRect = New-Object System.Drawing.Rectangle 88, 26, 80, 8
    $pillPath = New-GraphicsPath-RoundRect $pillRect 4
    $g.FillPath($accentBrush, $pillPath)
    
    # 3. Chevron `>` (Prompt)
    $whitePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 16
    $whitePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    
    $chevPoints = @(
        (New-Object System.Drawing.Point 46, 78),
        (New-Object System.Drawing.Point 82, 114),
        (New-Object System.Drawing.Point 46, 150)
    )
    $g.DrawLines($whitePen, $chevPoints)
    
    # Parameter Arguments: Horizontal Bars
    $argPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 148, 163, 184)), 12
    $argPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $argPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($argPen, 104, 94, 180, 94)
    $g.DrawLine($argPen, 104, 134, 145, 134)
    
    # 4. Magnifying Inspection Lens (Accent Cyan + Crisp White Ring)
    $lensPen = New-Object System.Drawing.Pen $cyanAccent, 15
    $g.DrawEllipse($lensPen, 115, 105, 78, 78)
    
    # Lens Handle
    $handlePen = New-Object System.Drawing.Pen $cyanAccent, 17
    $handlePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $handlePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($handlePen, 174, 164, 215, 205)
    
    # Center Inspection Reticle Dot
    $whiteDotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillEllipse($whiteDotBrush, 150, 140, 8, 8)
    
    $g.Dispose()
    return $bmp
}

function Create-WindowSpyIcon() {
    $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # 1. Tile Base
    $rect = New-Object System.Drawing.Rectangle 12, 12, 232, 232
    $path = New-GraphicsPath-RoundRect $rect 48
    $baseBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 20, 22, 27))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 42, 47, 56)), 3
    $g.FillPath($baseBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # 2. Azure Accent
    $azure = [System.Drawing.Color]::FromArgb(255, 56, 189, 248)
    $accentBrush = New-Object System.Drawing.SolidBrush $azure
    $pillRect = New-Object System.Drawing.Rectangle 88, 26, 80, 8
    $pillPath = New-GraphicsPath-RoundRect $pillRect 4
    $g.FillPath($accentBrush, $pillPath)
    
    # 3. Background Layer Window
    $bgWinRect = New-Object System.Drawing.Rectangle 44, 58, 120, 92
    $bgWinPath = New-GraphicsPath-RoundRect $bgWinRect 14
    $bgWinBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 34, 38, 47))
    $bgWinPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 71, 85, 105)), 4
    $g.FillPath($bgWinBrush, $bgWinPath)
    $g.DrawPath($bgWinPen, $bgWinPath)
    # Background Window titlebar line
    $g.DrawLine($bgWinPen, 44, 82, 164, 82)
    
    # 4. Foreground Window
    $fgWinRect = New-Object System.Drawing.Rectangle 80, 94, 134, 104
    $fgWinPath = New-GraphicsPath-RoundRect $fgWinRect 16
    $fgWinBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 26, 30, 38))
    $fgWinPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 6
    $g.FillPath($fgWinBrush, $fgWinPath)
    $g.DrawPath($fgWinPen, $fgWinPath)
    
    # Foreground window titlebar
    $fgTitleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 37, 99, 235))
    $fgHeaderRect = New-Object System.Drawing.Rectangle 80, 94, 134, 26
    $fgHeaderPath = New-GraphicsPath-RoundRect $fgHeaderRect 16
    $g.FillRectangle($fgTitleBrush, 80, 108, 134, 14)
    $g.DrawLine($fgWinPen, 80, 122, 214, 122)
    
    # Window Dots (Close/Min/Max)
    $dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 203, 213, 225))
    $g.FillEllipse($dotBrush, 92, 104, 8, 8)
    $g.FillEllipse($dotBrush, 106, 104, 8, 8)
    $g.FillEllipse($dotBrush, 120, 104, 8, 8)
    
    # 5. Inspection Crosshair / Focus Lens in Azure
    $lensPen = New-Object System.Drawing.Pen $azure, 8
    $g.DrawEllipse($lensPen, 125, 130, 60, 60)
    
    # Crosshair Ticks
    $reticlePen = New-Object System.Drawing.Pen $azure, 5
    $reticlePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $reticlePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($reticlePen, 155, 118, 155, 127) # Top
    $g.DrawLine($reticlePen, 155, 193, 155, 202) # Bottom
    $g.DrawLine($reticlePen, 113, 160, 122, 160) # Left
    $g.DrawLine($reticlePen, 188, 160, 197, 160) # Right
    
    $centerDot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillEllipse($centerDot, 152, 157, 6, 6)
    
    $g.Dispose()
    return $bmp
}

function Create-HardwareSentinelIcon() {
    $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # 1. Tile Base
    $rect = New-Object System.Drawing.Rectangle 12, 12, 232, 232
    $path = New-GraphicsPath-RoundRect $rect 48
    $baseBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 20, 22, 27))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 42, 47, 56)), 3
    $g.FillPath($baseBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # 2. Emerald Accent
    $emerald = [System.Drawing.Color]::FromArgb(255, 16, 185, 129)
    $accentBrush = New-Object System.Drawing.SolidBrush $emerald
    $pillRect = New-Object System.Drawing.Rectangle 88, 26, 80, 8
    $pillPath = New-GraphicsPath-RoundRect $pillRect 4
    $g.FillPath($accentBrush, $pillPath)
    
    # 3. Sentinel Shield (Geometric)
    $shieldPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $shieldPath.AddLine(128, 52, 198, 76)
    $shieldPath.AddLine(198, 76, 198, 142)
    $shieldPath.AddBezier(198, 142, 198, 194, 128, 218, 128, 218)
    $shieldPath.AddBezier(128, 218, 58, 194, 58, 142, 58, 142)
    $shieldPath.AddLine(58, 142, 58, 76)
    $shieldPath.CloseFigure()
    
    $shieldBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 16, 185, 129))
    $shieldPen = New-Object System.Drawing.Pen $emerald, 9
    $shieldPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.FillPath($shieldBrush, $shieldPath)
    $g.DrawPath($shieldPen, $shieldPath)
    
    # 4. Integrated Circuit / Chip in Center
    $chipRect = New-Object System.Drawing.Rectangle 100, 106, 56, 56
    $chipPath = New-GraphicsPath-RoundRect $chipRect 10
    $chipBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 26, 30, 38))
    $chipPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 5
    $g.FillPath($chipBrush, $chipPath)
    $g.DrawPath($chipPen, $chipPath)
    
    # Pin traces radiating out
    $pinPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 5
    $pinPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pinPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    
    # Top & Bottom pins
    $g.DrawLine($pinPen, 114, 94, 114, 106)
    $g.DrawLine($pinPen, 142, 94, 142, 106)
    $g.DrawLine($pinPen, 114, 162, 114, 174)
    $g.DrawLine($pinPen, 142, 162, 142, 174)
    
    # Left & Right pins
    $g.DrawLine($pinPen, 88, 120, 100, 120)
    $g.DrawLine($pinPen, 88, 148, 100, 148)
    $g.DrawLine($pinPen, 156, 120, 168, 120)
    $g.DrawLine($pinPen, 156, 148, 168, 148)
    
    # Glowing Core Dot
    $coreBrush = New-Object System.Drawing.SolidBrush $emerald
    $g.FillEllipse($coreBrush, 120, 126, 16, 16)
    
    $g.Dispose()
    return $bmp
}

function Create-ShellSentinelIcon() {
    $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    
    # 1. Tile Base
    $rect = New-Object System.Drawing.Rectangle 12, 12, 232, 232
    $path = New-GraphicsPath-RoundRect $rect 48
    $baseBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 20, 22, 27))
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 42, 47, 56)), 3
    $g.FillPath($baseBrush, $path)
    $g.DrawPath($borderPen, $path)
    
    # 2. Violet Accent
    $violet = [System.Drawing.Color]::FromArgb(255, 168, 85, 247)
    $accentBrush = New-Object System.Drawing.SolidBrush $violet
    $pillRect = New-Object System.Drawing.Rectangle 88, 26, 80, 8
    $pillPath = New-GraphicsPath-RoundRect $pillRect 4
    $g.FillPath($accentBrush, $pillPath)
    
    # 3. Sentinel Shield (Geometric)
    $shieldPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $shieldPath.AddLine(128, 52, 198, 76)
    $shieldPath.AddLine(198, 76, 198, 142)
    $shieldPath.AddBezier(198, 142, 198, 194, 128, 218, 128, 218)
    $shieldPath.AddBezier(128, 218, 58, 194, 58, 142, 58, 142)
    $shieldPath.AddLine(58, 142, 58, 76)
    $shieldPath.CloseFigure()
    
    $shieldBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 168, 85, 247))
    $shieldPen = New-Object System.Drawing.Pen $violet, 9
    $shieldPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.FillPath($shieldBrush, $shieldPath)
    $g.DrawPath($shieldPen, $shieldPath)
    
    # 4. Interactive Shell Prompt Chevron `>`
    $whitePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 10
    $whitePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    
    $chevPoints = @(
        (New-Object System.Drawing.Point 88, 114),
        (New-Object System.Drawing.Point 112, 136),
        (New-Object System.Drawing.Point 88, 158)
    )
    $g.DrawLines($whitePen, $chevPoints)
    
    # 5. Broadcasting Event Radar / Signal Waves in Violet
    $wavePen1 = New-Object System.Drawing.Pen $violet, 7
    $wavePen1.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wavePen1.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($wavePen1, 110, 116, 40, 40, -45, 90)
    
    $wavePen2 = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 248, 250, 252)), 7
    $wavePen2.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wavePen2.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($wavePen2, 120, 102, 68, 68, -45, 90)
    
    $g.Dispose()
    return $bmp
}

# --- Generation Execution ---
$outDir = Join-Path $PSScriptRoot "..\assets"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$tools = @(
    @{ Name = "Process_Spy_Pro"; Create = ${function:Create-ProcessSpyIcon} },
    @{ Name = "Window_Spy_Pro"; Create = ${function:Create-WindowSpyIcon} },
    @{ Name = "Hardware_Sentinel"; Create = ${function:Create-HardwareSentinelIcon} },
    @{ Name = "Shell_Sentinel"; Create = ${function:Create-ShellSentinelIcon} }
)

# Also create a composite preview image containing all 4 icons side-by-side
$previewBmp = New-Object System.Drawing.Bitmap (256 * 4 + 60), 296, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$prevG = [System.Drawing.Graphics]::FromImage($previewBmp)
$prevG.Clear([System.Drawing.Color]::FromArgb(255, 15, 17, 21))

$xPos = 12
foreach ($t in $tools) {
    Write-Host "Rendering $($t.Name) icon..."
    $masterBmp = & $t.Create
    
    # Draw onto preview
    $prevG.DrawImage($masterBmp, $xPos, 20, 256, 256)
    $xPos += 256 + 12
    
    # Save standalone master PNG
    $pngPath = Join-Path $outDir "$($t.Name).png"
    $masterBmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Generate multi-res bitmaps
    $sizes = @(16, 32, 48, 256)
    $bitmaps = @()
    foreach ($sz in $sizes) {
        $bitmaps += (Resize-Bitmap $masterBmp $sz)
    }
    
    $icoPath = Join-Path $outDir "$($t.Name).ico"
    Build-MultiResIco $bitmaps $icoPath
    Write-Host " -> Saved $icoPath"
    
    foreach ($b in $bitmaps) { $b.Dispose() }
    $masterBmp.Dispose()
}

$previewPath = Join-Path $outDir "suite_icons_preview.png"
$previewBmp.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$prevG.Dispose()
$previewBmp.Dispose()

Write-Host "`nAll icons generated successfully!"
