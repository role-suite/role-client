import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';

/// Dialog to set API base URL and optional API key for the remote workspace.
class DataSourceConfigDialog extends ConsumerStatefulWidget {
  const DataSourceConfigDialog({super.key, this.initialConfig});

  final DataSourceConfig? initialConfig;

  @override
  ConsumerState<DataSourceConfigDialog> createState() => _DataSourceConfigDialogState();
}

class _DataSourceConfigDialogState extends ConsumerState<DataSourceConfigDialog> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  ApiStyle _apiStyle = ApiStyle.rest;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _baseUrlController = TextEditingController(text: c?.baseUrl ?? '');
    _apiKeyController = TextEditingController(text: c?.apiKey ?? '');
    _apiStyle = c?.apiStyle ?? ApiStyle.rest;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() => _error = 'Base URL is required');
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      final config = DataSourceConfig(
        baseUrl: baseUrl,
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        apiStyle: _apiStyle,
      );
      await ref.read(dataSourceStateNotifierProvider.notifier).setConfig(config);
      if (!mounted) return;
      ref.invalidate(collectionsNotifierProvider);
      ref.invalidate(requestsNotifierProvider);
      ref.invalidate(environmentsNotifierProvider);
      ref.invalidate(activeEnvironmentNotifierProvider);
      ref.read(selectedCollectionIdProvider.notifier).select('default');
      await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
      ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
      if (!mounted) return;
      Navigator.of(context).pop(config);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('API configuration'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose REST (GET/PUT /workspace) or Serverpod RPC, then enter the server URL.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('API style', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('REST'),
                  selected: _apiStyle == ApiStyle.rest,
                  onSelected: (_) => setState(() => _apiStyle = ApiStyle.rest),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Serverpod RPC'),
                  selected: _apiStyle == ApiStyle.serverpod,
                  onSelected: (_) => setState(() => _apiStyle = ApiStyle.serverpod),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _baseUrlController,
              label: _apiStyle == ApiStyle.serverpod ? 'Server URL' : 'Base URL',
              hint: 'https://api.example.com',
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _apiKeyController,
              label: 'API key (optional)',
              hint: 'Bearer token or key',
              obscureText: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(label: _isSaving ? 'Saving…' : 'Save', onPressed: _isSaving ? null : _save),
      ],
    );
  }
}
