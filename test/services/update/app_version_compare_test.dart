import 'package:fleur/services/update/app_version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares stable semantic versions', () {
    expect(
      isRemoteVersionNewer(currentVersion: '0.1.2', remoteVersion: '0.1.3'),
      isTrue,
    );
    expect(
      isRemoteVersionNewer(currentVersion: '0.1.3', remoteVersion: '0.1.3'),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(currentVersion: '0.2.0', remoteVersion: '0.1.9'),
      isFalse,
    );
  });

  test('orders prereleases before stable release', () {
    expect(
      isRemoteVersionNewer(
        currentVersion: '0.1.5-beta.1',
        remoteVersion: '0.1.5',
      ),
      isTrue,
    );
    expect(
      isRemoteVersionNewer(
        currentVersion: '0.1.5',
        remoteVersion: '0.1.5-rc.1',
      ),
      isFalse,
    );
  });

  test('compares prerelease identifiers', () {
    expect(
      isRemoteVersionNewer(
        currentVersion: '0.1.5-beta.1',
        remoteVersion: '0.1.5-beta.2',
      ),
      isTrue,
    );
    expect(
      isRemoteVersionNewer(
        currentVersion: '0.1.5-rc.2',
        remoteVersion: '0.1.5-beta.3',
      ),
      isFalse,
    );
  });
}
