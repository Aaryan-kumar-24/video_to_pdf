import 'dart:io';
import 'dart:typed_data';

void previewImpl(Uint8List bytes, String filename) async {
  final tempDir = Directory.systemTemp;
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(bytes);
  
  if (Platform.isMacOS) {
    Process.run('open', [file.path]);
  } else if (Platform.isWindows) {
    Process.run('start', [file.path], runInShell: true);
  } else if (Platform.isLinux) {
    Process.run('xdg-open', [file.path]);
  }
}

void downloadImpl(Uint8List bytes, String filename) async {
  // Save to Downloads folder
  String? downloadsPath;
  if (Platform.isMacOS || Platform.isLinux) {
    downloadsPath = '${Platform.environment['HOME']}/Downloads';
  } else if (Platform.isWindows) {
    downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
  }
  
  if (downloadsPath != null) {
    final file = File('$downloadsPath/$filename');
    await file.writeAsBytes(bytes);
    
    // Optionally open the directory to show the file
    if (Platform.isMacOS) {
      Process.run('open', ['-R', file.path]);
    } else if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', file.path]);
    }
  }
}
