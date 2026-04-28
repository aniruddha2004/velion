import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = 'gemini-2.0-flash';
  bool _obscureApiKey = true;
  bool _isLoading = true;

  static const _geminiModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(settingsServiceProvider);
    final apiKey = await service.getGeminiApiKey();
    final model = await service.getGeminiModel();
    if (mounted) {
      _apiKeyController.text = apiKey ?? '';
      setState(() {
        _selectedModel = model;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Configure your AI assistant',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFA6ADBD),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // AI Provider Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSectionCard(
                  icon: Icons.auto_awesome,
                  title: 'AI Provider',
                  subtitle: 'Configure your AI model and API key',
                  gradient: const [Color(0xFF6878FF), Color(0xFF3B82F6)],
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(color: Color(0xFF6878FF)),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Provider label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6878FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF6878FF).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Google Gemini',
                                    style: TextStyle(
                                      color: Color(0xFF6878FF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.check_circle, color: const Color(0xFF6878FF).withOpacity(0.7), size: 18),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Model dropdown
                            Text(
                              'AI Model',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2029),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2A2C38), width: 0.5),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedModel,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6878FF)),
                                  dropdownColor: const Color(0xFF1E2029),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  borderRadius: BorderRadius.circular(14),
                                  items: _geminiModels.map((model) {
                                    return DropdownMenuItem(
                                      value: model,
                                      child: Text(model),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedModel = value);
                                      ref.read(settingsNotifierProvider.notifier).setGeminiModel(value);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // API Key field
                            Text(
                              'API Key',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2029),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2A2C38), width: 0.5),
                              ),
                              child: TextField(
                                controller: _apiKeyController,
                                obscureText: _obscureApiKey,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Enter your Gemini API key',
                                  hintStyle: const TextStyle(color: Color(0xFF5A5A6A), fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF5A5A6A),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                                  ),
                                ),
                                onChanged: (value) {
                                  ref.read(settingsNotifierProvider.notifier).setGeminiApiKey(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Get your API key from ai.google.dev',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF5A5A6A),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA6ADBD),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
