# xffi_web

Shared web implementation for xffi.

`xffi_web` provides the web-side implementation of xffi's pointer and memory abstractions. It is the common foundation used by the `xffi_web_*` backend packages.

## What it provides

- Web-compatible implementation of the shared xffi pointer abstractions.
- WebAssembly memory integration.
- Common web memory setup used by the backend packages.

## Backends

Choose a backend according to how your WebAssembly module was built:

- [`xffi_web_vanilla`](../xffi_web_vanilla) - integrates with raw WebAssembly exports without relying on the Emscripten runtime.
- [`xffi_web_emscripten`](../xffi_web_emscripten) - integrates with Emscripten's runtime and exported functions.

`xffi_web` provides the shared web layer; the backend package supplies the environment-specific integration.

## Related packages

- [`xffi_core`](../xffi_core) - shared types and abstractions.
- [`xffi_web_vanilla`](../xffi_web_vanilla) - vanilla WebAssembly backend.
- [`xffi_web_emscripten`](../xffi_web_emscripten) - Emscripten backend.

## Notes

Refer to the selected backend's documentation for its setup and initialization requirements.