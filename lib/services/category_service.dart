class CategoryService {
  static const _techKeywords = [
    'ai', 'artificial intelligence', 'machine learning', 'ml', 'deep learning',
    'neural network', 'llm', 'gpt', 'chatgpt', 'claude', 'gemini',
    'programming', 'coding', 'developer', 'software', 'api', 'sdk',
    'cloud', 'aws', 'azure', 'gcp', 'devops', 'kubernetes', 'docker',
    'cybersecurity', 'cyber security', 'infosec', 'hacking', 'vulnerability',
    'blockchain', 'crypto', 'cryptocurrency', 'bitcoin', 'ethereum', 'web3',
    'startup', 'funding', 'series a', 'series b', 'seed round',
    'javascript', 'python', 'rust', 'typescript', 'golang', 'java',
    'react', 'flutter', 'swift', 'kotlin', 'firebase', 'supabase',
    'github', 'gitlab', 'open source', 'open-source',
    'tech', 'technology', 'silicon valley', 'big tech',
    'semiconductor', 'chip', 'processor', 'nvidia', 'amd', 'intel',
    'robotics', 'automation', 'iot', 'edge computing',
    'quantum', '5g', '6g', 'ar vr', 'vr ar', 'augmented reality', 'virtual reality',
    'saas', 'paas', 'iaas', 'serverless', 'microservices',
    'database', 'sql', 'nosql', 'redis', 'postgres', 'mongodb',
    'frontend', 'backend', 'fullstack', 'full-stack', 'devtools',
    'product hunt', 'y combinator', 'yc',
    // AI companies and products
    'openai', 'codex', 'copilot', 'symphony', 'anthropic', 'deepmind',
    'stability ai', 'midjourney', 'dall-e', 'sora',
    // Dev tools and automation
    'linear', 'jira', 'notion', 'figma', 'vercel', 'netlify',
    'automation', 'automate', 'workflow', 'agent', 'agents',
    // Security
    'ransomware', 'malware', 'phishing', 'zero-day', 'cve',
    'firewall', 'encryption', 'penetration test',
  ];

  static const _techSources = [
    'techcrunch', 'theverge', 'arstechnica', 'wired', 'engadget',
    'gizmodo', 'hacker news', 'dev.to', 'hashnode', 'medium.com',
    'zdnet', 'cnet', 'tomshardware', 'anandtech', 'venturebeat',
    'thenextweb', 'tnw', 'mashable', 'digital trends',
    'bgr.com', '9to5google', '9to5mac', 'macrumors', 'androidauthority',
    'android central', 'xda-developers', 'xda developers',
    'infoq', 'dzone', 'stackoverflow', 'stack overflow',
    'github.com', 'gitlab.com', 'npmjs.com', 'pypi.org',
    'huggingface', 'paperswithcode', 'arxiv.org',
    'producthunt', 'product hunt', 'ycombinator', 'y combinator',
    'openai.com', 'deepmind', 'anthropic',
    'theinformation', 'stratechery', 'daringfireball',
    // Security-focused tech publications
    'helpnetsecurity', 'thehackernews', 'bleepingcomputer', 'darkreading',
    'securityweek', 'threatpost', 'krebs on security', 'krebsonsecurity',
    'sans.org', 'owasp',
    // Dev/AI publications
    'benevolence.ai', 'spectrum.ieee', 'ieee',
  ];

  /// Categorize an article based on its URL, title, description, and site name.
  /// Returns 'tech' if it matches tech patterns, 'general' otherwise.
  static String categorize({
    required String url,
    String? title,
    String? description,
    String? siteName,
  }) {
    final combinedText = [
      url.toLowerCase(),
      (title ?? '').toLowerCase(),
      (description ?? '').toLowerCase(),
      (siteName ?? '').toLowerCase(),
    ].join(' ');

    // Check tech sources first (stronger signal)
    for (final source in _techSources) {
      if (combinedText.contains(source)) return 'tech';
    }

    // Check tech keywords
    for (final keyword in _techKeywords) {
      // Use word boundary check for short keywords to avoid false positives
      if (keyword.length <= 3) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
        if (regex.hasMatch(combinedText)) return 'tech';
      } else {
        if (combinedText.contains(keyword)) return 'tech';
      }
    }

    return 'general';
  }
}
