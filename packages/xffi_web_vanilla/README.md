# xffi_web_vanilla

Vanilla WebAssembly backend for xffi.

`xffi_web_vanilla` provides memory integration for WebAssembly modules without depending on the Emscripten runtime. It works with raw WebAssembly exports.

## When to use it

Use this backend when your WebAssembly module exposes the memory and functions required by xffi directly, rather than relying on Emscripten's JavaScript runtime.

## Package structure

This package builds on:

- [`xffi_core`](../xffi_core) - shared types and abstractions.
- [`xffi_web`](../xffi_web) - shared web implementation.

## Requirements

Your WebAssembly module must expose the memory and allocation functions expected by this backend. The exact exports depend on how the module is compiled and configured.

## Example

[`vanilla_js`](../../test/vanilla_js/) - Shows how to compile and how to handle shared abstraction for Dart code compiled for `js` as well as `wasm`.