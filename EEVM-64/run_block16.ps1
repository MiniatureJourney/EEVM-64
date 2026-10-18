$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root 'build'
New-Item -ItemType Directory -Force -Path $Build | Out-Null

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    throw 'Icarus Verilog (iverilog) is not available on PATH.'
}
if (-not (Get-Command vvp -ErrorAction SilentlyContinue)) {
    throw 'Icarus Verilog runtime (vvp) is not available on PATH.'
}

Push-Location $Build
try {
    & iverilog -g2012 -Wall -s tb_array_multiplier_core_small `
        -o (Join-Path $Build 'tb_array_multiplier_core_small.vvp') `
        (Join-Path $Root 'rtl/array_multiplier.sv') `
        (Join-Path $Root 'tb/tb_array_multiplier_core_small.sv')
    if ($LASTEXITCODE -ne 0) { throw 'Core testbench compilation failed.' }
    & vvp (Join-Path $Build 'tb_array_multiplier_core_small.vvp') | Tee-Object -FilePath (Join-Path $Build 'core_small.log')
    if ($LASTEXITCODE -ne 0) { throw 'Core testbench simulation failed.' }
    if (-not (Select-String -Quiet -Path (Join-Path $Build 'core_small.log') -Pattern 'PASS: Block16 array core exhaustive WIDTH=8')) {
        throw 'Core testbench did not report PASS.'
    }

    & iverilog -g2012 -Wall -s tb_array_multiplier `
        -o (Join-Path $Build 'tb_array_multiplier.vvp') `
        (Join-Path $Root 'rtl/array_multiplier.sv') `
        (Join-Path $Root 'tb/tb_array_multiplier.sv')
    if ($LASTEXITCODE -ne 0) { throw 'Top-level testbench compilation failed.' }
    & vvp (Join-Path $Build 'tb_array_multiplier.vvp') | Tee-Object -FilePath (Join-Path $Build 'top_level.log')
    if ($LASTEXITCODE -ne 0) { throw 'Top-level testbench simulation failed.' }
    if (-not (Select-String -Quiet -Path (Join-Path $Build 'top_level.log') -Pattern 'PASS: Block16 array_multiplier')) {
        throw 'Top-level testbench did not report PASS.'
    }
    Write-Host 'Block 16 simulations completed: core_small and top_level PASS.'
}
finally {
    Pop-Location
}
