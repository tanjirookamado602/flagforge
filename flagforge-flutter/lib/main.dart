import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flagsmith/flagsmith.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Fallback if .env not present
  }
  runApp(const FlagForgeApp());
}

class FlagForgeApp extends StatelessWidget {
  const FlagForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlagForge Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  FlagsmithClient? _flagsmithClient;
  bool _isLoading = true;
  String _activeVariant = 'variant_a'; // default fallback
  late final String _sessionId;
  int _clickCount = 0;
  bool _isSimulating = false;
  String _statusMessage = 'Connecting to Flagsmith...';

  final String _defaultEnvKey = 'RzHBVWSKkhdTJqQKsfa4bQ';
  final String _defaultBaseUrl = 'http://localhost:8000/api/v1/';

  @override
  void initState() {
    super.initState();
    _sessionId = 'session_${const Uuid().v4().substring(0, 8)}';
    _initFlagsmith();
  }

  @override
  void dispose() {
    _flagsmithClient?.close();
    super.dispose();
  }

  String _getEnv(String key, String fallback) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet(key) ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _initFlagsmith() async {
    final envKey = _getEnv('FLAGSMITH_ENVIRONMENT_KEY', _defaultEnvKey);
    final baseUri = _getEnv('FLAGSMITH_BASE_URL', _defaultBaseUrl);

    try {
      _flagsmithClient = await FlagsmithClient.init(
        apiKey: envKey,
        config: FlagsmithConfig(
          baseURI: baseUri,
          isDebug: kDebugMode,
          enableAnalytics: true,
        ),
      );

      await _fetchVariant();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Flagsmith initialized (Local fallback mode)';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchVariant() async {
    if (_flagsmithClient == null) return;
    try {
      final identity = Identity(identifier: _sessionId);
      final flagValue = await _flagsmithClient!.getFeatureFlagValue(
        'cta_button',
        user: identity,
        reload: true,
      );

      if (mounted) {
        setState(() {
          if (flagValue != null && flagValue.isNotEmpty) {
            _activeVariant = flagValue.toLowerCase().contains('b') ? 'variant_b' : 'variant_a';
          }
          _statusMessage = 'Connected to Flagsmith (Flag: cta_button)';
          _isLoading = false;
        });
        _sendFlagsmithEvent(eventName: r'$flag_exposure', value: _activeVariant, count: 1);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Active Variant: $_activeVariant';
        });
      }
    }
  }

  Future<void> _sendFlagsmithEvent({
    required String eventName,
    required String value,
    int count = 1,
  }) async {
    final baseUrl = _getEnv('FLAGSMITH_BASE_URL', 'http://localhost:8000');
    final cleanBaseUrl = baseUrl.replaceAll('/api/v1/', '').replaceAll('/api/v1', '');
    final envKey = _getEnv('FLAGSMITH_ENVIRONMENT_KEY', _defaultEnvKey);
    final url = Uri.parse('$cleanBaseUrl/api/v1/events/');

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final events = List.generate(count, (index) => {
      'event': eventName,
      'feature_name': 'cta_button',
      'identifier': _sessionId,
      'timestamp': nowMs + index,
      'value': value,
    });

    try {
      await http.post(
        url,
        headers: {
          'X-Environment-Key': envKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'events': events}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _logClickEvent({int count = 1}) async {
    setState(() {
      _clickCount += count;
    });

    // Send real experimentation event directly to self-hosted Flagsmith API
    await _sendFlagsmithEvent(
      eventName: 'cta_clicked',
      value: _activeVariant,
      count: count,
    );

    if (mounted && count == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Event "cta_clicked" logged for [$_activeVariant]! (Total: $_clickCount)'),
          backgroundColor: _activeVariant == 'variant_a' ? Colors.blue[700] : Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _simulate50Clicks() async {
    setState(() {
      _isSimulating = true;
    });

    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _logClickEvent(count: 10);
    }

    if (mounted) {
      setState(() {
        _isSimulating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Simulated 50 conversion clicks! Bayesian win probabilities updated.'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVariantA = _activeVariant == 'variant_a';
    final buttonColor = isVariantA ? const Color(0xFF2563EB) : const Color(0xFF10B981);
    final buttonText = isVariantA ? 'Get Started' : 'Try for Free';
    final buttonIcon = isVariantA ? Icons.arrow_forward_rounded : Icons.bolt_rounded;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'FlagForge',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v0.1.0 Demo',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
            tooltip: 'Refresh Flags',
            onPressed: _fetchVariant,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF312E81),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF4338CA)),
                              ),
                              child: const Text(
                                '✨ Model Context Protocol + Flagsmith Experimentation',
                                style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Ship Features with AI Agents,\nBacked by Bayesian A/B Testing',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Automate multivariate feature rollout directly inside Claude Code or Cursor. Let autonomous agents evaluate live conversion statistics and ship winning variants with 100% confidence.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF94A3B8),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Distinct Visual Elements per Variant
                            if (!isVariantA)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF065F46),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      '⭐ MOST POPULAR • 14-Day Free Trial',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E3A8A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF3B82F6)),
                                ),
                                child: const Text(
                                  'Standard Edition • Direct Access',
                                  style: TextStyle(
                                    color: Color(0xFFBFDBFE),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                            // Multivariate CTA Button
                            ElevatedButton.icon(
                              onPressed: () => _logClickEvent(count: 1),
                              icon: Icon(buttonIcon, color: Colors.white, size: 22),
                              label: Text(
                                buttonText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                shadowColor: buttonColor.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVariantA
                                  ? 'Standard onboarding flow • Click to fire metric "cta_clicked"'
                                  : '🔥 High-converting variant • Click to fire metric "cta_clicked"',
                              style: TextStyle(
                                fontSize: 12,
                                color: isVariantA ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6EE7B7),
                                fontWeight: isVariantA ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Feature Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFeatureCard(
                              icon: Icons.psychology_rounded,
                              title: 'AI Agent Driven',
                              description:
                                  'Claude Code & Cursor seamlessly manage flags and experiments via native MCP tools.',
                            ),
                            const SizedBox(width: 24),
                            _buildFeatureCard(
                              icon: Icons.analytics_rounded,
                              title: 'Bayesian Statistics',
                              description:
                                  'Continuous Monte Carlo win probability ensures mathematically sound rollout decisions.',
                            ),
                            const SizedBox(width: 24),
                            _buildFeatureCard(
                              icon: Icons.rocket_launch_rounded,
                              title: 'Auto-Ship Winners',
                              description:
                                  'One agent prompt reallocates 100% traffic to the highest-converting variant.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Debug Panel (Always accessible in demo)
                  Container(
                    margin: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(maxWidth: 900),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bug_report_rounded, color: Color(0xFFF59E0B), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'FlagForge Live Debug Panel',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusMessage,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF334155), height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildDebugBadge('Current Variant', _activeVariant, isVariantA ? Colors.blue : Colors.green),
                            _buildDebugBadge('Session ID', _sessionId, Colors.grey),
                            _buildDebugBadge('Total Clicks Logged', '$_clickCount', Colors.purple),
                            
                            // Switch variant preview
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text('Switch Variant:', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'variant_a', label: Text('Variant A (Blue)')),
                                    ButtonSegment(value: 'variant_b', label: Text('Variant B (Green)')),
                                  ],
                                  selected: {_activeVariant},
                                  onSelectionChanged: (set) {
                                    setState(() {
                                      _activeVariant = set.first;
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Simulate 50 clicks button
                            ElevatedButton.icon(
                              onPressed: _isSimulating ? null : _simulate50Clicks,
                              icon: _isSimulating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.flash_on_rounded, size: 18),
                              label: Text(_isSimulating ? 'Simulating...' : 'Simulate 50 Clicks'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF312E81),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFA5B4FC), size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}
