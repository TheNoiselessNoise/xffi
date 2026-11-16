# xffi_core

Core types and abstractions shared by the xffi packages.

This package provides the common memory and structure model used by the platform-specific backends, including `XPtr`, `XStruct`, and related primitives.

## What it provides

- `XPtr` and the shared pointer abstractions.
- `XStruct` and the shared structure abstractions.
- Common memory types, layouts, and operations.
- Platform-independent building blocks used by the other xffi packages.

## Platform support

`xffi_core` contains the shared API and abstractions. A platform backend is required to provide the actual memory implementation for the target environment.

Use `xffi_native` for native Dart applications, or `xffi_web` together with a web backend for WebAssembly applications.

## Related packages

- [`xffi_native`](../xffi_native) - native implementation using Dart FFI.
- [`xffi_web`](../xffi_web) - shared web implementation.
- [`xffi_web_vanilla`](../xffi_web_vanilla) - raw WebAssembly backend.
- [`xffi_web_emscripten`](../xffi_web_emscripten) - Emscripten backend.

## Status

This package is part of the xffi workspace. See the repository for the source code and development history.