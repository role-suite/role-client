import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/api_request.dart';
import '../../core/models/enums.dart';
import '../../core/models/key_value_entry.dart';
import '../../core/models/request_body.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../widgets/widgets.dart';

/// Warn once an encoded form-data/binary payload nears role-node's overall
/// request body cap — overflow currently surfaces as a bare 500, not a clean
/// 413 (role-node/docs/guides/client-integration.md).
const _largePayloadWarningBytes = 700 * 1024;

enum _BodyKind { none, raw, urlEncoded, formData, binary }

extension on _BodyKind {
  String get label => switch (this) {
    _BodyKind.none => 'None',
    _BodyKind.raw => 'Raw',
    _BodyKind.urlEncoded => 'URL-encoded',
    _BodyKind.formData => 'Form Data',
    _BodyKind.binary => 'Binary',
  };
}

_BodyKind _kindOf(RequestBody body) => switch (body) {
  NoneBody() => _BodyKind.none,
  RawBody() => _BodyKind.raw,
  UrlEncodedBody() => _BodyKind.urlEncoded,
  FormDataBody() => _BodyKind.formData,
  BinaryBody() => _BodyKind.binary,
};

enum _EditorTab { params, headers, body, auth, tests, description }

/// Params / Headers / Body / Auth / Description sub-editors for a request draft.
class RequestEditorPanel extends StatefulWidget {
  const RequestEditorPanel({super.key, required this.request, required this.onChanged, this.enabled = true});

  final ApiRequest request;
  final ValueChanged<ApiRequest> onChanged;
  final bool enabled;

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
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
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
      case _EditorTab.tests:
        final count = widget.request.assertions.length;
        return count == 0 ? 'Tests' : 'Tests ($count)';
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
          enabled: widget.enabled,
          onChanged: (v) => widget.onChanged(widget.request.copyWith(queryParams: v)),
        );
      case _EditorTab.headers:
        return KeyValueEditor(
          key: ValueKey('headers-${widget.request.id}'),
          initial: widget.request.headers,
          keyHint: 'Header',
          enabled: widget.enabled,
          onChanged: (v) => widget.onChanged(widget.request.copyWith(headers: v)),
        );
      case _EditorTab.body:
        return _BodyEditor(request: widget.request, enabled: widget.enabled, onChanged: widget.onChanged);
      case _EditorTab.auth:
        return _AuthEditor(request: widget.request, enabled: widget.enabled, onChanged: widget.onChanged);
      case _EditorTab.tests:
        return AssertionsEditor(
          key: ValueKey('tests-${widget.request.id}'),
          initial: widget.request.assertions,
          onChanged: widget.enabled ? (v) => widget.onChanged(widget.request.copyWith(assertions: v)) : (_) {},
        );
      case _EditorTab.description:
        return TextFormField(
          key: ValueKey('desc-${widget.request.id}'),
          initialValue: widget.request.description ?? '',
          enabled: widget.enabled,
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? colors.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: context.type.label.copyWith(color: selected ? colors.textPrimary : colors.textMuted)),
      ),
    );
  }
}

class _BodyEditor extends StatelessWidget {
  const _BodyEditor({required this.request, required this.enabled, required this.onChanged});

  final ApiRequest request;
  final bool enabled;
  final ValueChanged<ApiRequest> onChanged;

  void _changeKind(_BodyKind kind) {
    final next = switch (kind) {
      _BodyKind.none => const NoneBody(),
      _BodyKind.raw => const RawBody(),
      _BodyKind.urlEncoded => const UrlEncodedBody(),
      _BodyKind.formData => const FormDataBody(),
      _BodyKind.binary => const BinaryBody(),
    };
    onChanged(request.copyWith(requestBody: next));
  }

  @override
  Widget build(BuildContext context) {
    final body = request.requestBody;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<_BodyKind>(value: _kindOf(body), items: _BodyKind.values, itemLabel: (k) => k.label, onChanged: enabled ? _changeKind : null),
        const SizedBox(height: AppSpacing.md),
        switch (body) {
          NoneBody() => Text('This request has no body.', style: context.type.caption),
          RawBody(:final raw) => TextFormField(
            key: ValueKey('body-${request.id}'),
            initialValue: raw,
            enabled: enabled,
            minLines: 10,
            maxLines: 24,
            style: context.type.mono,
            decoration: const InputDecoration(hintText: '{\n  "key": "value"\n}'),
            onChanged: (v) => onChanged(
              request.copyWith(
                requestBody: RawBody(contentType: body.contentType, raw: v),
              ),
            ),
          ),
          UrlEncodedBody(:final entries) => KeyValueEditor(
            key: ValueKey('urlencoded-${request.id}'),
            initial: entries,
            enabled: enabled,
            onChanged: (v) => onChanged(request.copyWith(requestBody: UrlEncodedBody(entries: v))),
          ),
          FormDataBody(:final parts) => _FormDataEditor(
            key: ValueKey('formdata-${request.id}'),
            parts: parts,
            enabled: enabled,
            onChanged: (v) => onChanged(request.copyWith(requestBody: FormDataBody(parts: v))),
          ),
          BinaryBody() => _BinaryEditor(
            key: ValueKey('binary-${request.id}'),
            body: body,
            enabled: enabled,
            onChanged: (v) => onChanged(request.copyWith(requestBody: v)),
          ),
        },
      ],
    );
  }
}

