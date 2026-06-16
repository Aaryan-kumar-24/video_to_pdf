import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<File> _downloadFile(String url, String filename) async {
  final response = await http.get(Uri.parse(url));
  final bytes = response.bodyBytes;
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file;
}

void previewImpl(String url, String filename) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      final file = await _downloadFile(url, filename);
      if (Platform.isMacOS) {
        Process.run('open', [file.path]);
      } else if (Platform.isWindows) {
        Process.run('start', [file.path], runInShell: true);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [file.path]);
      }
    }
  } catch (e) {
    print('Failed to preview: $e');
  }
}

void downloadImpl(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    
    String? downloadsPath;
    if (Platform.isMacOS || Platform.isLinux) {
      downloadsPath = '${Platform.environment['HOME']}/Downloads';
    } else if (Platform.isWindows) {
      downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
    } else if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
      downloadsPath = dir?.path;
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      downloadsPath = dir.path;
    }
    
    if (downloadsPath != null) {
      final file = File('$downloadsPath/$filename');
      await file.writeAsBytes(bytes);
      
      if (Platform.isMacOS) {
        Process.run('open', ['-R', file.path]);
      } else if (Platform.isWindows) {
        Process.run('explorer.exe', ['/select,', file.path]);
      }
    }
  } catch (e) {
    print('Failed to download: $e');
  }
}

void shareImpl(String url, String filename) async {
  try {
    final file = await _downloadFile(url, filename);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: filename,
    );
  } catch (e) {
    print('Failed to share: $e');
  }
}

bool canShareFilesImpl() {
  return true;
}
