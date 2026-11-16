# xffi

**A cross-platform FFI foundation for Dart.**

`xffi` provides a shared set of low-level primitives and abstractions for working with native memory, C-compatible structures, and foreign-function interfaces across Dart platforms.

The project separates platform-independent functionality from platform-specific memory and interop implementations. This allows packages built on top of `xffi` to share the same underlying abstractions while targeting native platforms or the web.

| Package | Description |
| --- | --- |
| [`xffi_core`](packages/xffi_core) | Platform-independent foundations, including `XPtr`, `XStruct`, and primitive types. |
| [`xffi_native`](packages/xffi_native) | Native implementation using Dart FFI and native memory. |
| [`xffi_web`](packages/xffi_web) | WebAssembly memory and interop foundation for Dart web applications. |
| [`xffi_web_vanilla`](packages/xffi_web_vanilla) | WebAssembly backend using raw Wasm memory, without relying on the Emscripten runtime. |
| [`xffi_web_emscripten`](packages/xffi_web_emscripten) | WebAssembly backend integrated with the Emscripten runtime. |

The repository also contains `xffi_gen`, an experimental, not-yet-ready, private package for C/C++ binding generation. It is not part of the public package set.