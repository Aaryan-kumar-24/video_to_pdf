import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

void previewImpl(String url, String filename) {
  html.window.open(url, '_blank');
}

/// Force-download via Blob so the browser never opens the PDF in a tab.
void downloadImpl(String url, String filename) async {
  try {
    final request = await html.HttpRequest.request(
      url,
      responseType: 'arraybuffer',
    );
    final buffer = request.response as dynamic;
    final blob = html.Blob([buffer], 'application/pdf');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: blobUrl)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(blobUrl);
  } catch (e) {
    // Fallback: plain anchor download
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
  }
}

void shareImpl(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: filename,
    );
    await Share.shareXFiles(
      [xFile],
      subject: filename,
    );
  } catch (e) {
    // Copy URL to clipboard as a basic fallback
    html.window.navigator.clipboard?.writeText(url);
  }
}

/// Open a URL in a new tab (used by the custom share sheet).
void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

/// Copy text to clipboard.
void copyToClipboard(String text) {
  html.window.navigator.clipboard?.writeText(text);
}
