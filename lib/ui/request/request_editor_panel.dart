import 'package:flutter/material.dart';

import '../../core/models/api_request.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../widgets/widgets.dart';

enum _EditorTab { params, headers, body, auth, description }

/// Params / Headers / Body / Auth / Description sub-editors for a request draft.
class RequestEditorPanel extends StatefulWidget {
  const RequestEditorPanel({super.key, required this.request, required this.onChanged});

  final ApiRequest request;
  final ValueChanged<ApiRequest> onChanged;

  @override
  State<RequestEditorPanel> createState() => _RequestEditorPanelState();
}

class _RequestEditorPanelState extends State<RequestEditorPanel> {
  _EditorTab _tab = _EditorTab.params;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
          child: Row(
            children: [
              for (final tab in _EditorTab.values) _TabButton(label: _labelFor(tab), selected: _tab == tab, onTap: () => setState(() => _tab = tab)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SingleChildScrollView(child: _buildTabContent()),
          ),
        ),
      ],
    );
  }

  String _labelFor(_EditorTab tab) {
    switch (tab) {
      case _EditorTab.params:
        final count = widget.request.queryParams.length;
        return count == 0 ? 'Params' : 'Params ($count)';
      case _EditorTab.headers:
        final count = widget.request.headers.length;
        return count == 0 ? 'Headers' : 'Headers ($count)';
      case _EditorTab.body:
        return 'Body';
      case _EditorTab.auth:
        return 'Auth';
      case _EditorTab.description:
        return 'Description';
    }
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case _EditorTab.params:
        return KeyValueEditor(
          key: ValueKey('params-${widget.request.id}'),
          initial: widget.request.queryParams,
          keyHint: 'Param',
          onChanged: (v) => widget.onChanged(widget.request.copyWith(queryParams: v)),
        );
      case _EditorTab.headers:
        return KeyValueEditor(
          key: ValueKey('headers-${widget.request.id}'),
          initial: widget.request.headers,
          keyHint: 'Header',
          onChanged: (v) => widget.onChanged(widget.request.copyWith(headers: v)),
        );
      case _EditorTab.body:
        return _BodyEditor(request: widget.request, onChanged: widget.onChanged);
      case _EditorTab.auth:
        return _AuthEditor(request: widget.request, onChanged: widget.onChanged);
      case _EditorTab.description:
        return TextFormField(
          key: ValueKey('desc-${widget.request.id}'),
          initialValue: widget.request.description ?? '',
          minLines: 4,
          maxLines: 12,
          style: context.type.body,
          decoration: const InputDecoration(hintText: 'What does this request do?'),
          onChanged: (v) => widget.onChanged(widget.request.copyWith(description: v)),
        );
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? colors.accent : Colors.transparent, width: 2))),
        child: Text(label, style: context.type.label.copyWith(color: selected ? colors.textPrimary : colors.textMuted)),
      ),
    );
  }
}

class _BodyEditor extends StatelessWidget {
  const _BodyEditor({required this.request, required this.onChanged});

  final ApiRequest request;
  final ValueChanged<ApiRequest> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<BodyType>(
          value: request.bodyType,
          items: BodyType.values,
          itemLabel: (t) => t.label,
          onChanged: (t) => onChanged(request.copyWith(bodyType: t)),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (request.bodyType) {
          BodyType.none => Text('This request has no body.', style: context.type.caption),
          BodyType.raw || BodyType.binary => TextFormField(
            key: ValueKey('body-${request.id}'),
            initialValue: request.body ?? '',
            minLines: 10,
            maxLines: 24,
            style: context.type.mono,
            decoration: const InputDecoration(hintText: '{\n  "key": "value"\n}'),
            onChanged: (v) => onChanged(request.copyWith(body: v)),
          ),
          BodyType.formData || BodyType.urlEncoded => KeyValueEditor(
            key: ValueKey('form-${request.id}'),
            initial: request.formFields,
            onChanged: (v) => onChanged(request.copyWith(formFields: v)),
          ),
        },
      ],
    );
  }
}

class _AuthEditor extends StatelessWidget {
  const _AuthEditor({required this.request, required this.onChanged});

  final ApiRequest request;
  final ValueChanged<ApiRequest> onChanged;

  void _setConfig(String key, String value) {
    onChanged(request.copyWith(authConfig: {...request.authConfig, key: value}));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<AuthType>(
          value: request.authType,
          items: AuthType.values,
          itemLabel: (t) => t.label,
          onChanged: (t) => onChanged(request.copyWith(authType: t)),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (request.authType) {
          AuthType.none => Text('No authentication for this request.', style: context.type.caption),
          AuthType.bearer => LabeledField(
            label: 'Token',
            child: _AuthField(
              initial: request.authConfig[AuthConfigKeys.token] ?? '',
              onChanged: (v) => _setConfig(AuthConfigKeys.token, v),
            ),
          ),
          AuthType.basic => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledField(
                label: 'Username',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.username] ?? '',
                  onChanged: (v) => _setConfig(AuthConfigKeys.username, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Password',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.password] ?? '',
                  obscure: true,
                  onChanged: (v) => _setConfig(AuthConfigKeys.password, v),
                ),
              ),
            ],
          ),
          AuthType.apiKey => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledField(
                label: 'Key',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.key] ?? '',
                  onChanged: (v) => _setConfig(AuthConfigKeys.key, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Value',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.value] ?? '',
                  onChanged: (v) => _setConfig(AuthConfigKeys.value, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Add to',
                child: AppDropdown<String>(
                  value: request.authConfig[AuthConfigKeys.addTo] ?? 'header',
                  items: const ['header', 'query'],
                  itemLabel: (v) => v == 'header' ? 'Header' : 'Query Param',
                  onChanged: (v) => _setConfig(AuthConfigKeys.addTo, v),
                ),
              ),
            ],
          ),
        },
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({required this.initial, required this.onChanged, this.obscure = false});

  final String initial;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.controlHeight,
      child: TextFormField(
        initialValue: initial,
        obscureText: obscure,
        style: context.type.mono.copyWith(fontSize: 13),
        decoration: const InputDecoration(isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}
