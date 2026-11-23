part of '../xffi_core.dart';

/// Specific source for an external library.
sealed class XLibrarySource {
  const XLibrarySource();

  factory XLibrarySource.path(String path) = XLibrarySourcePath;
  factory XLibrarySource.asset(String path) = XLibrarySourceAsset;
}

/// Specific source for an external library, defined by it's [path].
final class XLibrarySourcePath extends XLibrarySource {
  final String path;

  const XLibrarySourcePath(this.path);
}

/// Specific source for an external library, defined by it's [assetId].
final class XLibrarySourceAsset extends XLibrarySource {
  final String assetId;

  const XLibrarySourceAsset(this.assetId);
}