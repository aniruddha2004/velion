import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      debugPrint('Fetching preview for: $normalizedUrl');
      
      final uri = Uri.parse(normalizedUrl);
      
      // Handle Google sharing URLs - they redirect to the actual article
      if (uri.host.contains('share.google')) {
        debugPrint('Detected Google share URL, attempting to resolve...');
        final redirectUrl = await _resolveGoogleShareUrl(uri);
        if (redirectUrl != null) {
          debugPrint('Resolved to: $redirectUrl');
          return fetchPreview(redirectUrl);
        } else {
          debugPrint('Failed to resolve Google share URL');
        }
      }

      // Use desktop User-Agent for Instagram to avoid login wall
      final isInstagram = uri.host.toLowerCase().contains('instagram.com') ||
          uri.host.toLowerCase().contains('instagr.am');
      final isYouTube = uri.host.toLowerCase().contains('youtube.com') ||
          uri.host.toLowerCase().contains('youtu.be');
      final userAgent = (isInstagram || isYouTube)
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

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Final URL after redirects: ${response.request?.url}');

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

      // YouTube fallback: extract video title and description from page
      if (isYouTube && (title == null || title == 'YouTube')) {
        final pageTitle = document.querySelector('title')?.text;
        if (pageTitle != null && pageTitle != 'YouTube') {
          // Remove " - YouTube" suffix if present
          title = pageTitle.replaceAll(RegExp(r'\s*-\s*YouTube\s*$'), '').trim();
        }
        
        // Try to extract description from meta tags more aggressively
        if (description == null || description.isEmpty) {
          // Look for video description in various places
          final metaDesc = head.querySelector('meta[name="description"]')?.attributes['content'];
          if (metaDesc != null && metaDesc.isNotEmpty && metaDesc != 'Enjoy the videos and music you love, upload original content, and share it all with friends, family, and the world on YouTube.') {
            description = metaDesc;
          }
          
          // Try JSON-LD for VideoObject
          if (jsonLdData['@type'] == 'VideoObject') {
            description ??= jsonLdData['description'];
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

  /// Fetch the full article text content from a URL.
  /// Extracts article body text by looking for common article containers.
  Future<String?> fetchFullArticleContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final isInstagram = uri.host.toLowerCase().contains('instagram.com') ||
          uri.host.toLowerCase().contains('instagr.am');
      final userAgent = isInstagram
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final document = parse(response.body);

      // Try to get full article text from JSON-LD articleBody first
      final jsonLdData = _extractJsonLd(document);
      final articleBody = jsonLdData['articleBody'];
      if (articleBody is String && articleBody.length > 200) {
        return articleBody.trim();
      }

      // Try common article content selectors
      final selectors = [
        'article',
        '[role="article"]',
        '.article-body',
        '.article-content',
        '.article-text',
        '.post-body',
        '.post-content',
        '.entry-content',
        '.story-body',
        '.story-content',
        '.content-body',
        '.article__body',
        '.article__content',
        '#article-body',
        '#article-content',
        '.main-content',
        '.post-article',
      ];

      for (final selector in selectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          final text = _extractTextFromElement(element);
          if (text.length > 200) return text;
        }
      }

      // Fallback: get all paragraph text from the body
      final body = document.body;
      if (body != null) {
        final text = _extractTextFromElement(body);
        if (text.length > 100) return text;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract clean text from an HTML element, removing scripts, styles, nav, etc.
  String _extractTextFromElement(dynamic element) {
    // Remove unwanted elements
    final removeSelectors = [
      'script', 'style', 'nav', 'header', 'footer',
      '.sidebar', '.ad', '.advertisement', '.social-share',
      '.share-buttons', '.comments', '.related', '.newsletter',
      'noscript', 'iframe',
    ];

    final clone = element.clone(true);
    for (final selector in removeSelectors) {
      clone.querySelectorAll(selector).forEach((el) => el.remove());
    }

    // Get text from paragraphs, headings, lists, blockquotes
    final contentElements = clone.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote, pre');
    final buffer = StringBuffer();
    for (final el in contentElements) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        buffer.writeln(text);
        buffer.writeln();
      }
    }

    var result = buffer.toString().trim();
    // Clean up excessive whitespace
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Truncate to ~15000 chars to stay within token limits
    if (result.length > 15000) {
      result = '${result.substring(0, 14997)}...';
    }
    return result;
  }

  /// Resolve Google share.google URLs to the actual destination
  Future<String?> _resolveGoogleShareUrl(Uri uri) async {
    try {
      // Follow redirects manually to get the final URL
      var currentUri = uri;
      var redirectCount = 0;
      const maxRedirects = 5;
      
      while (redirectCount < maxRedirects) {
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36';
        
        final streamedResponse = await request.send().timeout(Duration(seconds: 10));
        final response = await http.Response.fromStream(streamedResponse);
        
        // Check for redirect
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          if (location != null) {
            currentUri = Uri.parse(location);
            redirectCount++;
            continue;
          }
        }
        
        // Parse the final response
        if (response.statusCode == 200) {
          // If we reached a non-share.google URL, return it
          if (!currentUri.host.contains('share.google')) {
            return currentUri.toString();
          }
          
          // Still on share.google, parse the HTML
          final document = parse(response.body);
          
          // Look for meta refresh
          final metaRefresh = document.querySelector('meta[http-equiv="refresh"]');
          if (metaRefresh != null) {
            final content = metaRefresh.attributes['content'];
            if (content != null) {
              final match = RegExp(r'URL=\s*(.+)', caseSensitive: false).firstMatch(content);
              if (match != null) {
                return match.group(1)?.trim();
              }
            }
          }
          
          // Look for canonical link
          final canonical = document.querySelector('link[rel="canonical"]');
          if (canonical != null) {
            final href = canonical.attributes['href'];
            if (href != null && !href.contains('share.google')) {
              return href;
            }
          }
          
          // Look for og:url
          final ogUrl = document.querySelector('meta[property="og:url"]');
          if (ogUrl != null) {
            final content = ogUrl.attributes['content'];
            if (content != null && !content.contains('share.google')) {
              return content;
            }
          }
          
          // Look for JavaScript redirect
          final scripts = document.querySelectorAll('script');
          for (final script in scripts) {
            final text = script.text;
            // Match location.href assignments
            final hrefMatch = RegExp(r'location\.href\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(text);
            if (hrefMatch != null) {
              final url = hrefMatch.group(1);
              if (url != null && !url.contains('share.google')) {
                return url;
              }
            }
          }
          
          return null;
        }
        
        return null;
      }
      
      return null;
    } catch (e) {
      debugPrint('Failed to resolve Google share URL: $e');
      return null;
    }
  }
}
