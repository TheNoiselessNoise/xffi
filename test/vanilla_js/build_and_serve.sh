#!/usr/bin/env bash

# build the demo
WASI=/home/xyzt/Sdks/wasi-sdk-34.0-x86_64-linux

"$WASI/bin/clang" \
  -O2 -nostartfiles \
  -Wl,--no-entry -Wl,--export-memory \
  -Wl,--export=add,--export=str_len,--export=malloc,--export=free,--export=vsnprintf \
  -Wl,--export=call_binop,--export=call_notify \
  -Wl,--export=call_i64,--export=call_f32,--export=call_f64 \
  -Wl,--export=vec2_add,--export=make_mixed,--export=wrap_single,--export=call_vecfn \
  -Wl,--export-table,--growable-table \
  ./demo/demo.c -o ./demo/demo.wasm

# build the javascript and wasm versions
dart compile js -o ./js/main.js ./dart/js.dart
dart compile wasm -o ./wasm/main.wasm ./dart/wasm.dart

# serve
python -m http.server 8080