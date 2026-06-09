class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this.major, this.minor, this.patch, this.preRelease);

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  static AppVersion parse(String value) {
    final buildSeparator = value.indexOf('+');
    final withoutBuild = buildSeparator == -1
        ? value
        : value.substring(0, buildSeparator);
    final preReleaseSeparator = withoutBuild.indexOf('-');
    final core = preReleaseSeparator == -1
        ? withoutBuild
        : withoutBuild.substring(0, preReleaseSeparator);
    final preRelease = preReleaseSeparator == -1
        ? const <String>[]
        : withoutBuild.substring(preReleaseSeparator + 1).split('.');
    final parts = core.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid app version: $value');
    }
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) {
      throw FormatException('Invalid app version: $value');
    }
    return AppVersion._(major, minor, patch, preRelease);
  }

  @override
  int compareTo(AppVersion other) {
    final core = _compareInt(major, other.major);
    if (core != 0) return core;
    final minorResult = _compareInt(minor, other.minor);
    if (minorResult != 0) return minorResult;
    final patchResult = _compareInt(patch, other.patch);
    if (patchResult != 0) return patchResult;

    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final count = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < count; index++) {
      if (index >= preRelease.length) return -1;
      if (index >= other.preRelease.length) return 1;
      final result = _comparePreReleasePart(
        preRelease[index],
        other.preRelease[index],
      );
      if (result != 0) return result;
    }
    return 0;
  }

  static int _compareInt(int a, int b) => a == b ? 0 : (a > b ? 1 : -1);

  static int _comparePreReleasePart(String a, String b) {
    final aNumber = int.tryParse(a);
    final bNumber = int.tryParse(b);
    if (aNumber != null && bNumber != null) {
      return _compareInt(aNumber, bNumber);
    }
    if (aNumber != null) return -1;
    if (bNumber != null) return 1;
    return a.compareTo(b).sign;
  }
}

bool isRemoteVersionNewer({
  required String currentVersion,
  required String remoteVersion,
}) {
  return AppVersion.parse(
        remoteVersion,
      ).compareTo(AppVersion.parse(currentVersion)) >
      0;
}
