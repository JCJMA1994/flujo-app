Add-Type -AssemblyName System.Drawing
$srcPath = "C:\Users\jcjma\.gemini\antigravity-ide\brain\ca9c0e14-ca30-4363-8a71-03b76597e142\flujo_app_icon_1788366917231.jpg"
$img = [System.Drawing.Image]::FromFile($srcPath)

$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($folder in $sizes.Keys) {
    $dim = $sizes[$folder]
    $destDir = "android/app/src/main/res/$folder"
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $destPath = "$destDir/ic_launcher.png"
    
    $bmp = New-Object System.Drawing.Bitmap($dim, $dim)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $dim, $dim)
    $g.Dispose()
    
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated $destPath ($dim x $dim)"
}
$img.Dispose()
