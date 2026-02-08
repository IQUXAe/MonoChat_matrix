import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A utility class to handle platform-specific dynamic library loading.
/// 
/// This addresses the issue of hardcoded library paths by providing:
/// - Platform-specific naming conventions.
/// - Configuration via environment variables.
/// - Relative path lookups for bundled libraries.
class LibraryLoader {
  /// Loads a dynamic library by [name].
  /// 
  /// The [name] should be the base name of the library (e.g., 'sqlcipher_flutter_libs_plugin').
  /// The method will automatically append the appropriate prefix and extension for the current platform.
  /// 
  /// Loading order:
  /// 1. Environment variable override: `LIB{NAME}_PATH`
  /// 2. Default OS search paths (relying on RPATH or standard system locations)
  /// 3. Fallback: Path relative to the application executable (bundled libraries)
  static DynamicLibrary load(String name) {
    final String filename;
    if (Platform.isLinux) {
      filename = 'lib$name.so';
    } else if (Platform.isWindows) {
      filename = '$name.dll';
    } else if (Platform.isMacOS) {
      filename = 'lib$name.dylib';
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported for dynamic library loading.');
    }

    // 1. Check for environment variable override (Configuration)
    final envVarName = 'LIB${name.toUpperCase()}_PATH';
    final envPath = Platform.environment[envVarName];
    if (envPath != null && envPath.isNotEmpty) {
      return DynamicLibrary.open(envPath);
    }

    // 2. Try loading from standard library paths
    try {
      return DynamicLibrary.open(filename);
    } catch (_) {
      // 3. Fallback: Try relative to the executable (bundled libraries)
      try {
        final executableDir = p.dirname(Platform.resolvedExecutable);
        final String bundledPath;
        
        if (Platform.isLinux) {
          // On Linux, bundled libs are typically in the 'lib' subfolder relative to the binary
          bundledPath = p.join(executableDir, 'lib', filename);
        } else {
          // On Windows and macOS, they are often in the same folder as the binary
          bundledPath = p.join(executableDir, filename);
        }

        if (FileSystemEntity.typeSync(bundledPath) != FileSystemEntityType.notFound) {
          return DynamicLibrary.open(bundledPath);
        }
      } catch (_) {
        // Fall through to rethrow original error if relative lookup also fails
      }
      
      rethrow;
    }
  }
}
