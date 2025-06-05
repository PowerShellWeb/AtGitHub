#requires -Module PSSVG
$AssetsPath = $PSScriptRoot | Join-Path -ChildPath "Assets"
if (-not (Test-Path $AssetsPath)) {
    New-Item -ItemType Directory -Path $AssetsPath | Out-Null
}

if (-not $script:GitHubIcon) {
    $script:GitHubIcon = Invoke-RestMethod -uri 'https://raw.githubusercontent.com/feathericons/feather/refs/heads/main/icons/github.svg'
    $script:GitHubIcon.svg.SetAttribute('stroke', '#4488FF')
    $script:GitHubIcon.svg.SetAttribute('stroke-width', '1.5')
    $script:GitHubIcon.svg.setAttribute('class','foreground-stroke')
    # $svgXml.Save("$psScriptRoot/GitHub.svg")
}

if (-not $script:AtSignIcon) {
    $script:AtSignIcon = Invoke-RestMethod -uri 'https://raw.githubusercontent.com/feathericons/feather/refs/heads/main/icons/at-sign.svg'
    $script:AtSignIcon.svg.SetAttribute('stroke', '#4488FF')
    $script:GitHubIcon.svg.SetAttribute('stroke-width', '1.5')
    $script:AtSignIcon.svg.setAttribute('class','foreground-stroke')
}

$fontName = 'Anta'
$fontName = 'Heebo'
$fontName = 'Noto Sans'
$strokeWidth = '0.5%'
foreach ($variant in '','Animated') { 
    $outputPath = if (-not $variant) {
        Join-Path $assetsPath "AtGitHub.svg"
    } else {
        Join-Path $assetsPath "AtGitHub-$variant.svg"
    }
    svg -content $(
        $fillParameters = [Ordered]@{
            Fill        = '#4488FF'
            Class       = 'foreground-fill'
        }
    
        $strokeParameters = [Ordered]@{
            Stroke      = '#4488FF'
            Class       = 'foreground-stroke'
            StrokeWidth = $strokeWidth
        }
    
        $transparentFill = [Ordered]@{Fill='transparent'}
        $animationDuration = [Ordered]@{
            Dur = "4.2s"
            RepeatCount = "indefinite"
        }
    
        SVG.GoogleFont -FontName $fontName
    
        svg.symbol -Id psChevron -Content @(
            svg.polygon -Points (@(
                "40,20"
                "45,20"
                "60,50"
                "35,80"
                "32.5,80"
                "55,50"
            ) -join ' ') -TransformOrigin '50% 50%'
        ) -ViewBox 100, 100 -TransformOrigin '50% 50%'
    
        SVG.symbol -Id gitHubIcon -Content @(
            $script:GitHubIcon.svg
        ) -ViewBox 24, 24 -TransformOrigin '50% 50%'
        
        SVG.symbol -Id atIcon -Content @(
            $script:AtSignIcon.svg
        ) -ViewBox 24, 24 -TransformOrigin '50% 50%'
        
    
        SVG.circle -CX 50% -Cy 50% -R 42% @transparentFill @strokeParameters -Content @(            
        )
        SVG.ellipse -Cx 50% -Cy 50% -Rx 23% -Ry 42% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '23%;16%;23%' -AttributeName rx @animationDuration
            }
        )
        SVG.ellipse -Cx 50% -Cy 50% -Rx 16% -Ry 42% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '16%;23%;16%' -AttributeName rx @animationDuration
            }
        ) -Opacity .9
        SVG.ellipse -Cx 50% -Cy 50% -Rx 15% -Ry 42% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '15%;16%;15%' -AttributeName rx @animationDuration                
            }
        ) -Opacity .8
        SVG.ellipse -Cx 50% -Cy 50% -Rx 42% -Ry 23% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '23%;16%;23%' -AttributeName ry @animationDuration
            }
        )
        SVG.ellipse -Cx 50% -Cy 50% -Rx 42% -Ry 16% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '16%;23%;16%' -AttributeName ry @animationDuration
            }
        ) -Opacity .9
        SVG.ellipse -Cx 50% -Cy 50% -Rx 42% -Ry 15% @transparentFill @strokeParameters  -Content @(
            if ($variant -match 'animate') {
                svg.animate -Values '15%;16%;15%' -AttributeName ry @animationDuration
            }
        ) -Opacity .8
        
        svg.use -Href '#psChevron' -Y 44% @fillParameters -Height 12%
        svg.use -Href '#atIcon' -Y 44% @strokeParameters -Height 12% -X -6%
        svg.use -Href '#gitHubIcon' -Y 44% @strokeParameters -Height 12% -X 6%
        
    ) -ViewBox 0, 0, 200, 200 -OutputPath $outputPath
}
