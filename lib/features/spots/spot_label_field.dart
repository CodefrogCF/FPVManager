import 'package:flutter/material.dart';

import '../../core/models/spot_classification.dart';
import 'data/spot_repository.dart';

String? validateSpotLabels(String? value, {bool tags = false}) {
  try {
    if (tags) {
      SpotClassification.parseTags(value ?? '');
    } else {
      SpotClassification(category: value);
    }
    return null;
  } on ArgumentError catch (error) {
    return error.message.toString();
  }
}

/// Suggestions are bounded in SQLite; arbitrary new labels remain editable.
class SpotLabelField extends StatefulWidget {
  const SpotLabelField({
    super.key,
    required this.controller,
    required this.repository,
    this.tags = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final SpotRepository repository;
  final bool tags;
  final bool enabled;

  @override
  State<SpotLabelField> createState() => _SpotLabelFieldState();
}

class _SpotLabelFieldState extends State<SpotLabelField> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    textEditingController: widget.controller,
    focusNode: _focus,
    optionsBuilder: (value) async {
      if (!widget.enabled) return const <String>[];
      final separator = widget.tags ? value.text.lastIndexOf(',') : -1;
      final prefix = value.text.substring(0, separator + 1);
      final term = value.text.substring(separator + 1).trim();
      try {
        final options = widget.tags
            ? await widget.repository.findTags(term)
            : await widget.repository.findCategories(term);
        return options.map(
          (option) => '$prefix${prefix.isEmpty ? '' : ' '}$option',
        );
      } catch (_) {
        // A suggestion failure must not prevent manual entry or saving.
        return const <String>[];
      }
    },
    fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
      controller: controller,
      focusNode: focus,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.tags ? 'Tags' : 'Category',
        helperText: widget.tags
            ? 'Comma separated · up to 10 tags, 32 characters each'
            : 'Optional · up to 40 characters',
        helperMaxLines: 2,
      ),
      validator: (value) => validateSpotLabels(value, tags: widget.tags),
      onFieldSubmitted: (_) => submit(),
    ),
    optionsViewBuilder: (context, select, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(title: Text(option), onTap: () => select(option));
            },
          ),
        ),
      ),
    ),
  );
}
