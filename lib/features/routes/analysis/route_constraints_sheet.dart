import 'package:flutter/material.dart';

import '../../../core/models/route_constraints.dart';
import '../route_editor_controller.dart';

Future<void> showRouteConstraints(
  BuildContext context,
  RouteEditorController editor,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _Constraints(editor: editor),
);

class _Constraints extends StatefulWidget {
  const _Constraints({required this.editor});
  final RouteEditorController editor;
  @override
  State<_Constraints> createState() => _ConstraintsState();
}

class _ConstraintsState extends State<_Constraints> {
  final _form = GlobalKey<FormState>();
  late final _initial = widget.editor.planning.constraints;
  late final _legal = TextEditingController(
    text: _initial.legalCeilingAgl?.toString() ?? '',
  );
  late final _operational = TextEditingController(
    text: _initial.operationalCeilingAgl?.toString() ?? '',
  );
  late final _radius = TextEditingController(
    text: _initial.planningRadiusMeters?.toString() ?? '',
  );
  late RouteVisibilityMode _visibility = _initial.visibility;
  @override
  void dispose() {
    _legal.dispose();
    _operational.dispose();
    _radius.dispose();
    super.dispose();
  }

  double? value(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));
  Widget field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Empty means unverified / not configured.',
      ),
      validator: (v) => v!.trim().isEmpty
          ? null
          : value(c) == null ||
                !value(c)!.isFinite ||
                value(c)! < 0 ||
                value(c)! > 100000
          ? 'Enter 0–100000 metres.'
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route constraints',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'The default 120 m AGL ceiling is a Swiss open-category planning reference. '
              'A configured value does not establish the applicable law, an exemption or authorisation. '
              'Vertical AGL samples do not evaluate distance to the nearest terrain surface on steep slopes.',
            ),
            const SizedBox(height: 16),
            field(_legal, 'Configured legal ceiling (m AGL)'),
            field(_operational, 'Operational ceiling (m AGL)'),
            field(_radius, 'Planning radius from waypoint 1 (m)'),
            DropdownButtonFormField<RouteVisibilityMode>(
              initialValue: _visibility,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Planned visibility scenario',
              ),
              items: RouteVisibilityMode.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(switch (v) {
                        RouteVisibilityMode.unverified => 'Unverified',
                        RouteVisibilityMode.vlos => 'VLOS',
                        RouteVisibilityMode.fpvWithObserver =>
                          'FPV with observer',
                        RouteVisibilityMode.bvlos => 'BVLOS',
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _visibility = v!),
            ),
            const SizedBox(height: 16),
            const Text(
              'A planning radius is not a VLOS limit. Visibility, aircraft orientation, observers, '
              'people, pilot qualifications, local restrictions and approvals require manual verification.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                widget.editor.configurePlanning(
                  widget.editor.planning.withConstraints(
                    RouteConstraints(
                      legalCeilingAgl: value(_legal),
                      operationalCeilingAgl: value(_operational),
                      planningRadiusMeters: value(_radius),
                      visibility: _visibility,
                    ),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Apply route constraints'),
            ),
          ],
        ),
      ),
    ),
  );
}
