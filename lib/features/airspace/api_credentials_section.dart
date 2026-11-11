import 'package:flutter/foundation.dart';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/osint/api_access_policy.dart';
import '../../core/osint/api_credential_vault.dart';

/// A section for future officially verified, free-key APIs. Sources that are
/// paid, unverified, or need no key never receive a credential input.
class ApiCredentialsSection extends StatelessWidget {
  const ApiCredentialsSection({super.key, required this.policies, this.vault});
  final List<ApiAccessPolicy> policies;
  final ApiCredentialVault? vault;

  @override
  Widget build(BuildContext context) {
    final eligible = policies.where((policy) => policy.allowsUserKey).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.translate("API access (free services only)"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (eligible.isEmpty)
          Text(
            context.translate(
              "No supported airspace provider currently needs a freely obtainable API key. BAZL works without one; Skyguide NOTAM access is not verified as free.",
            ),
          ),
        if (eligible.isNotEmpty) ...[
          Text(
            kIsWeb
                ? context.translate(
                    "Keys are kept for this browser session only and disappear after reload.",
                  )
                : context.translate(
                    "Keys are stored locally using encrypted OS-backed storage, not app preferences.",
                  ),
          ),
          for (final policy in eligible)
            _CredentialEditor(
              policy: policy,
              vault: vault ?? LocalApiCredentialVault.shared,
            ),
        ],
      ],
    );
  }
}

class _CredentialEditor extends StatefulWidget {
  const _CredentialEditor({required this.policy, required this.vault});
  final ApiAccessPolicy policy;
  final ApiCredentialVault vault;
  @override
  State<_CredentialEditor> createState() => _CredentialEditorState();
}

class _CredentialEditorState extends State<_CredentialEditor> {
  final _key = TextEditingController();
  bool _saved = false, _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _key.addListener(_notifyInputChanged);
    _refresh();
  }

  void _notifyInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final saved = await widget.vault.contains(widget.policy);
      if (mounted) {
        setState(() {
          _saved = saved;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Secure storage is unavailable';
        });
      }
    }
  }

  Future<void> _mutate({required bool remove}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (remove) {
        await widget.vault.remove(widget.policy);
      } else {
        await widget.vault.save(widget.policy, _key.text);
      }
      _key.clear();
      if (mounted) {
        setState(() {
          _saved = !remove;
          _loading = false;
        });
      }
    } catch (_) {
      // Avoid displaying error.toString(): platform failures can contain keys.
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not update this API key';
        });
      }
    }
  }

  @override
  void dispose() {
    _key.removeListener(_notifyInputChanged);
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(widget.policy.name, style: Theme.of(context).textTheme.labelLarge),
      Text(
        _saved
            ? context.translate("Key configured")
            : context.translate("No key configured"),
      ),
      TextField(
        controller: _key,
        obscureText: true,
        maxLength: 4096,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: context.translate("API key"),
          helperText: context.translate(
            "Leave existing key unchanged by keeping this empty",
          ),
        ),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _loading || _key.text.trim().isEmpty
                ? null
                : () => _mutate(remove: false),
            child: Text(context.translate("Save key")),
          ),
          TextButton(
            onPressed: _loading || !_saved ? null : () => _mutate(remove: true),
            child: Text(context.translate("Remove key")),
          ),
          TextButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    try {
                      await launchUrl(
                        widget.policy.registrationUri!,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      /* The site is separately given in the source policy. */
                    }
                  },
            icon: const Icon(Icons.open_in_new),
            label: Text(context.translate("Get free API key")),
          ),
        ],
      ),
    ],
  );
}
