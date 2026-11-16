# xffi_native

Native memory backend for xffi.

`xffi_native` provides the native implementation of xffi's pointer and memory abstractions, using Dart FFI to access native memory.

## What it provides

- Native implementation of the shared `XPtr` memory abstractions.
- Memory allocation and release backed by native memory.
- Native pointer operations through Dart FFI.

## When to use it

Use this package when running xffi on a native Dart target, such as a desktop or server application.

## Related packages

- [`xffi_core`](../xffi_core) - shared types and abstractions.
- [`xffi_web`](../xffi_web) - web implementation.

## Notes

The public API is built around the abstractions defined by `xffi_core`. Refer to the package source and API documentation for the available operations and initialization requirements.