# xffi_web_emscripten

Emscripten backend for xffi.

`xffi_web_emscripten` provides memory integration for WebAssembly modules built with Emscripten. It uses Emscripten's runtime and exported functions to connect xffi's memory abstractions to the module.

## When to use it

Use this backend when your WebAssembly module is built with Emscripten and relies on its JavaScript runtime for memory and function access.

## Package structure

This package builds on:

- [`xffi_core`](../xffi_core) - shared types and abstractions.
- [`xffi_web`](../xffi_web) - shared web implementation.

The Emscripten-specific layer handles the runtime integration, while the shared web package provides the common xffi web functionality.

## Requirements

Your application must load and initialize the Emscripten-generated JavaScript module before using the xffi backend. The module must expose the runtime functionality expected by this package.