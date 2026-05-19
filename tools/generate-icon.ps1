<#
.SYNOPSIS
    Regenerates GitBatchCommit.ico — the application icon.

.DESCRIPTION
    Vector-renders the "git-branch on slate" design (Option 1) with GDI+ at
    every Windows size and packs a single multi-resolution .ico:

        slate rounded-rect tile (vertical gradient, faint edge) with a
        white main branch (two commit nodes) and a git-orange feature
        branch curving in and merging — themed to the app's
        "Aqua Light Slate" VCL style.

    Sizes <=128 px are stored as 32-bit BGRA DIBs; 256 px as PNG.
    Output: <repo-root>\GitBatchCommit.ico  (referenced by
    GitBatchCommit.dproj <Icon_MainIcon>, embedded as MAINICON on build).

.NOTES
    Re-run after any design tweak, then rebuild so the .res picks it up.
    Requires Windows PowerShell / PowerShell 7+ with System.Drawing.

.EXAMPLE
    pwsh -File tools\generate-icon.ps1
#>

Add-Type -AssemblyName System.Drawing

$OutIco = Join-Path (Split-Path $PSScriptRoot -Parent) 'GitBatchCommit.ico'
$sizes  = 16, 24, 32, 48, 64, 128, 256

function New-IconBitmap([int]$S) {
    $bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # --- slate rounded-rect background with vertical gradient ---
    $radius = [single]($S * 0.18)
    $inset  = [single]($S * 0.045)
    $rx = $inset; $ry = $inset
    $rw = [single]($S - 2 * $inset); $rh = [single]($S - 2 * $inset)
    $d  = [single]($radius * 2)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($rx,                 $ry,                 $d, $d, 180, 90)
    $path.AddArc($rx + $rw - $d,      $ry,                 $d, $d, 270, 90)
    $path.AddArc($rx + $rw - $d,      $ry + $rh - $d,      $d, $d,   0, 90)
    $path.AddArc($rx,                 $ry + $rh - $d,      $d, $d,  90, 90)
    $path.CloseFigure()

    $rectF = New-Object System.Drawing.RectangleF($rx, $ry, $rw, $rh)
    $cTop  = [System.Drawing.Color]::FromArgb(255, 43, 58, 66)   # #2B3A42
    $cBot  = [System.Drawing.Color]::FromArgb(255, 27, 38, 44)   # #1B262C
    $grad  = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $cTop, $cBot, 90)
    $g.FillPath($grad, $path)

    # faint edge so the dark tile stays defined on dark backgrounds
    $penEdge = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 255, 255, 255), [single]([Math]::Max(1, $S * 0.012)))
    $g.DrawPath($penEdge, $path)

    # --- git-branch glyph ---
    $xTrunk  = [single]($S * 0.36)
    $xBranch = [single]($S * 0.64)
    $yTop    = [single]($S * 0.23)
    $yBot    = [single]($S * 0.77)
    $yMerge  = [single]($S * 0.55)
    $r       = [single]($S * 0.085)
    $sw      = [single]($S * 0.085)

    $white  = [System.Drawing.Color]::FromArgb(255, 245, 247, 248)
    $orange = [System.Drawing.Color]::FromArgb(255, 240, 81, 51)   # git #F05133

    $penTrunk = New-Object System.Drawing.Pen($white, $sw)
    $penTrunk.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penTrunk.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

    $penBranch = New-Object System.Drawing.Pen($orange, $sw)
    $penBranch.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penBranch.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

    # feature branch: drops from top-right, curves left, merges into trunk
    $branch = New-Object System.Drawing.Drawing2D.GraphicsPath
    $branch.AddBezier(
        $xBranch, $yTop,
        $xBranch, [single](($yTop + $yMerge) / 2),
        $xBranch, $yMerge,
        $xTrunk,  $yMerge)
    $g.DrawPath($penBranch, $branch)

    # main trunk
    $g.DrawLine($penTrunk, $xTrunk, $yTop, $xTrunk, $yBot)

    # commit nodes (drawn last so they sit crisp atop the lines)
    $brW = New-Object System.Drawing.SolidBrush($white)
    $brO = New-Object System.Drawing.SolidBrush($orange)
    $g.FillEllipse($brW, $xTrunk  - $r, $yTop - $r, 2 * $r, 2 * $r)   # top-left
    $g.FillEllipse($brW, $xTrunk  - $r, $yBot - $r, 2 * $r, 2 * $r)   # bottom-left
    $g.FillEllipse($brO, $xBranch - $r, $yTop - $r, 2 * $r, 2 * $r)   # top-right (feature)

    $g.Dispose()
    return $bmp
}

function Get-DibBytes([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $buf.Length)
    $bmp.UnlockBits($data)

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    # BITMAPINFOHEADER
    $bw.Write([int]40)
    $bw.Write([int]$w)
    $bw.Write([int]($h * 2))      # XOR + AND mask
    $bw.Write([int16]1)
    $bw.Write([int16]32)
    $bw.Write([int]0)             # BI_RGB
    $bw.Write([int]($w * $h * 4))
    $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0)
    # XOR pixel data, bottom-up
    for ($y = $h - 1; $y -ge 0; $y--) {
        $bw.Write($buf, $y * $stride, $w * 4)
    }
    # AND mask: alpha-driven, all zero, 1bpp rows padded to 4 bytes
    $maskStride = [int]([Math]::Floor(($w + 31) / 32) * 4)
    $zero = New-Object byte[] ($maskStride * $h)
    $bw.Write($zero, 0, $zero.Length)
    $bw.Flush()
    return $ms.ToArray()
}

# Build each image payload (<=128 as DIB, 256 as PNG)
$images = @()
foreach ($s in $sizes) {
    $bmp = New-IconBitmap $s
    if ($s -ge 256) {
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $payload = $ms.ToArray()
    } else {
        $payload = Get-DibBytes $bmp
    }
    $images += [pscustomobject]@{ Size = $s; Data = $payload }
    $bmp.Dispose()
}

# Assemble ICO container
$out = New-Object System.IO.MemoryStream
$bw  = New-Object System.IO.BinaryWriter($out)
$bw.Write([int16]0)                 # reserved
$bw.Write([int16]1)                 # type = icon
$bw.Write([int16]$images.Count)

$offset = 6 + 16 * $images.Count
foreach ($img in $images) {
    $dim = if ($img.Size -ge 256) { 0 } else { $img.Size }
    $bw.Write([byte]$dim)           # width
    $bw.Write([byte]$dim)           # height
    $bw.Write([byte]0)              # palette
    $bw.Write([byte]0)              # reserved
    $bw.Write([int16]1)             # planes
    $bw.Write([int16]32)            # bpp
    $bw.Write([int]$img.Data.Length)
    $bw.Write([int]$offset)
    $offset += $img.Data.Length
}
foreach ($img in $images) { $bw.Write($img.Data, 0, $img.Data.Length) }
$bw.Flush()

[System.IO.File]::WriteAllBytes($OutIco, $out.ToArray())
Write-Output ("Wrote {0} ({1:N0} bytes, {2} resolutions)" -f $OutIco, (Get-Item $OutIco).Length, $images.Count)
