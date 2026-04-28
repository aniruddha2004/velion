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
  static const _timeout = Duration(seconds: 15);

  Future<LinkPreviewData> fetchPreview(String url) async {
    try {
      final uri = Uri.parse(url);

      // Use desktop User-Agent for Instagram to avoid login wall
      final isInstagram = uri.host.toLowerCase().contains('instagram.com') ||
          uri.host.toLowerCase().contains('instagr.am');
      final userAgent = isInstagram
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'max-age=0',
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

      // Try JSON-LD first (Instagram, LinkedIn use this)
      final jsonLdData = _extractJsonLd(document);

      String? title = _extractTitle(head) ?? jsonLdData['headline'] ?? jsonLdData['name'];
      String? description = _extractDescription(head) ?? jsonLdData['description'];
      String? imageUrl = _extractImage(head, resolvedUrl) ?? _extractImageFromJsonLd(jsonLdData, resolvedUrl);
      String? siteName = _extractSiteName(head) ?? jsonLdData['publisher']?['name'];
      String? faviconUrl = _extractFavicon(head, resolvedUrl);

      // Instagram fallback: extract image from page scripts
      if (isInstagram && imageUrl == null) {
        final scripts = document.querySelectorAll('script');
        for (final script in scripts) {
          final content = script.text;
          if (content.contains('"image":')) {
            final regex = RegExp(r'"image":"([^"]+)"');
            final match = regex.firstMatch(content);
            if (match != null) {
              imageUrl = match.group(1)?.replaceAll(r'\/', '/');
              break;
            }
          }
        }
      }

      // Instagram profile fallback: extract username
      if (isInstagram && title == null) {
        final pageTitle = document.querySelector('title')?.text;
        if (pageTitle != null && pageTitle.contains('(@')) {
          title = pageTitle.trim();
        } else {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            title = '@${segments.first}';
            description = 'Instagram profile';
          }
        }
      }

      // Default siteName to domain
      siteName ??= _extractDomain(resolvedUrl);

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

  Map<String, dynamic> _extractJsonLd(dynamic document) {
    try {
      final scripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (final script in scripts) {
        final text = script.text;
        if (text.isNotEmpty) {
          try {
            final data = jsonDecode(text);
            if (data is Map<String, dynamic>) {
              if (data.containsKey('@graph')) {
                final graph = data['@graph'] as List;
                for (final item in graph) {
                  if (item['@type'] == 'Article' ||
                      item['@type'] == 'NewsArticle' ||
                      item['@type'] == 'SocialMediaPosting' ||
                      item['@type'] == 'ProfilePage') {
                    return item as Map<String, dynamic>;
                  }
                }
              }
              return data;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return {};
  }

  String? _extractImageFromJsonLd(Map<String, dynamic> jsonLd, Uri baseUri) {
    final image = jsonLd['image'];
    if (image == null) return null;

    if (image is List && image.isNotEmpty) {
      final firstImage = image.first;
      if (firstImage is String) return _resolveUrl(firstImage, baseUri);
      if (firstImage is Map) return _resolveUrl(firstImage['url']?.toString() ?? '', baseUri);
    } else if (image is String) {
      return _resolveUrl(image, baseUri);
    } else if (image is Map) {
      return _resolveUrl(image['url']?.toString() ?? '', baseUri);
    }
    return null;
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
    final twitterImage = head.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    final twitterImageSrc = head.querySelector('meta[name="twitter:image:src"]')?.attributes['content'];

    final imageUrl = ogImage ?? twitterImage ?? twitterImageSrc;

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
      head.querySelector('link[rel="apple-touch-icon"][sizes="180x180"]')?.attributes['href'],
      head.querySelector('link[rel="apple-touch-icon"]')?.attributes['href'],
      head.querySelector('link[rel="apple-touch-icon-precomposed"]')?.attributes['href'],
      head.querySelector('link[rel="icon"][type="image/png"][sizes="192x192"]')?.attributes['href'],
      head.querySelector('link[rel="icon"][sizes="192x192"]')?.attributes['href'],
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

  String _extractDomain(Uri uri) {
    final host = uri.host;
    if (host.startsWith('www.')) {
      return host.substring(4);
    }
    return host;
  }

  String? _truncateDescription(String? desc) {
    if (desc == null) return null;
    if (desc.length <= 200) return desc;
    return '${desc.substring(0, 197)}...';
  }
}
