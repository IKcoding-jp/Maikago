import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:maikago/models/release_history.dart';
import 'package:maikago/services/debug_service.dart';

class AppInfoService {
  factory AppInfoService() => _instance;
  AppInfoService._internal();

  static final AppInfoService _instance = AppInfoService._internal();

  PackageInfo? _packageInfo;
  String? _latestVersion;
  bool _isUpdateAvailable = false;

  /// パッケージ情報を初期化
  Future<void> _initPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
  }

  /// アプリのバージョンを取得
  Future<String> getCurrentVersion() async {
    try {
      await _initPackageInfo();
      return _packageInfo!.version;
    } catch (e) {
      DebugService().logError('バージョンの取得に失敗しました: $e');
      // フォールバックとしてpubspec.yamlのバージョンを使用
      return '0.4.5';
    }
  }

  /// ビルド番号を取得
  Future<String> getBuildNumber() async {
    try {
      await _initPackageInfo();
      return _packageInfo!.buildNumber;
    } catch (e) {
      DebugService().logError('ビルド番号の取得に失敗しました: $e');
      // フォールバックとしてpubspec.yamlのビルド番号を使用
      return '24';
    }
  }

  /// アプリの完全なバージョン情報を取得（例: 0.4.5+24）
  Future<String> getFullVersion() async {
    final version = await getCurrentVersion();
    final buildNumber = await getBuildNumber();
    return '$version+$buildNumber';
  }

  /// 最新バージョンをチェック（GitHubのリリースから取得）
  Future<bool> checkForUpdates() async {
    try {
      // GitHubのリリースAPIから最新バージョンを取得
      final response = await http.get(
        // 公開エンドポイントのみ使用。トークン等の秘匿情報は使用しない。
        // セキュリティ根拠: 認証不要APIのためフロント側で安全に参照可能。
        Uri.parse(
          'https://api.github.com/repos/ikcoding/maikago/releases/latest',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        final currentVersion = await getCurrentVersion();
        _isUpdateAvailable =
            ReleaseHistory.compareVersions(_latestVersion!, currentVersion) > 0;

        return _isUpdateAvailable;
      }
    } catch (e) {
      DebugService().logError('バージョンチェックエラー: $e');
    }

    return false;
  }

  /// 更新が利用可能かどうか
  bool get isUpdateAvailable => _isUpdateAvailable;

  /// 最新バージョン
  String? get latestVersion => _latestVersion;

  /// アプリストアでアプリを開く
  Future<void> openAppStore() async {
    if (kIsWeb) return; // Web版ではネイティブストアへの遷移は不要
    try {
      // Androidの場合
      const androidUrl =
          'https://play.google.com/store/apps/details?id=com.ikcoding.maikago';
      // iOSの場合（App Store IDが必要）
      const iosUrl =
          'https://apps.apple.com/app/maikago/id1234567890'; // 実際のApp Store IDに変更が必要

      // プラットフォームに応じてURLを選択
      String url;
      if (Platform.isIOS) {
        url = iosUrl;
      } else {
        url = androidUrl; // Androidとその他のプラットフォーム
      }

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      DebugService().logError('アプリストアを開けませんでした: $e');
    }
  }

  /// GitHubのリリースページを開く
  Future<void> openGitHubReleases() async {
    try {
      const url = 'https://github.com/ikcoding/maikago/releases';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      DebugService().logError('GitHubリリースページを開けませんでした: $e');
    }
  }
}
