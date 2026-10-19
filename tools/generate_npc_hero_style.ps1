param(
    [string[]]$Keys = @(
        'flyer_lady','old_artisan','aming','old_shopkeeper','fat_teahouse',
        'helper','laozhou','old_man','tourist','vendor','refugee'
    )
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'assets/production/npc/cast_v2'
$workRoot = Join-Path $projectRoot 'assets/generated/npc_hero_style'
$referenceRoot = Join-Path $workRoot 'references'
$rawRoot = Join-Path $workRoot 'raw'
New-Item -ItemType Directory -Force -Path $referenceRoot, $rawRoot | Out-Null

$descriptions = @{
    flyer_lady = '热情但有些缠人的重庆传单阿姨，花头巾，暗红色上衣，深蓝围裙，布鞋，斜挎小布包'
    old_artisan = '清末民初老工匠，朴素褐色短褂和围裙，敦厚，手上有劳作痕迹'
    aming = '年轻作坊帮工阿明，旧式深色短衫长裤，利落朴实'
    old_shopkeeper = '年长店掌柜，灰白头发，传统深色长衫，沉稳亲切'
    fat_teahouse = '身材敦实的茶馆掌柜，民国短褂与布裤，和气但精明'
    helper = '年轻搬运帮工，粗布短打，袖口卷起，结实勤快'
    laozhou = '水乡渔夫老周，蓑衣感旧衣与深色布裤，风吹日晒的面容'
    old_man = '重庆老者，灰发，朴素中式衣裤，温和清醒'
    tourist = '现代重庆游客，轻便外套、长裤和小背包，日常自然'
    vendor = '重庆街头摊贩，围裙和便装，亲切利落'
    refugee = '抗战时期重庆避难市民，朴素旧衣，背着轻便包袱，疲惫但坚韧'
}

function Draw-ImageContain([System.Drawing.Graphics]$graphics, [System.Drawing.Image]$image, [System.Drawing.Rectangle]$box) {
    $scale = [Math]::Min($box.Width / $image.Width, $box.Height / $image.Height)
    $w = [int]($image.Width * $scale)
    $h = [int]($image.Height * $scale)
    $x = $box.X + [int](($box.Width - $w) / 2)
    $y = $box.Y + $box.Height - $h
    $graphics.DrawImage($image, $x, $y, $w, $h)
}

foreach ($key in $Keys) {
    $npcDir = Join-Path $sourceRoot $key
    $idlePath = Join-Path $npcDir 'idle-transparent.png'
    $sheetPath = Join-Path $npcDir 'sheet-transparent.png'
    if (!(Test-Path -LiteralPath $idlePath) -or !(Test-Path -LiteralPath $sheetPath)) {
        Write-Warning "Skip ${key}: source sprite missing"
        continue
    }

    # 4x2 source atlas: cell 0 is idle, cells 1-6 are the original walk cycle.
    # The lower half is reserved for a style reference and palette notes.
    $canvas = New-Object System.Drawing.Bitmap 1024, 1024
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.Clear([System.Drawing.Color]::Magenta)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $idle = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $idlePath))
    $sheet = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $sheetPath))
    Draw-ImageContain $g $idle ([System.Drawing.Rectangle]::new(0, 0, 256, 256))
    for ($i = 0; $i -lt 6; $i++) {
        $sx = ($i % 3) * 256
        $sy = [Math]::Floor($i / 3) * 256
        $dx = (($i + 1) % 4) * 256
        $dy = [Math]::Floor(($i + 1) / 4) * 256
        $src = [System.Drawing.Rectangle]::new($sx, $sy, 256, 256)
        $dst = [System.Drawing.Rectangle]::new($dx, $dy, 256, 256)
        $g.DrawImage($sheet, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $heroPath = Join-Path $projectRoot 'assets/production/hero/idle/idle-1.png'
    $hero = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $heroPath))
    Draw-ImageContain $g $hero ([System.Drawing.Rectangle]::new(384, 560, 256, 384))
    $hero.Dispose(); $idle.Dispose(); $sheet.Dispose(); $g.Dispose()

    $referencePath = Join-Path $referenceRoot ($key + '-reference.png')
    $canvas.Save($referencePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose()

    $description = $descriptions[$key]
    $prompt = @"
将参考图上半部的 NPC 精灵重新绘制为与参考图下半部男主角完全统一的 2D 像素游戏画风。角色身份：$description。

严格输出一个 1024x1024 像素精灵图集：纯洋红色 #FF00FF 背景；上半部为严格 4列x2行、每格256x256 的网格，下半部保持纯洋红色空白。第1格是自然站立待机，随后6格是同一角色向右行走的一整套连续循环帧，第8格留空。所有帧必须是同一个角色、同一服装、同一画风、同一身高、同一脚底线、同一身体中心，完整全身，不裁切，不触边，不加文字、框线、阴影地面或道具。

画风必须跟男主一致：重庆题材横版叙事游戏，清晰低分辨率像素块，克制的深棕轮廓，简化但自然的五官，约1:5.5成年人体比例，头部不可夸张，非大头Q版，非动漫立绘，非写实油画；颜色偏暖且低饱和，阴影只用少量色阶，边缘锐利无抗锯齿。角色视觉高度约占每格68%，脚底位于每格下方约88%处。行走动作自然连贯：接触、下沉、经过、抬起、反向接触、反向经过，手臂与腿交替摆动。必须保留参考 NPC 的年龄、体型、发型、衣着和重庆地域特征，但像素密度、描边粗细、头身比例必须以男主为唯一标准。
"@

    $outputPath = Join-Path $rawRoot ($key + '-atlas.png')
    Write-Output "Generating $key -> $outputPath"
    & node 'C:/Users/Administrator/.codex/imagegen.js' $prompt --out $outputPath --size 1024x1024 --image $referencePath
    if ($LASTEXITCODE -ne 0) { throw "Image generation failed for $key" }
}
