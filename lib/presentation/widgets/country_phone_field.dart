import 'package:flutter/material.dart';

import '../../utils/validators.dart';

class CountryPhoneField extends StatelessWidget {
  const CountryPhoneField({
    super.key,
    required this.controller,
    required this.dialCode,
    required this.onDialCodeChanged,
    this.labelText = 'Phone number',
    this.required = true,
  });

  final TextEditingController controller;
  final String dialCode;
  final ValueChanged<String> onDialCodeChanged;
  final String labelText;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final selectedCountry = AppValidators.phoneCountryForDialCode(dialCode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: DropdownButtonFormField<String>(
            value: selectedCountry.dialCode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Code'),
            selectedItemBuilder: (context) {
              return [
                for (final country in AppValidators.phoneCountries)
                  Text(
                    country.label,
                    overflow: TextOverflow.ellipsis,
                  ),
              ];
            },
            items: [
              for (final country in AppValidators.phoneCountries)
                DropdownMenuItem(
                  value: country.dialCode,
                  child: Text(
                    country.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onDialCodeChanged(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            validator: (value) => AppValidators.phoneForCountry(
              value ?? '',
              dialCode: selectedCountry.dialCode,
              required: required,
            ),
            decoration: InputDecoration(
              labelText: labelText,
              hintText: selectedCountry.example,
            ),
          ),
        ),
      ],
    );
  }
}
