import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../utils/validators.dart';

class CountryPhoneField extends StatelessWidget {
  const CountryPhoneField({
    super.key,
    required this.controller,
    required this.dialCode,
    required this.onDialCodeChanged,
    this.labelText = 'Phone number',
    this.required = true,
    this.externalLabels = false,
    this.codeLabel = 'Code',
    this.enabled = true,
  });

  final TextEditingController controller;
  final String dialCode;
  final ValueChanged<String> onDialCodeChanged;
  final String labelText;
  final bool required;
  final bool externalLabels;
  final String codeLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedCountry = AppValidators.phoneCountryForDialCode(dialCode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: externalLabels ? 94 : 122,
          child: _PhoneFieldShell(
            label: externalLabels ? codeLabel : null,
            child: DropdownButtonFormField<String>(
              initialValue: selectedCountry.dialCode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: externalLabels ? null : codeLabel,
                hintText: externalLabels ? '+60' : null,
              ),
              selectedItemBuilder: (context) {
                return [
                  for (final country in AppValidators.phoneCountries)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        externalLabels ? country.dialCode : country.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ];
              },
              items: [
                for (final country in AppValidators.phoneCountries)
                  DropdownMenuItem(
                    value: country.dialCode,
                    child: Text(
                      country.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: !enabled
                  ? null
                  : (value) {
                      if (value == null) return;
                      onDialCodeChanged(value);
                    },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhoneFieldShell(
            label: externalLabels ? labelText : null,
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              validator: (value) => AppValidators.phoneForCountry(
                value ?? '',
                dialCode: selectedCountry.dialCode,
                required: required,
              ),
              decoration: InputDecoration(
                labelText: externalLabels ? null : labelText,
                hintText: selectedCountry.example,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneFieldShell extends StatelessWidget {
  const _PhoneFieldShell({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
