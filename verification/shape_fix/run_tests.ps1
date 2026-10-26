param([string]$VivadoBin = 'D:/vivado/Vivado/2018.3/bin')
$ErrorActionPreference = 'Stop'
$hdl = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../user_source/hdl_source')).Path
$runDir = Join-Path $env:TEMP ('ph1p35_shape_verification_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDir -ErrorAction Stop | Out-Null
Push-Location $runDir
try {
    $sources = @('roi_binary_frame_buffer.v','roi_moment_stats.v','roi_axis_calc.v',
        'roi_rotate_normalize.v','shape_template_match.v','shape_match_fusion.v') |
        ForEach-Object { Join-Path $hdl ('isp/' + $_) }
    $sources += @('hdmi_mixer.v','anlogic_logo_rom.v','osd_char_lib.v') |
        ForEach-Object { Join-Path $hdl $_ }
    $tests = 'shape_pipeline','shape_calibrate','shape_osd'
    $sources += $tests | ForEach-Object { Join-Path $PSScriptRoot ('tb_' + $_ + '.sv') }
    & "$VivadoBin/xvlog.bat" -sv @sources
    if ($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed' }
    foreach ($test in $tests) {
        & "$VivadoBin/xelab.bat" "tb_$test" -s "${test}_sim" -timescale 1ns/1ps
        if ($LASTEXITCODE -ne 0) { throw "Elaboration failed: $test" }
        & "$VivadoBin/xsim.bat" "${test}_sim" -R -log "${test}_result.log"
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
        $log = Get-Content "${test}_result.log" -Raw
        if ($log -match 'Fatal:|FATAL|ERROR:' -or $log -notmatch 'PASS:') {
            throw "Test assertions failed: $test"
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $runDir -Recurse -Force
}
