#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v iverilog >/dev/null 2>&1 || { echo "ERROR: Icarus Verilog (iverilog) is not installed." >&2; exit 127; }
command -v vvp >/dev/null 2>&1 || { echo "ERROR: vvp is not installed." >&2; exit 127; }
mkdir -p "$ROOT/build"

iverilog -g2012 -Wall -s tb_array_multiplier_core_small \
  -o "$ROOT/build/tb_array_multiplier_core_small.vvp" \
  "$ROOT/rtl/array_multiplier.sv" \
  "$ROOT/tb/tb_array_multiplier_core_small.sv"
(
  cd "$ROOT/build"
  vvp ./tb_array_multiplier_core_small.vvp | tee core_small.log
)

grep -q "PASS: Block16 array core exhaustive WIDTH=8" "$ROOT/build/core_small.log"

iverilog -g2012 -Wall -s tb_array_multiplier \
  -o "$ROOT/build/tb_array_multiplier.vvp" \
  "$ROOT/rtl/array_multiplier.sv" \
  "$ROOT/tb/tb_array_multiplier.sv"
(
  cd "$ROOT/build"
  vvp ./tb_array_multiplier.vvp | tee top_level.log
)
grep -q "PASS: Block16 array_multiplier" "$ROOT/build/top_level.log"
echo "Block 16 simulations completed: core_small and top_level PASS."
