// lib/services/imagekit_service.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'imagekit_config.dart';

class ImageKitService {
  static final ImageKitService _instance = ImageKitService._internal();
  factory ImageKitService() => _instance;
  ImageKitService._internal();

  /// Upload file to ImageKit
  Future<String?> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String folder = 'profile_photos',
    Map<String, String>? customMetadata,
  }) async {
    if (!ImageKitConfig.isConfigured()) {
      print('ImageKit not configured. Check imagekit_config.dart');
      return null;
    }

    try {
      const String uploadUrl =
          'https://upload.imagekit.io/api/v1/files/upload';

      // 1. Primary method: Direct HTTP Basic Auth with Private Key
      // This is the most reliable method as it does not suffer from client clock skew or token collisions
      try {
        final basicRequest =
            http.MultipartRequest('POST', Uri.parse(uploadUrl));
        final authHeader = 'Basic ${base64Encode(utf8.encode('${ImageKitConfig.privateKey.trim()}:'))}';
        basicRequest.headers['Authorization'] = authHeader;

        basicRequest.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        );

        basicRequest.fields['fileName'] = fileName;
        basicRequest.fields['folder'] = folder;

        if (customMetadata != null && customMetadata.isNotEmpty) {
          basicRequest.fields['customMetadata'] = jsonEncode(customMetadata);
        }

        final response = await basicRequest.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          return data['url'] as String?;
        }
        print('ImageKit Basic Auth attempt returned ${response.statusCode}: $responseBody');
      } catch (basicErr) {
        print('ImageKit Basic Auth attempt error: $basicErr');
      }

      // 2. Fallback method: Client-side signature auth
      final sigRequest =
          http.MultipartRequest('POST', Uri.parse(uploadUrl));

      sigRequest.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      sigRequest.fields['fileName'] = fileName;
      sigRequest.fields['folder'] = folder;

      if (customMetadata != null && customMetadata.isNotEmpty) {
        sigRequest.fields['customMetadata'] = jsonEncode(customMetadata);
      }

      final String token = _generateRandomString(32);
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String expire = (now + 1800).toString(); // +30 minutes
      final String signature = _generateSignature(token, expire);

      sigRequest.fields['publicKey'] = ImageKitConfig.publicKey.trim();
      sigRequest.fields['token'] = token;
      sigRequest.fields['expire'] = expire;
      sigRequest.fields['signature'] = signature;

      final sigResponse = await sigRequest.send();
      final sigResponseBody = await sigResponse.stream.bytesToString();

      if (sigResponse.statusCode == 200) {
        final data = jsonDecode(sigResponseBody);
        return data['url'] as String?;
      }

      print('ImageKit signature upload failed: ${sigResponse.statusCode} - $sigResponseBody');
      return null;
    } catch (e) {
      print('ImageKit upload exception: $e');
      return null;
    }
  }

  /// Generate HMAC-SHA256 signature
  String _generateSignature(String token, String expire) {
  final key = utf8.encode(ImageKitConfig.privateKey.trim());
  final data = utf8.encode(token + expire);

  final hmacSha1 = Hmac(sha1, key);
  final digest = hmacSha1.convert(data);

  return digest.toString();
}

  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rand.nextInt(chars.length)),
      ),
    );
  }

  /// Generate optimized ImageKit URL
  String getOptimizedUrl(
    String url, {
    int width = 200,
    int height = 200,
    int quality = 80,
    String cropMode = 'at_max',
  }) {
    if (url.isEmpty) return url;

    final cleanUrl = url.trim();
    final transformation =
        'w-$width,h-$height,c-$cropMode,q-$quality';

    if (cleanUrl.contains('?')) {
      return '$cleanUrl&tr=$transformation';
    }
    return '$cleanUrl?tr=$transformation';
  }

  String getThumbnailUrl(String url, {int size = 100}) {
    return getOptimizedUrl(url, width: size, height: size);
  }

  static bool get isConfigured => ImageKitConfig.isConfigured();
}
