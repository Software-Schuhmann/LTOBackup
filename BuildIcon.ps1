Add-Type -AssemblyName System.Drawing

function Fill-RoundRect($Graphics, $Brush, [single]$X, [single]$Y, [single]$W, [single]$H, [single]$R) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $p.AddArc($X, $Y, $d, $d, 180, 90); $p.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $p.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90); $p.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $p.CloseFigure(); $Graphics.FillPath($Brush, $p); $p.Dispose()
}

$sizes = @(256, 64, 32, 16)
$pngs = @()
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = $size / 256.0
    $g.ScaleTransform($scale, $scale)
    $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 21, 57, 91))
    $teal = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 8, 126, 139))
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 235, 243, 250))
    $dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 25, 59, 90))
    $reel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 224, 237, 247))
    $hole = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 103, 141, 169))
    $green = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 114, 224, 168), 11)
    Fill-RoundRect $g $bg 8 8 240 240 48
    Fill-RoundRect $g $teal 48 64 160 130 13
    $g.FillRectangle($white, 48, 76, 160, 104)
    Fill-RoundRect $g $dark 67 111 122 58 8
    foreach ($cx in @(99, 157)) {
        $g.FillEllipse($reel, $cx - 20, 120, 40, 40)
        $g.FillEllipse($hole, $cx - 11, 129, 22, 22)
    }
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 72, 195, 181), 6)), 110, 140, 146, 140)
    $g.DrawLine($green, 171, 198, 185, 212)
    $g.DrawLine($green, 185, 212, 214, 178)
    $stream = New-Object System.IO.MemoryStream
    $bmp.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,$stream.ToArray()
    $stream.Dispose(); $g.Dispose(); $bmp.Dispose()
    $bg.Dispose(); $teal.Dispose(); $white.Dispose(); $dark.Dispose(); $reel.Dispose(); $hole.Dispose(); $green.Dispose()
}

$outPath = Join-Path $PSScriptRoot 'LTOBackup.ico'
$fs = [System.IO.File]::Create($outPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $n = $sizes[$i]; $w = if ($n -eq 256) { 0 } else { $n }
    $bw.Write([byte]$w); $bw.Write([byte]$w); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]$pngs[$i].Length); $bw.Write([UInt32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($png in $pngs) { $bw.Write($png) }
$bw.Dispose(); $fs.Dispose()
Write-Output "Erstellt: $outPath"
