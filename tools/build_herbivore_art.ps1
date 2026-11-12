$ErrorActionPreference = 'Stop'
$assetRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../assets/units'))
$encoding = New-Object Text.UTF8Encoding($false)
# Top-down, right-facing SVG parts with natural bodies and shaded wave-colored
# fur, ears, manes and shell plates. Separate heads retain smooth aim animation.
$animals = [ordered]@{
    scout = @(
@'
<path d="M13 18Q8 14 10 10Q17 7 23 14L27 20M13 46Q8 50 10 54Q17 57 23 50L27 44" fill="#87969b" stroke="#24343c" stroke-width="2"/>
<path d="M30 19L36 15Q43 15 42 20L37 25M30 45L36 49Q43 49 42 44L37 39" fill="#aebbbd" stroke="#24343c" stroke-width="2"/>
<path d="M9 25L5 24L3 28L5 31L3 35L6 39L10 38L13 32Z" fill="#f2f5e9" stroke="#34444a" stroke-width="2"/>
<path d="M10 23Q14 12 26 14Q38 15 40 28L40 36Q38 49 26 50Q14 52 10 41Q6 33 10 23Z" fill="#b9c5c7" stroke="#24343c" stroke-width="2"/>
<path d="M12 24Q17 14 27 17Q33 18 35 24Q25 20 17 27L14 36L10 33Z" fill="#edf2e8"/>
<path d="M11 37Q20 46 29 42L37 35Q36 46 27 48Q17 49 12 42Z" fill="#8e9da4"/>
<path d="M15 23L18 20M20 19L24 18M15 41L18 44" stroke="#dce5df" stroke-width="2" stroke-linecap="round"/>
'@,
@'
<path d="M34 26Q29 22 24 13Q19 5 23 3Q30 1 35 11L41 24Z" fill="#d4dfdc" stroke="#24343c" stroke-width="2"/>
<path d="M34 38Q29 42 24 51Q19 59 23 61Q30 63 35 53L41 40Z" fill="#d4dfdc" stroke="#24343c" stroke-width="2"/>
<path d="M25 7Q30 10 35 22L32 21Q26 15 25 7M25 57Q30 54 35 42L32 43Q26 49 25 57" fill="#82959c"/>
<path d="M31 25Q35 20 43 22Q50 23 53 29L58 32L53 35Q50 41 43 42Q35 44 31 39L33 35L30 32L33 29Z" fill="#c5d1cd" stroke="#24343c" stroke-width="2"/>
<path d="M34 26Q41 20 47 26L45 30L37 29Z" fill="#f2f5e9"/>
<path d="M34 38Q41 44 47 38L45 34L37 35Z" fill="#9cacae"/>
<path d="M48 29Q55 26 57 32Q55 38 48 35L46 32Z" fill="#e5ece2"/>
<path d="M55 30L59 32L55 34Z" fill="#34444a"/>
<ellipse cx="45" cy="26" rx="3" ry="2.8" fill="#24343c"/><ellipse cx="45" cy="38" rx="3" ry="2.8" fill="#24343c"/>
<path d="M44 24H46V26H44ZM44 36H46V38H44Z" fill="#ffffff"/>
'@
    )
    heavy = @(
@'
<path d="M10 20L8 14Q12 10 18 13L23 20M10 44L8 50Q12 54 18 51L23 44M34 18L36 12L43 13L45 20M34 46L36 52L43 51L45 44" fill="#63777f" stroke="#1e3039" stroke-width="2"/>
<path d="M9 15L15 15M9 49L15 49M38 14L42 14M38 50L42 50" stroke="#c8d3d0" stroke-width="2"/>
<path d="M9 31L3 29L2 33L10 35" fill="#758990" stroke="#1e3039" stroke-width="2"/>
<path d="M7 25Q9 13 22 12L36 14Q48 17 48 31Q49 44 37 49L22 52Q9 51 7 39Z" fill="#657982" stroke="#1e3039" stroke-width="2"/>
<path d="M16 14Q22 11 30 13L33 20L32 44L28 51Q20 53 15 48L18 39L19 24Z" fill="#e2e9df"/>
<path d="M17 43L26 46L31 41L28 50Q20 53 15 48Z" fill="#aebfbd"/>
<path d="M10 24Q11 16 17 16L19 24L17 29L10 31ZM32 17Q40 18 43 25L37 27L32 23Z" fill="#aebfc2"/>
<path d="M9 39Q11 48 18 49L18 43ZM33 41Q43 41 46 34Q47 44 36 47Z" fill="#435b67"/>
'@,
@'
<path d="M34 24Q27 18 30 12Q35 9 40 18L41 24M34 40Q27 46 30 52Q35 55 40 46L41 40" fill="#a8b9bc" stroke="#1e3039" stroke-width="2"/>
<path d="M33 16L36 20L33 21ZM33 48L36 44L33 43Z" fill="#405661"/>
<path d="M32 25Q36 19 43 22Q50 24 52 28L58 28Q64 32 59 39L55 42L51 39L54 34L48 36Q41 45 34 40Z" fill="#899da6" stroke="#1e3039" stroke-width="2"/>
<path d="M34 26Q39 21 45 26L50 30L45 32L38 28Z" fill="#cad7d5"/>
<path d="M35 38Q42 42 48 35L53 33L55 36L51 40Q42 46 35 40Z" fill="#526d7b"/>
<path d="M52 29Q58 27 60 32L57 36L54 34L56 32Z" fill="#b3c5c8"/>
<ellipse cx="45" cy="27" rx="2.5" ry="2" fill="#172c37"/><ellipse cx="45" cy="38" rx="2.5" ry="2" fill="#172c37"/>
<path d="M44 26H46V27H44M44 37H46V38H44" stroke="#ffffff" stroke-width="1.5"/>
<path d="M56 37L58 38" stroke="#263f4d" stroke-width="2"/>
'@
    )
    runner = @(
@'
<path d="M12 24L18 14L23 12L25 16L20 22M12 40L18 50L23 52L25 48L20 42M31 23L38 16L45 16L45 20L39 21M31 41L38 48L45 48L45 44L39 43" fill="#a9b9b8" stroke="#243640" stroke-width="2"/>
<path d="M19 13L24 14M19 51L24 50M41 16V20M41 44V48" stroke="#314653" stroke-width="3"/>
<path d="M11 31L4 25L2 28L7 34L12 35Z" fill="#e2e8db" stroke="#243640" stroke-width="2"/>
<path d="M9 27Q12 19 25 20L36 23L41 30L39 38Q32 45 18 43Q7 40 9 27Z" fill="#bdc9c5" stroke="#243640" stroke-width="2"/>
<path d="M12 26Q22 19 33 25L29 28L16 28L13 32Z" fill="#edf0df"/>
<path d="M11 35Q21 40 34 34L38 32L36 39Q25 45 14 40Z" fill="#7c9299"/>
<path d="M12 32Q24 35 34 30L34 33Q23 39 12 35Z" fill="#405964"/>
<path d="M14 38L18 40L23 40" fill="none" stroke="#d2dcd4" stroke-width="2"/>
'@,
@'
<path d="M39 26Q33 21 27 12L18 7L22 5Q31 7 35 14L44 25M39 38Q33 43 27 52L18 57L22 59Q31 57 35 50L44 39" fill="#e2e6d3" stroke="#293f48" stroke-width="2"/>
<path d="M29 14L33 12M32 19L37 17M29 50L33 52M32 45L37 47" stroke="#7f9294" stroke-width="2"/>
<path d="M35 26L27 23L25 17Q34 16 40 24M35 38L27 41L25 47Q34 48 40 40" fill="#c2ceca" stroke="#293f48" stroke-width="2"/>
<path d="M34 27L43 23L49 26L59 31L59 34L48 39L42 41L34 37Z" fill="#bdcbc8" stroke="#243640" stroke-width="2"/>
<path d="M38 26L43 25L55 31L49 32L40 30Z" fill="#f1f3e5"/>
<path d="M38 38L43 39L54 34L47 33L40 35Z" fill="#748c96"/>
<path d="M47 26L51 28L46 31L43 29ZM47 38L51 36L46 33L43 35Z" fill="#2b414e"/>
<path d="M45 27H47V28H45M45 36H47V37H45" stroke="#ffffff"/>
<path d="M55 30L60 31V34L55 35Z" fill="#354d59"/>
'@
    )
    skirmisher = @(
@'
<path d="M12 23L13 15L21 13L24 18L20 24M12 41L13 49L21 51L24 46L20 40M33 21L40 14L46 15L45 20L40 24M33 43L40 50L46 49L45 44L40 40" fill="#98abae" stroke="#263b45" stroke-width="2"/>
<path d="M14 14L19 14M14 50L19 50M42 15V19M42 45V49" stroke="#344c59" stroke-width="3"/>
<path d="M10 30L4 24L2 27L5 35L11 36Z" fill="#edf1df" stroke="#263b45" stroke-width="2"/>
<path d="M8 25Q13 15 27 17Q38 19 42 28L41 37Q36 47 23 48Q11 47 8 39Z" fill="#aebfbe" stroke="#263b45" stroke-width="2"/>
<path d="M11 25Q19 17 29 21L35 27L26 25L18 28L12 32Z" fill="#e2e9da"/>
<path d="M11 38Q24 45 37 34L39 39Q32 47 22 46L13 43Z" fill="#748e96"/>
<path d="M15 26H18V29H15ZM21 22H24V25H21ZM27 26H30V29H27ZM17 34H20V37H17ZM24 32H27V35H24Z" fill="#f4f3df"/>
'@,
@'
<path d="M39 25L30 18L24 8L19 3M30 18L17 17L11 12M25 10L32 6M23 17L20 9M39 39L30 46L24 56L19 61M30 46L17 47L11 52M25 54L32 58M23 47L20 55" fill="none" stroke="#293c46" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M39 25L30 18L24 8L19 3M30 18L17 17L11 12M25 10L32 6M23 17L20 9M39 39L30 46L24 56L19 61M30 46L17 47L11 52M25 54L32 58M23 47L20 55" fill="none" stroke="#e1e6cf" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M37 25Q27 24 28 19Q35 16 42 23M37 39Q27 40 28 45Q35 48 42 41" fill="#c8d4cb" stroke="#293c46" stroke-width="2"/>
<path d="M34 27L43 22Q50 23 53 28L60 32L53 36Q50 41 43 42L34 37Z" fill="#c4d1c8" stroke="#263b45" stroke-width="2"/>
<path d="M38 26L44 24L51 29L46 31L39 29Z" fill="#f0f3e0"/>
<path d="M37 37L43 40L51 36L46 34Z" fill="#7f989e"/>
<path d="M49 29L57 30L59 32L57 34L49 35L46 32Z" fill="#e2e9da"/>
<ellipse cx="46" cy="27" rx="2.7" ry="2" fill="#253d49"/><ellipse cx="46" cy="37" rx="2.7" ry="2" fill="#253d49"/>
<path d="M45 26H47M45 36H47" stroke="#ffffff" stroke-width="1.5"/><path d="M57 30L61 32L57 34Z" fill="#344b57"/>
'@
    )
    bulwark = @(
@'
<path d="M10 22L11 12L20 10L25 17L21 24M10 42L11 52L20 54L25 47L21 40M32 19L35 9L44 11L46 22M32 45L35 55L44 53L46 42" fill="#82979c" stroke="#213741" stroke-width="2"/>
<path d="M12 13L20 12M12 51L20 52M37 11L44 13M37 53L44 51" stroke="#c6d3cd" stroke-width="3"/>
<path d="M9 30L3 27L2 31L7 34L2 38L5 41L11 35Z" fill="#8ba0a4" stroke="#213741" stroke-width="2"/>
<path d="M7 24Q12 14 24 15L33 18L42 26L43 39L33 48L22 50Q10 49 7 40Z" fill="#9db1b4" stroke="#213741" stroke-width="2"/>
<path d="M11 24Q17 17 25 19L33 25L27 29L16 27L10 32Z" fill="#c9d7d1"/>
<path d="M26 13L31 8L35 11L40 8L44 12L49 11L52 17L54 24L52 32L54 40L51 48L46 53L41 52L37 56L32 53L27 55L23 48L25 43L22 38L24 31L22 25L25 21Z" fill="#657f89" stroke="#213741" stroke-width="2"/>
<path d="M28 18L32 13L35 16L40 13L44 17L48 16L49 23L44 22L42 26L36 22L32 26L26 23Z" fill="#a5bdc0"/>
<path d="M26 35L30 38L28 44L33 42L35 48L39 45L44 49L48 44L48 50L42 52L37 54L32 51L28 52L25 46Z" fill="#405e6b"/>
<path d="M28 27L31 30L29 33M36 28L39 31L37 34M45 30L48 33L46 37" fill="none" stroke="#88a2ab" stroke-width="2" stroke-linecap="round"/>
'@,
@'
<path d="M41 25Q30 25 27 15L28 6L32 11Q33 18 44 19M41 39Q30 39 27 49L28 58L32 53Q33 46 44 45" fill="#dce5cf" stroke="#243a43" stroke-width="2"/>
<path d="M29 12Q29 21 39 23M29 52Q29 43 39 41" fill="none" stroke="#f7f7e8" stroke-width="2"/>
<path d="M34 25L38 20L43 22L48 20L52 25L54 32L52 39L48 44L43 42L38 44L34 39L36 35L33 32L36 29Z" fill="#809ba4" stroke="#213741" stroke-width="2"/>
<path d="M37 25L40 23L43 26L47 24L50 28L43 30L37 29Z" fill="#c4d5d3"/>
<path d="M37 37L43 36L50 37L48 41L43 40L39 42Z" fill="#506f7d"/>
<path d="M48 27Q57 25 60 30V34Q57 39 48 37L45 32Z" fill="#b6cac9" stroke="#2e4b59" stroke-width="2"/>
<path d="M49 28L57 28L59 31L48 31Z" fill="#e0e9da"/>
<path d="M53 30V32M57 32V34" stroke="#3a5865" stroke-width="2"/>
<path d="M41 25L46 26L44 29L41 28ZM41 39L46 38L44 35L41 36Z" fill="#193440"/>
<path d="M42 26H44M42 37H44" stroke="#ffffff" stroke-width="1.5"/>
'@
    )
    siege = @(
@'
<path d="M10 19L11 10Q16 7 22 12L24 20M10 45L11 54Q16 57 22 52L24 44M33 16L37 8L45 10L47 20M33 48L37 56L45 54L47 44" fill="#8199a4" stroke="#233c49" stroke-width="2"/>
<path d="M12 12L19 12M12 52L19 52M38 11L44 13M38 53L44 51" stroke="#d5e2de" stroke-width="3"/>
<path d="M8 30L3 24L2 26L4 33L10 36" fill="#a5bdc1" stroke="#233c49" stroke-width="2"/>
<path d="M6 23Q10 10 25 10Q41 10 47 24L49 36Q43 52 28 54Q11 55 6 42Q2 32 6 23Z" fill="#a6bec3" stroke="#233c49" stroke-width="2"/>
<path d="M9 23Q13 13 25 13Q34 13 40 21L35 24L24 20L14 26L9 33Z" fill="#d9e5df"/>
<path d="M8 38Q18 48 31 43L43 33L46 37Q42 50 28 52Q14 53 8 44Z" fill="#748f9d"/>
<path d="M12 30L15 26M14 39L17 43M22 17L27 16M22 48L28 48" fill="none" stroke="#8ba6af" stroke-width="2" stroke-linecap="round"/>
'@,
@'
<path d="M40 27Q28 28 25 20L23 11Q24 3 31 4L39 7L45 16L44 25M40 37Q28 36 25 44L23 53Q24 61 31 60L39 57L45 48L44 39" fill="#a8c0c6" stroke="#233c49" stroke-width="2"/>
<path d="M28 9Q32 5 37 12L41 21L35 23L29 18Z" fill="#dfebe4"/>
<path d="M28 55Q32 59 37 52L41 43L35 41L29 46Z" fill="#809fab"/>
<path d="M28 12L31 19L37 23M28 52L31 45L37 41" fill="none" stroke="#7c9ba8" stroke-width="2"/>
<path d="M39 24Q34 17 40 13Q48 12 52 23L53 30L52 41Q48 52 40 51Q34 47 39 40Z" fill="#a7c0c4" stroke="#233c49" stroke-width="2"/>
<path d="M40 19Q45 14 48 22L48 28L42 29Z" fill="#e2ebe2"/>
<path d="M39 42L45 39L50 41Q47 50 41 48Z" fill="#7795a2"/>
<path d="M48 23Q56 18 59 20Q61 25 54 28L50 28M48 41Q56 46 59 44Q61 39 54 36L50 36" fill="#f7f1dc" stroke="#526d75" stroke-width="1.5"/>
<path d="M47 27Q53 25 57 29Q61 34 58 40L55 45L50 45L48 42L52 38L53 33L48 35Z" fill="#bad0d0" stroke="#2b4857" stroke-width="2"/>
<path d="M50 28Q56 27 57 32L55 36L53 35L54 31Z" fill="#e1eae0"/>
<path d="M51 38L55 40M50 41L53 43" stroke="#7e9ca6" stroke-width="2"/>
<ellipse cx="47" cy="23" rx="2.5" ry="2" fill="#203b49"/><ellipse cx="47" cy="41" rx="2.5" ry="2" fill="#203b49"/>
<path d="M46 22H48M46 40H48" stroke="#ffffff" stroke-width="1.5"/>
'@
    )
    mender = @(
@'
<path d="M12 22L7 15L10 10L17 12L23 21M12 42L7 49L10 54L17 52L23 43M36 20L43 11L49 14L46 23M36 44L43 53L49 50L46 41" fill="#a9bdb3" stroke="#243f43" stroke-width="2"/>
<path d="M10 14L13 15M10 50L13 49M44 14L46 17M44 50L46 47" stroke="#e0e9d9" stroke-width="2"/>
<path d="M10 30L3 32L10 36Z" fill="#c8d5bd" stroke="#243f43" stroke-width="2"/>
<path d="M7 24Q10 10 27 9Q43 9 49 23L50 39Q44 54 27 55Q10 54 7 40Z" fill="#667e7c" stroke="#243f43" stroke-width="2"/>
<path d="M10 25Q14 13 27 12Q40 13 46 25L47 38Q41 51 27 52Q13 51 10 39Z" fill="#b9cdb7"/>
<path d="M14 23L25 17L37 21L42 32L36 43L23 46L13 37Z" fill="#829f97" stroke="#3c595b" stroke-width="2"/>
<path d="M25 17L25 29L14 23M25 29L23 46M25 29L42 32M25 29L37 21" fill="none" stroke="#3c595b" stroke-width="2.5"/>
<path d="M17 23L23 20L23 26L18 28ZM28 20L34 22L29 26L27 25ZM28 33L37 34L34 39L27 41ZM16 32L21 31L20 40L16 36Z" fill="#c8dbc4"/>
<path d="M14 18L12 24M21 14L25 12M36 15L40 18M46 27L47 32M43 43L39 47M28 51L23 50M13 43L11 38" stroke="#6c8a83" stroke-width="2"/>
<path d="M16 18L21 16L23 17" fill="none" stroke="#edf1de" stroke-width="2" stroke-linecap="round"/>
'@,
@'
<path d="M43 26Q48 23 54 25L59 28L61 32L59 36L54 39Q48 41 43 38Z" fill="#bdcdb6" stroke="#284446" stroke-width="2"/>
<path d="M45 27L52 26L57 29L53 31L46 30Z" fill="#edf0da"/>
<path d="M45 36L51 37L57 34L57 37L52 39L46 38Z" fill="#819e92"/>
<ellipse cx="54" cy="27" rx="2.3" ry="1.8" fill="#203d42"/><ellipse cx="54" cy="37" rx="2.3" ry="1.8" fill="#203d42"/>
<path d="M53 26H55M53 36H55" stroke="#ffffff" stroke-width="1.3"/>
<path d="M58 30L61 32L58 34" fill="none" stroke="#78978b" stroke-width="2"/>
'@
    )
}

