import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class LinkPreviewData {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? faviconUrl;

  LinkPreviewData({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.faviconUrl,
  });

  factory LinkPreviewData.empty() => LinkPreviewData();
}

class LinkPreviewService {
  static const _timeout = Duration(seconds: 10);

  Future<LinkPreviewData> fetchPreview(String url) async {
    try {
      final uri = Uri.parse(url);

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        return LinkPreviewData.empty();
      }

      // Use the final URL after redirects for resolving relative URLs
      final resolvedUrl = response.request?.url ?? uri;
      final document = parse(response.body);
      final head = document.head;

      if (head == null) return LinkPreviewData.empty();

      String? title = _extractTitle(head);
      String? description = _extractDescription(head);
      String? imageUrl = _extractImage(head, resolvedUrl);
      String? siteName = _extractSiteName(head);
      String? faviconUrl = _extractFavicon(head, resolvedUrl);

      return LinkPreviewData(
        title: title?.trim(),
        description: _truncateDescription(description?.trim()),
        imageUrl: imageUrl,
        siteName: siteName?.trim(),
        faviconUrl: faviconUrl,
      );
    } catch (e) {
      return LinkPreviewData.empty();
    }
  }

  String? _extractTitle(dynamic head) {
    final ogTitle = head.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    final twitterTitle = head.querySelector('meta[name="twitter:title"]')?.attributes['content'];
    if (twitterTitle != null && twitterTitle.isNotEmpty) return twitterTitle;

    return head.querySelector('title')?.text;
  }

  String? _extractDescription(dynamic head) {
    final ogDesc = head.querySelector('meta[property="og:description"]')?.attributes['content'];
    if (ogDesc != null && ogDesc.isNotEmpty) return ogDesc;

    final twitterDesc = head.querySelector('meta[name="twitter:description"]')?.attributes['content'];
    if (twitterDesc != null && twitterDesc.isNotEmpty) return twitterDesc;

    return head.querySelector('meta[name="description"]')?.attributes['content'];
  }

  String? _extractImage(dynamic head, Uri baseUri) {
    final ogImage = head.querySelector('meta[property="og:image"]')?.attributes['content'];
    final imageUrl = ogImage ?? head.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    return _resolveUrl(imageUrl, baseUri);
  }

  String? _extractSiteName(dynamic head) {
    final ogSite = head.querySelector('meta[property="og:site_name"]')?.attributes['content'];
    if (ogSite != null && ogSite.isNotEmpty) return ogSite;

    final applicationName = head.querySelector('meta[name="application-name"]')?.attributes['content'];
    return applicationName;
  }

  String? _extractFavicon(dynamic head, Uri baseUri) {
    final iconLinks = [
      head.querySelector('link[rel="apple-touch-icon"]')?.attributes['href'],
      head.querySelector('link[rel="apple-touch-icon-precomposed"]')?.attributes['href'],
      head.querySelector('link[rel="icon"][sizes="192x192"]')?.attributes['href'],
      head.querySelector('link[rel="icon"][sizes="128x128"]')?.attributes['href'],
      head.querySelector('link[rel="shortcut icon"]')?.attributes['href'],
      head.querySelector('link[rel="icon"]')?.attributes['href'],
    ];

    for (final href in iconLinks) {
      if (href != null && href.isNotEmpty) {
        return _resolveUrl(href, baseUri);
      }
    }

    return '${baseUri.scheme}://${baseUri.host}/favicon.ico';
  }

  String _resolveUrl(String url, Uri baseUri) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return '${baseUri.scheme}:$url';
    if (url.startsWith('/')) return '${baseUri.scheme}://${baseUri.host}$url';
    return '${baseUri.scheme}://${baseUri.host}/$url';
  }

  String? _truncateDescription(String? desc) {
    if (desc == null) return null;
    if (desc.length <= 200) return desc;
    return '${desc.substring(0, 197)}...';
  }
}