/// Text/file rows for a [FormDataBody]. File parts are added via the file
/// picker (already a dependency, used by workspace import/export) and stored
/// base64-encoded, matching role-node's `endpointBodySchema`.
class _FormDataEditor extends StatelessWidget {
  const _FormDataEditor({super.key, required this.parts, required this.enabled, required this.onChanged});

  final List<FormPart> parts;
  final bool enabled;
  final ValueChanged<List<FormPart>> onChanged;

  Future<void> _addFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final dataBase64 = base64Encode(file.bytes!);
    if (dataBase64.length > _largePayloadWarningBytes && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${file.name}" is large — role-node may reject it (over its request body limit).')));
    }

    onChanged([...parts, FormFilePart(key: file.name, fileName: file.name, dataBase64: dataBase64)]);
  }

  @override
  Widget build(BuildContext context) {
    final textEntries = [
      for (final p in parts)
        if (p is FormTextPart) KeyValueEntry(key: p.key, value: p.value, enabled: p.enabled),
    ];
    final filePartsList = parts.whereType<FormFilePart>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyValueEditor(
          initial: textEntries,
          keyHint: 'Field',
          enabled: enabled,
          onChanged: (updated) {
            final next = [...updated.map((e) => FormTextPart(key: e.key, value: e.value, enabled: e.enabled)), ...filePartsList];
            onChanged(next);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final filePart in filePartsList)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(filePart.fileName, style: context.type.monoSmall)),
                AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Remove',
                  onPressed: enabled ? () => onChanged([...parts.where((p) => p != filePart)]) : null,
                ),
              ],
            ),
          ),
        AppButton(
          label: 'Add file',
          icon: Icons.attach_file,
          variant: AppButtonVariant.secondary,
          onPressed: enabled ? () => _addFile(context) : null,
        ),
      ],
    );
  }
}

class _BinaryEditor extends StatelessWidget {
  const _BinaryEditor({super.key, required this.body, required this.enabled, required this.onChanged});

  final BinaryBody body;
  final bool enabled;
  final ValueChanged<RequestBody> onChanged;

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final dataBase64 = base64Encode(file.bytes!);
    if (dataBase64.length > _largePayloadWarningBytes && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${file.name}" is large — role-node may reject it (over its request body limit).')));
    }

    onChanged(BinaryBody(fileName: file.name, contentType: body.contentType, dataBase64: dataBase64));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(body.fileName ?? 'No file selected.', style: body.fileName == null ? context.type.caption : context.type.monoSmall)),
        AppButton(
          label: 'Choose file',
          icon: Icons.attach_file,
          variant: AppButtonVariant.secondary,
          onPressed: enabled ? () => _pickFile(context) : null,
        ),
      ],
    );
  }
}

class _AuthEditor extends StatelessWidget {
  const _AuthEditor({required this.request, required this.enabled, required this.onChanged});

  final ApiRequest request;
  final bool enabled;
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
          onChanged: enabled ? (t) => onChanged(request.copyWith(authType: t)) : null,
        ),
        const SizedBox(height: AppSpacing.md),
        switch (request.authType) {
          AuthType.none => Text('No authentication for this request.', style: context.type.caption),
          AuthType.bearer => LabeledField(
            label: 'Token',
            child: _AuthField(
              initial: request.authConfig[AuthConfigKeys.token] ?? '',
              enabled: enabled,
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
                  enabled: enabled,
                  onChanged: (v) => _setConfig(AuthConfigKeys.username, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Password',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.password] ?? '',
                  enabled: enabled,
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
                  enabled: enabled,
                  onChanged: (v) => _setConfig(AuthConfigKeys.key, v),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Value',
                child: _AuthField(
                  initial: request.authConfig[AuthConfigKeys.value] ?? '',
                  enabled: enabled,
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
                  onChanged: enabled ? (v) => _setConfig(AuthConfigKeys.addTo, v) : null,
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
  const _AuthField({required this.initial, required this.enabled, required this.onChanged, this.obscure = false});

  final String initial;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.controlHeight,
      child: TextFormField(
        initialValue: initial,
        enabled: enabled,
        obscureText: obscure,
        style: context.type.mono.copyWith(fontSize: 13),
        decoration: const InputDecoration(isDense: true),
        onChanged: onChanged,
      ),
    );
  }
}