$header = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
foreach ($kind in $animals.Keys) {
        $body = $animals[$kind][0]
    # Warm natural fur, neutral elephant skin, green tortoise shell.
    $hue = switch ($kind) { 'scout' { 35 }; 'heavy' { 220 }; 'runner' { 38 }; 'skirmisher' { 20 }; 'bulwark' { 18 }; 'siege' { 210 }; 'mender' { 96 } }
    $saturation = switch ($kind) { 'scout' { .32 }; 'heavy' { .12 }; 'runner' { .58 }; 'skirmisher' { .52 }; 'bulwark' { .42 }; 'siege' { .20 }; 'mender' { .48 } }
        $head = $animals[$kind][1]
    foreach ($part in @('body', 'head')) {
        $value = Get-Variable -Name $part -ValueOnly
        $value = [regex]::Replace($value, '#[0-9a-fA-F]{6}', {
            param($match)
            $hex = $match.Value
            $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
            $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
            $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
            $lightness = ($r + $g + $b) / 765.0
                        if ($lightness -lt .30 -or $lightness -gt .90) { return $hex }
            $naturalShade = switch ($kind) { 'scout' { .92 }; 'heavy' { .62 }; 'runner' { .88 }; 'skirmisher' { .84 }; 'bulwark' { .60 }; 'siege' { .85 }; 'mender' { .82 } }
            if ($kind -eq 'heavy' -and $lightness -gt .78) { $naturalShade = 1.0 }
            $lightness *= $naturalShade
            $sat = $saturation
            if ($lightness -gt .78) { $sat *= .5 }
            $chroma = (1 - [Math]::Abs(2 * $lightness - 1)) * $sat
            $segment = $hue / 60.0
            $secondary = $chroma * (1 - [Math]::Abs($segment % 2 - 1))
            $rgb = if ($segment -lt 1) { @($chroma,$secondary,0) } elseif ($segment -lt 2) { @($secondary,$chroma,0) } elseif ($segment -lt 3) { @(0,$chroma,$secondary) } elseif ($segment -lt 4) { @(0,$secondary,$chroma) } elseif ($segment -lt 5) { @($secondary,0,$chroma) } else { @($chroma,0,$secondary) }
            $offset = $lightness - $chroma / 2
            return '#{0:x2}{1:x2}{2:x2}' -f [int](($rgb[0]+$offset)*255),[int](($rgb[1]+$offset)*255),[int](($rgb[2]+$offset)*255)
        })
        Set-Variable -Name $part -Value $value
    }
    $bodyMark = switch ($kind) {
        'scout' { '<path d="M13 25Q18 16 27 18Q33 20 34 29L32 37Q28 44 19 43L14 39L16 32Z" fill="#d8d8d8"/><path d="M14 25Q21 17 28 20L31 24Q23 22 17 29Z" fill="#ffffff"/><path d="M15 37Q23 42 31 35L30 40Q23 46 17 41Z" fill="#929292"/>' }
        'heavy' { '<path d="M16 14Q22 11 30 13L33 20L32 44L28 51Q20 53 15 48L18 39L19 24Z" fill="#dddddd"/><path d="M17 16Q23 13 29 15L31 21L27 24L20 21Z" fill="#ffffff"/><path d="M17 43L26 46L31 41L28 50Q20 53 15 48Z" fill="#929292"/>' }
        'runner' { '<path d="M12 27Q23 20 34 26L36 31Q25 30 13 35ZM13 36Q24 40 36 33L36 38Q25 45 14 40Z" fill="#d4d4d4"/><path d="M14 26Q25 22 33 27L30 29Q21 26 15 30Z" fill="#ffffff"/><path d="M14 38Q25 42 35 36L34 40Q24 44 15 40Z" fill="#8f8f8f"/>' }
        'skirmisher' { '<path d="M11 35Q23 42 37 32L38 39Q32 47 22 46L13 43Z" fill="#d8d8d8"/><path d="M12 35Q25 39 36 32L36 35Q25 43 14 39Z" fill="#ffffff"/><path d="M14 41Q26 46 36 38L34 42Q24 48 15 44Z" fill="#929292"/>' }
        'bulwark' { '<path d="M26 13L31 8L35 11L40 8L44 12L49 11L52 17L54 24L52 32L54 40L51 48L46 53L41 52L37 56L32 53L27 55L23 48L25 43L22 38L24 31L22 25L25 21Z" fill="#c5c5c5"/><path d="M28 18L32 13L35 16L40 13L44 17L48 16L49 23L44 22L42 26L36 22L32 26L26 23Z" fill="#f2f2f2"/><path d="M26 35L30 38L28 44L33 42L35 48L39 45L44 49L48 44L48 50L42 52L37 54L32 51L28 52L25 46Z" fill="#777777"/>' }
        'siege' { '<path d="M8 38Q18 48 31 43L43 33L46 37Q42 50 28 52Q14 53 8 44Z" fill="#bcbcbc"/><path d="M10 38Q20 46 31 40L41 33L42 36Q27 51 12 43Z" fill="#e3e3e3"/><path d="M13 46Q28 53 42 42L38 48Q23 55 14 50Z" fill="#888888"/>' }
        'mender' { '<path d="M14 23L25 17L37 21L42 32L36 43L23 46L13 37Z" fill="#c8c8c8" stroke="#747474" stroke-width="2"/><path d="M17 23L23 20L23 26L18 28ZM28 20L34 22L29 26L27 25ZM28 33L37 34L34 39L27 41ZM16 32L21 31L20 40L16 36Z" fill="#f2f2f2"/><path d="M25 17L25 29L14 23M25 29L23 46M25 29L42 32M25 29L37 21" fill="none" stroke="#737373" stroke-width="2.5"/>' }
    }
    $headMark = switch ($kind) {
        'scout' { '<path d="M25 7Q30 10 35 22L32 21Q26 15 25 7M25 57Q30 54 35 42L32 43Q26 49 25 57" fill="#dedede"/><path d="M26 9L29 11L33 19L31 18ZM26 55L29 53L33 45L31 46Z" fill="#ffffff"/>' }
        'runner' { '<path d="M28 20Q34 19 39 24L36 26L30 24ZM28 44Q34 45 39 40L36 38L30 40Z" fill="#dddddd"/>' }
        'skirmisher' { '<path d="M39 25L30 18L24 8L19 3M30 18L17 17L11 12M25 10L32 6M23 17L20 9M39 39L30 46L24 56L19 61M30 46L17 47L11 52M25 54L32 58M23 47L20 55" fill="none" stroke="#eeeeee" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>' }
        'siege' { '<path d="M40 27Q28 28 25 20L23 11Q24 3 31 4L39 7L45 16L44 25M40 37Q28 36 25 44L23 53Q24 61 31 60L39 57L45 48L44 39" fill="#cccccc"/><path d="M28 9Q32 5 37 12L41 21L35 23L29 18Z" fill="#ffffff"/><path d="M28 55Q32 59 37 52L41 43L35 41L29 46Z" fill="#929292"/><path d="M28 12L31 19L37 23M28 52L31 45L37 41" fill="none" stroke="#999999" stroke-width="2"/>' }
        default { '' }
    }
    [IO.File]::WriteAllText((Join-Path $assetRoot "${kind}_body_accent.svg"), "$header`n$bodyMark`n</svg>`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $assetRoot "${kind}_gun_accent.svg"), "$header`n$headMark`n</svg>`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $assetRoot "${kind}_accent.svg"), "$header`n$bodyMark`n$headMark`n</svg>`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $assetRoot "$kind.svg"), "$header`n$body`n$head`n</svg>`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $assetRoot "${kind}_body.svg"), "$header`n$body`n</svg>`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $assetRoot "${kind}_gun.svg"), "$header`n$head`n</svg>`n", $encoding)
}
& (Join-Path $PSScriptRoot 'build_squirrel_horse.ps1')
