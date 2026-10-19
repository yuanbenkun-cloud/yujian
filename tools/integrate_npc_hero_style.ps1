$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $projectRoot 'assets/production/npc/cast_v3'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$sources = [ordered]@{
    flyer_lady    = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-304f03b6-6d20-48fb-bf1d-470a3beaf87c.png'
    old_artisan   = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-3c57d907-629c-4289-9d24-d78d645eef53.png'
    aming         = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-099330e9-933b-405a-973a-11053ef8ca1b.png'
    old_shopkeeper= 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-1ccf3a36-1000-4672-960b-c729334a88e2.png'
    fat_teahouse  = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-d6afea45-f35b-49f9-bf4e-ae8486598a57.png'
    helper        = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-fff71baa-9c49-4a0f-b29b-9e7c2e8d8dd1.png'
    laozhou       = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-b5eb5c9c-ca67-4727-93d8-f74ab1728477.png'
    old_man       = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-8e10418a-fe9b-40a6-99f0-56f392be64a4.png'
    tourist       = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-02fc9b28-f993-4e92-899d-e4b34a655117.png'
    vendor        = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-7ead292d-1e7f-40b4-86f8-56874b438bee.png'
    refugee       = 'C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-c487ca5b-bd29-489d-b824-2d236ebd9d50.png'
}

function Get-AlphaBounds([System.Drawing.Bitmap]$image, [System.Drawing.Rectangle]$cell) {
    $left = $cell.Right; $top = $cell.Bottom; $right = -1; $bottom = -1
    for ($y = $cell.Top; $y -lt $cell.Bottom; $y += 1) {
        for ($x = $cell.Left; $x -lt $cell.Right; $x += 1) {
            if ($image.GetPixel($x, $y).A -ge 24) {
                if ($x -lt $left) { $left = $x }; if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }; if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt $left -or $bottom -lt $top) { return $null }
    return [System.Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)
}

function Draw-NormalizedFrame(
    [System.Drawing.Graphics]$graphics,
    [System.Drawing.Bitmap]$source,
    [System.Drawing.Rectangle]$bounds,
    [System.Drawing.Rectangle]$cell,
    [double]$scale
) {
    $width = [Math]::Max(1, [int][Math]::Round($bounds.Width * $scale))
    $height = [Math]::Max(1, [int][Math]::Round($bounds.Height * $scale))
    $x = $cell.X + [int][Math]::Round(($cell.Width - $width) / 2.0)
    $feetY = $cell.Y + 112
    $dest = [System.Drawing.Rectangle]::new($x, $feetY - $height, $width, $height)
    $graphics.DrawImage($source, $dest, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
}

foreach ($entry in $sources.GetEnumerator()) {
    $key = $entry.Key
    $sourcePath = $entry.Value
    if (!(Test-Path -LiteralPath $sourcePath)) { throw "Missing generated atlas: $sourcePath" }
    $characterDir = Join-Path $outputRoot $key
    New-Item -ItemType Directory -Force -Path $characterDir | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $characterDir 'source-atlas.png') -Force

    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    $bounds = New-Object System.Collections.Generic.List[System.Drawing.Rectangle]
    for ($i = 0; $i -lt 7; $i += 1) {
        $column = $i % 4; $row = [Math]::Floor($i / 4)
        $x0 = [int][Math]::Round($column * $source.Width / 4.0)
        $x1 = [int][Math]::Round(($column + 1) * $source.Width / 4.0)
        $y0 = [int][Math]::Round($row * $source.Height / 2.0)
        $y1 = [int][Math]::Round(($row + 1) * $source.Height / 2.0)
        $cell = [System.Drawing.Rectangle]::new($x0, $y0, $x1 - $x0, $y1 - $y0)
        $box = Get-AlphaBounds $source $cell
        if ($null -eq $box) { throw "Empty frame $i in $key" }
        $bounds.Add($box)
    }
    $maxHeight = ($bounds | Measure-Object -Property Height -Maximum).Maximum
    $maxWidth = ($bounds | Measure-Object -Property Width -Maximum).Maximum
    $scale = [Math]::Min(88.0 / $maxHeight, 100.0 / $maxWidth)

    $idle = New-Object System.Drawing.Bitmap 128, 128
    $idleG = [System.Drawing.Graphics]::FromImage($idle)
    $idleG.Clear([System.Drawing.Color]::Transparent)
    $idleG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $idleG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    Draw-NormalizedFrame $idleG $source $bounds[0] ([System.Drawing.Rectangle]::new(0, 0, 128, 128)) $scale
    $idleG.Dispose()
    $idle.Save((Join-Path $characterDir 'idle-transparent.png'), [System.Drawing.Imaging.ImageFormat]::Png)

    $sheet = New-Object System.Drawing.Bitmap 384, 256
    $sheetG = [System.Drawing.Graphics]::FromImage($sheet)
    $sheetG.Clear([System.Drawing.Color]::Transparent)
    $sheetG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $sheetG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    for ($i = 0; $i -lt 6; $i += 1) {
        $cell = [System.Drawing.Rectangle]::new(($i % 3) * 128, [Math]::Floor($i / 3) * 128, 128, 128)
        Draw-NormalizedFrame $sheetG $source $bounds[$i + 1] $cell $scale
    }
    $sheetG.Dispose()
    $sheet.Save((Join-Path $characterDir 'sheet-transparent.png'), [System.Drawing.Imaging.ImageFormat]::Png)

    # Dialogue art is derived from the standing frame, so dialogue can never show a running pose.
    $idleBounds = Get-AlphaBounds $idle ([System.Drawing.Rectangle]::new(0, 0, 128, 128))
    $upperHeight = [Math]::Min($idleBounds.Height, [int][Math]::Ceiling($idleBounds.Height * 0.72))
    $upper = [System.Drawing.Rectangle]::new($idleBounds.X, $idleBounds.Y, $idleBounds.Width, $upperHeight)
    $portrait = New-Object System.Drawing.Bitmap 512, 512
    $portraitG = [System.Drawing.Graphics]::FromImage($portrait)
    $portraitG.Clear([System.Drawing.Color]::Transparent)
    $portraitG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $portraitG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $portraitScale = [Math]::Min(430.0 / $upper.Width, 480.0 / $upper.Height)
    $portraitW = [int][Math]::Round($upper.Width * $portraitScale)
    $portraitH = [int][Math]::Round($upper.Height * $portraitScale)
    $portraitDest = [System.Drawing.Rectangle]::new([int][Math]::Round((512 - $portraitW) / 2.0), 512 - $portraitH, $portraitW, $portraitH)
    $portraitG.DrawImage($idle, $portraitDest, $upper, [System.Drawing.GraphicsUnit]::Pixel)
    $portraitG.Dispose()
    $portrait.Save((Join-Path $characterDir 'portrait.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $portrait.Dispose(); $sheet.Dispose(); $idle.Dispose(); $source.Dispose()
    Write-Output "$key integrated"
}
