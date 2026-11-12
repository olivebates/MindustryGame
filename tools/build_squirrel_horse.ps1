$ErrorActionPreference = 'Stop'
$assetRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../assets/units'))
$encoding = New-Object Text.UTF8Encoding($false)
# Called after the original herbivores are generated: preserve the gazelle,
# move the rabbit to Bunny's save-compatible runner ID, then replace scout.
foreach ($suffix in @('', '_body', '_gun', '_accent', '_body_accent', '_gun_accent')) {
    Copy-Item -LiteralPath (Join-Path $assetRoot "runner$suffix.svg") -Destination (Join-Path $assetRoot "gazelle$suffix.svg")
    Copy-Item -LiteralPath (Join-Path $assetRoot "scout$suffix.svg") -Destination (Join-Path $assetRoot "runner$suffix.svg")
}
$animals = @{
scout = @(
@'
<path d="M20 35C-4 46 0 10 12 6C27 1 29 19 17 22C9 24 12 33 22 29" fill="#955a35" stroke="#382d25" stroke-width="2.5"/>
<path d="M13 9C22 5 24 16 16 18C7 19 7 29 11 34" fill="none" stroke="#c48b50" stroke-width="4"/>
<path d="M19 25L19 16L25 15L29 26M19 39L19 48L25 49L29 38M33 25L40 20L44 23L39 29M33 39L40 44L44 41L39 35" fill="#8f5535" stroke="#382d25" stroke-width="2"/>
<ellipse cx="28" cy="32" rx="15" ry="14" fill="#b87d48" stroke="#382d25" stroke-width="2"/>
<path d="M17 29Q23 16 33 22L37 27L29 25L21 31Z" fill="#d5a568"/>
<path d="M18 37Q29 44 40 33L38 41L27 46L20 42Z" fill="#875237"/>
'@,
@'
<path d="M33 25L31 14L37 12L42 24M33 39L31 50L37 52L42 40" fill="#b87d48" stroke="#382d25" stroke-width="2"/>
<path d="M34 25Q43 20 49 27L57 31L57 34L49 37Q42 45 34 39Z" fill="#c99558" stroke="#382d25" stroke-width="2"/>
<path d="M45 29L55 31L55 34L45 36L42 32Z" fill="#e1bd84"/>
<path d="M55 30L59 32L55 35Z" fill="#382d25"/>
<ellipse cx="45" cy="26" rx="3" ry="2.5" fill="#272b25"/><ellipse cx="45" cy="38" rx="3" ry="2.5" fill="#272b25"/>
<path d="M44 24H46V26H44ZM44 36H46V38H44Z" fill="#fff0ce"/>
'@,
'<path d="M20 27Q28 20 35 26L35 32Q30 40 22 38Z" fill="#d3d3d3"/><path d="M21 27Q28 23 33 26L25 30Z" fill="#ffffff"/><path d="M22 35L32 33L30 38L24 38Z" fill="#999999"/>',
'<path d="M33 16L36 15L39 23L36 23ZM33 48L36 49L39 41L36 41Z" fill="#dddddd"/>'
)
horse = @(
@'
<path d="M13 26L10 13L17 11L23 25M13 38L10 51L17 53L23 39M34 24L39 12L46 13L42 27M34 40L39 52L46 51L42 37" fill="#925e40" stroke="#332c2a" stroke-width="2.5"/>
<path d="M10 12L17 11L18 17L11 18ZM10 52L17 53L18 47L11 46ZM40 12L46 13L44 19L38 18ZM40 52L46 51L44 45L38 46Z" fill="#e4ccaa"/>
<path d="M13 29Q2 17 2 29L4 40L8 39L8 32L14 36" fill="#3b302b" stroke="#292726" stroke-width="2"/>
<path d="M10 25Q12 17 25 18L37 21L45 29L43 39Q37 48 22 47Q9 45 10 25Z" fill="#a8714c" stroke="#332c2a" stroke-width="2.5"/>
<path d="M13 26Q24 17 35 24L38 28L27 26L17 31Z" fill="#cf9b6b"/>
<path d="M12 37Q26 44 41 33L40 41Q30 49 17 43Z" fill="#784c37"/>
<path d="M31 23L35 19L39 23L40 28L44 32L40 37L39 41L35 45L31 41Z" fill="#49352c"/>
'@,
@'
<path d="M38 26L34 13L39 10L44 24M38 38L34 51L39 54L44 40" fill="#a8714c" stroke="#332c2a" stroke-width="2"/>
<path d="M34 25L40 21Q47 21 51 28L61 28L62 36L52 37Q47 44 40 43L34 39Z" fill="#bb855b" stroke="#332c2a" stroke-width="2.5"/>
<path d="M43 23L48 25L50 31L59 31L59 34L49 34L45 39L42 36L45 31Z" fill="#e7cba0"/>
<path d="M55 29L61 29L61 36L55 36Z" fill="#705443"/>
<ellipse cx="47" cy="26" rx="2.7" ry="2" fill="#292726"/><ellipse cx="47" cy="38" rx="2.7" ry="2" fill="#292726"/>
<path d="M46 25H48M46 37H48" stroke="#fff1da" stroke-width="1.5"/>
'@,
'<path d="M18 26Q27 21 34 26L37 32L33 39L22 41L17 37Z" fill="#cccccc"/><path d="M20 26L28 24L33 27L24 30Z" fill="#ffffff"/><path d="M20 37L32 34L33 39L24 40Z" fill="#888888"/>',
'<path d="M36 15L39 13L42 24L39 24ZM36 49L39 51L42 40L39 40Z" fill="#dddddd"/>'
)
}
$header='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
foreach ($kind in $animals.Keys) {
    $parts=$animals[$kind]
    $images=@{'_body'=$parts[0];'_gun'=$parts[1];''=($parts[0]+$parts[1]);'_body_accent'=$parts[2];'_gun_accent'=$parts[3];'_accent'=($parts[2]+$parts[3])}
    foreach ($suffix in $images.Keys) { [IO.File]::WriteAllText((Join-Path $assetRoot "$kind$suffix.svg"),$header+$images[$suffix]+'</svg>',$encoding) }
}
