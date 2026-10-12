import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/offline/attachment_cache_service.dart';
import '../../state/trip_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _defaultServerBaseUrl =
      'https://trippy-mcp-server-392329008088.us-central1.run.app';

  String _hashPat(String rawToken) {
    return sha256.convert(utf8.encode(rawToken.trim())).toString();
  }

  String _generateSecurePat() {
    final randomBytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final tokenHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'trippy_pat_$tokenHex';
  }

  Future<void> _showCreateTokenDialog(BuildContext context, String userId, String? userEmail) async {
    final nameController = TextEditingController(text: 'AI Assistant');
    bool isGenerating = false;

    await showDialog(
      context: context,
      barrierDismissible: !isGenerating,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.key_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Text('Generate Access Token'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a Personal Access Token to connect external AI assistants (Grok Bot, Gemini, ChatGPT Actions, Claude Desktop) to your Trippy trips.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    enabled: !isGenerating,
                    decoration: const InputDecoration(
                      labelText: 'Token Label / Assistant Name',
                      hintText: 'e.g. Grok Bot, Gemini Studio, Claude Desktop',
                      prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Impersonation Protection: This token is cryptographically bound strictly to your account. No other user can access your trips.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isGenerating
                    ? null
                    : () async {
                        final tokenName = nameController.text.trim().isEmpty
                            ? 'AI Assistant'
                            : nameController.text.trim();

                        setDialogState(() => isGenerating = true);

                        final rawToken = _generateSecurePat();
                        final tokenHash = _hashPat(rawToken);
                        final prefix = rawToken.length > 15
                            ? '${rawToken.substring(0, 14)}...'
                            : rawToken;
                        final nowIso = DateTime.now().toUtc().toIso8601String();

                        try {
                          await FirebaseFirestore.instance
                              .collection('mcp_api_keys')
                              .doc(tokenHash)
                              .set({
                            'userId': userId,
                            'userEmail': userEmail ?? '',
                            'name': tokenName,
                            'tokenPrefix': prefix,
                            'createdAt': nowIso,
                            'lastUsedAt': nowIso,
                            'enabled': true,
                          });

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }

                          if (context.mounted) {
                            _showTokenGeneratedSuccessDialog(context, tokenName, rawToken);
                          }
                        } catch (e) {
                          setDialogState(() => isGenerating = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text('Failed to generate token: $e'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                icon: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Generate Token'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTokenGeneratedSuccessDialog(
    BuildContext context,
    String tokenName,
    String rawToken,
  ) {
    final mcpPostUrl = '$_defaultServerBaseUrl/mcp?key=$rawToken';
    final sseUrl = '$_defaultServerBaseUrl/sse?key=$rawToken';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Personal Access Token Created',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Make sure to copy your token now. For your security, you will not be able to view it again after closing this window!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Token Raw Box
                Text(
                  'TOKEN: $tokenName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          rawToken,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Token',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rawToken));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Token copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Ready-to-use URL for Grok Bot, Gemini, ChatGPT
                const Text(
                  'MCP ENDPOINT URL (Grok Bot, Gemini, ChatGPT Actions)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          mcpPostUrl,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy MCP URL',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: mcpPostUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('MCP URL copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Ready-to-use SSE URL for Claude Desktop / Cursor
                const Text(
                  'SERVER-SENT EVENTS (SSE) URL (Claude Desktop, Cursor)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          sseUrl,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy SSE URL',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: sseUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SSE URL copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Have Saved My Token'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteToken(BuildContext context, String docId, String tokenName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Revoke Access Token?'),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke "$tokenName"?\n\n'
          'Any AI assistants (such as Grok Bot, Gemini, or Claude) using this token will lose access to Trippy immediately.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Revoke Token'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('mcp_api_keys').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Token "$tokenName" was successfully revoked.'),
              backgroundColor: Colors.grey.shade900,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to revoke token: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section 1: User Account Card
          _buildUserCard(context, ref, user),
          const SizedBox(height: 24),

          // Section 2: Personal Access Tokens (AI Assistants)
          _buildPatSection(context, user),
          const SizedBox(height: 24),

          // Section 3: AI Assistant Setup Guides
          _buildAssistantGuideCard(context),
          const SizedBox(height: 24),

          // Section 4: Offline Storage & Attachment Cache
          _buildOfflineStorageCard(context),
          const SizedBox(height: 24),

          // Section 5: App Info
          _buildAppInfoCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, WidgetRef ref, dynamic user) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                          (user?.displayName?.isNotEmpty == true
                                  ? user!.displayName![0]
                                  : user?.isAnonymous == true
                                      ? 'G'
                                      : 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ??
                            (user?.isAnonymous == true
                                ? 'Guest User'
                                : user == null
                                    ? 'Not Signed In'
                                    : 'Authenticated User'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.email!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (user != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'UID: ${user.uid}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textMuted,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                              tooltip: 'Copy UID',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: user.uid));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('UID copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user == null || user.isAnonymous == true)
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await ref.read(authServiceProvider).signInWithGoogle();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign-in failed: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(user?.isAnonymous == true
                        ? 'Upgrade with Google'
                        : 'Sign In with Google'),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sign Out'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatSection(BuildContext context, dynamic user) {
    final isGuest = user == null || user.isAnonymous == true;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Access Tokens (AI Assistants)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Model Context Protocol (MCP) integrations',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isGuest)
                  FilledButton.icon(
                    onPressed: () => _showCreateTokenDialog(context, user.uid, user.email),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Generate Token'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Personal Access Tokens allow AI chatbots (such as Grok Bot, Gemini, ChatGPT Actions, and Claude Desktop) '
              'to view, add, and organize your trips on your behalf via the Trippy MCP Server.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (isGuest) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Sign in with Google to generate and manage Personal Access Tokens for AI assistants.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Live Stream of MCP Tokens from Firestore
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('mcp_api_keys')
                    .where('userId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Failed to load tokens: ${snapshot.error}',
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.vpn_key_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text(
                            'No Personal Access Tokens Yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Click "Generate Token" above to connect Grok Bot, Gemini, or Claude Desktop.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort client-side by createdAt descending
                  final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
                    ..sort((a, b) {
                      final aTime = a.data()['createdAt'] as String? ?? '';
                      final bTime = b.data()['createdAt'] as String? ?? '';
                      return bTime.compareTo(aTime);
                    });

                  return Column(
                    children: sortedDocs.map((doc) {
                      final data = doc.data();
                      final tokenName = data['name'] as String? ?? 'AI Assistant';
                      final prefix = data['tokenPrefix'] as String? ?? 'trippy_pat_...';
                      final createdAt = data['createdAt'] as String?;
                      final formattedDate = createdAt != null
                          ? DateTime.tryParse(createdAt)?.toLocal().toString().split('.').first ??
                              createdAt
                          : 'Unknown';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.key_rounded,
                                  color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        tokenName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Prefix: $prefix • Created: $formattedDate',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Revoke Token',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 20),
                              onPressed: () => _confirmDeleteToken(context, doc.id, tokenName),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantGuideCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
        title: const Text(
          'How to Connect AI Assistants',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: const Text(
          'Quick instructions for Grok Bot, Gemini, ChatGPT, Claude',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: const [
          Divider(),
          SizedBox(height: 8),
          _GuideStep(
            botName: 'Grok Bot (X / Twitter)',
            instructions:
                '1. Generate a token above.\n'
                '2. In Grok Bot settings, add MCP Server URL:\n'
                '   https://trippy-mcp-server-392329008088.us-central1.run.app/mcp?key=<your_token>\n'
                '3. Ask Grok: "Show me my trips on Trippy" or "Add dinner reservation at 7pm".',
          ),
          SizedBox(height: 12),
          _GuideStep(
            botName: 'Gemini / Google AI Studio',
            instructions:
                '1. In Google AI Studio or Gemini tool configurations, register the Streamable HTTP endpoint.\n'
                '2. Pass your Personal Access Token in the Authorization header or query parameter ?key=...',
          ),
          SizedBox(height: 12),
          _GuideStep(
            botName: 'Claude Desktop / Cursor',
            instructions:
                '1. Open your Claude Desktop / Cursor config file.\n'
                '2. Add the SSE URL under "mcpServers":\n'
                '   "trippy": { "url": "https://trippy-mcp-server-392329008088.us-central1.run.app/sse?key=<your_token>" }',
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineStorageCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.offline_pin_rounded,
                      color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Travel Storage',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        'Manage cached trips, stays, flights, and files',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_zip_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Trip data and files are automatically cached locally when viewed or downloaded.',
                      style: TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Offline Storage?'),
                        content: const Text(
                          'This will clear all locally cached attachment files. '
                          'Your trips will remain safely stored in the cloud.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await AttachmentCacheService().clearAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline attachment cache cleared.'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Clear File Cache'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.luggage_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Trippy Itinerary Planner',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Spacer(),
                Text('v1.0.0+9',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Cross-platform collaborative travel planning with multi-day stays, flight logistics, day timelines, and Model Context Protocol AI bot integration.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String botName;
  final String instructions;

  const _GuideStep({required this.botName, required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(botName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          SelectableText(
            instructions,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
