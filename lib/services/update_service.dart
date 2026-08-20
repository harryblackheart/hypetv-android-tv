import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(ref.watch(httpClientProvider)),
);

final updateCheckProvider = FutureProvider<UpdateInfo>(
  (ref) => ref.watch(updateServiceProvider).check(),
);

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUri,
    this.apkUri,
    this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri releaseUri;
  final Uri? apkUri;
  final String? releaseNotes;

  bool get updateAvailable => isVersionNewer(latestVersion, currentVersion);
}


enum UpdateStage {
  connecting,
  downloading,
  verifying,
  readyToInstall,
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.stage,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  final UpdateStage stage;
  final int downloadedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}

class UpdateService {
  const UpdateService(this._client);
  final http.Client _client;

  static const _installer = MethodChannel('hypetv/update');

  Future<UpdateInfo> check() async {
    final package = await PackageInfo.fromPlatform();
    final response = await _client
        .get(
          Uri.parse(AppConstants.githubLatestReleaseUrl),
          headers: const {
            HttpHeaders.acceptHeader: 'application/vnd.github+json',
            HttpHeaders.userAgentHeader: 'HypeTV-Android-TV',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == HttpStatus.notFound) {
      return UpdateInfo(
        currentVersion: package.version,
        latestVersion: package.version,
        releaseUri: Uri.parse(
          'https://github.com/harryblackheart/hypetv-android-tv/releases',
        ),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Unable to check for updates right now.',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = body['tag_name']?.toString().replaceFirst(RegExp(r'^v'), '');
    final page = body['html_url']?.toString();
    if (tag == null || page == null) {
      throw const ApiException('The update response was incomplete.');
    }

    Uri? apkUri;
    final assets = body['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map>()) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final url = asset['browser_download_url']?.toString();
        if (name.endsWith('.apk') && url?.isNotEmpty == true) {
          apkUri = Uri.tryParse(url!);
          break;
        }
      }
    }

    return UpdateInfo(
      currentVersion: package.version,
      latestVersion: tag,
      releaseUri: Uri.parse(page),
      apkUri: apkUri,
      releaseNotes: body['body']?.toString(),
    );
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    final uri = info.apkUri;
    if (uri == null) {
      throw const ApiException(
        'This release does not contain an installable APK yet.',
      );
    }

    onProgress?.call(
      const UpdateDownloadProgress(
        stage: UpdateStage.connecting,
        downloadedBytes: 0,
        totalBytes: null,
      ),
    );

    final request = http.Request('GET', uri)
      ..headers[HttpHeaders.userAgentHeader] = 'HypeTV-Android-TV';

    final response = await _client
        .send(request)
        .timeout(const Duration(minutes: 3));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'The update could not be downloaded.',
        statusCode: response.statusCode,
      );
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/HypeTV-${info.latestVersion}.apk');
    final sink = file.openWrite();

    var downloaded = 0;
    final total = response.contentLength;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(
          UpdateDownloadProgress(
            stage: UpdateStage.downloading,
            downloadedBytes: downloaded,
            totalBytes: total,
          ),
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (downloaded <= 0) {
      throw const ApiException('The downloaded update file was empty.');
    }

    onProgress?.call(
      UpdateDownloadProgress(
        stage: UpdateStage.verifying,
        downloadedBytes: downloaded,
        totalBytes: total ?? downloaded,
      ),
    );

    if (!await file.exists() || await file.length() != downloaded) {
      throw const ApiException('The update download could not be verified.');
    }

    onProgress?.call(
      UpdateDownloadProgress(
        stage: UpdateStage.readyToInstall,
        downloadedBytes: downloaded,
        totalBytes: total ?? downloaded,
      ),
    );

    await _installer.invokeMethod<void>('installApk', {'path': file.path});
  }
}

bool isVersionNewer(String candidate, String current) {
  List<int> parts(String value) => value
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[.+-]'))
      .take(3)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  final candidateParts = parts(candidate);
  final currentParts = parts(current);
  for (var index = 0; index < 3; index++) {
    final next = index < candidateParts.length ? candidateParts[index] : 0;
    final installed = index < currentParts.length ? currentParts[index] : 0;
    if (next != installed) {
      return next > installed;
    }
  }
  return false;
}
