import 'dart:html' as html;
import 'dart:js' as js;

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

void _initJs() {
  js.context.callMethod('eval', ["""
    window.webCanShareFiles = function() {
      try {
        if (navigator.canShare) {
          const file = new File([], 'test.pdf', { type: 'application/pdf' });
          return navigator.canShare({ files: [file] });
        }
      } catch (e) {}
      return false;
    };

    window.webShareFile = function(url, filename, fallbackUrl) {
      return fetch(url)
        .then(function(response) { return response.arrayBuffer(); })
        .then(function(buffer) {
          const file = new File([buffer], filename, { type: 'application/pdf' });
          if (navigator.canShare && navigator.canShare({ files: [file] })) {
            return navigator.share({
              files: [file],
              title: filename
            });
          }
          throw new Error('Not shareable');
        })
        .catch(function(err) {
          console.error('Web share failed, copying to clipboard as fallback: ', err);
          if (navigator.clipboard) {
            navigator.clipboard.writeText(fallbackUrl);
          }
        });
    };
  """]);
}

void shareImpl(String url, String filename) {
  try {
    _initJs();
    js.context.callMethod('webShareFile', [url, filename, url]);
  } catch (e) {
    // Fallback: Copy URL to clipboard
    html.window.navigator.clipboard?.writeText(url);
  }
}

bool canShareFilesImpl() {
  try {
    _initJs();
    return js.context.callMethod('webCanShareFiles') as bool;
  } catch (e) {
    // ignore
  }
  return false;
}

/// Open a URL in a new tab (used by the custom share sheet).
void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

/// Copy text to clipboard.
void copyToClipboard(String text) {
  html.window.navigator.clipboard?.writeText(text);
}
