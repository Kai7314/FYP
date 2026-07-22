import 'package:flutter/material.dart';

import '../../core/constants/malaysia_locations.dart';
import '../../utils/validators.dart';

class MalaysiaAddressFields extends StatelessWidget {
  const MalaysiaAddressFields({
    super.key,
    required this.addressController,
    required this.selectedState,
    required this.selectedRegion,
    required this.onStateChanged,
    required this.onRegionChanged,
    this.addressRequired = false,
    this.addressLabel = 'Home address',
    this.addressHelperText = 'House/unit, street, building, or nearby landmark',
    this.stateLabel = 'State / federal territory',
    this.regionLabel = 'Region / district',
    this.regionHelperText,
    this.externalLabels = false,
    this.addressFieldKey,
  });

  final TextEditingController addressController;
  final String? selectedState;
  final String? selectedRegion;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onRegionChanged;
  final bool addressRequired;
  final String addressLabel;
  final String? addressHelperText;
  final String stateLabel;
  final String regionLabel;
  final String? regionHelperText;
  final bool externalLabels;
  final Key? addressFieldKey;

  @override
  Widget build(BuildContext context) {
    final regions = MalaysiaLocations.regionsFor(selectedState);
    final hasSelectedRegion = regions.any(
      (location) => location.region == selectedRegion,
    );

    return Column(
      children: [
        _AddressFieldShell(
          label: externalLabels ? addressLabel : null,
          child: TextFormField(
            key: addressFieldKey,
            controller: addressController,
            maxLength: AppValidators.maxAddressLength,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                AppValidators.address(value ?? '', required: addressRequired),
            decoration: InputDecoration(
              labelText: externalLabels ? null : addressLabel,
              helperText: addressHelperText,
              hintText: externalLabels
                  ? 'Unit, street, building, or landmark'
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _AddressFieldShell(
          label: externalLabels ? stateLabel : null,
          child: DropdownButtonFormField<String>(
            initialValue: selectedState?.isEmpty == true ? null : selectedState,
            isExpanded: true,
            selectedItemBuilder: (context) => [
              for (final state in MalaysiaLocations.states)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (_) =>
                addressRequired &&
                    (selectedState == null || selectedState!.trim().isEmpty)
                ? 'Select your state.'
                : null,
            decoration: InputDecoration(
              labelText: externalLabels ? null : stateLabel,
              hintText: externalLabels ? 'Select state' : null,
            ),
            items: [
              for (final state in MalaysiaLocations.states)
                DropdownMenuItem(
                  value: state,
                  child: Text(
                    state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onStateChanged,
          ),
        ),
        const SizedBox(height: 10),
        _AddressFieldShell(
          label: externalLabels ? regionLabel : null,
          child: DropdownButtonFormField<String>(
            initialValue: hasSelectedRegion ? selectedRegion : null,
            isExpanded: true,
            selectedItemBuilder: (context) => [
              for (final location in regions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    location.region,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (_) =>
                addressRequired &&
                    (selectedRegion == null || selectedRegion!.trim().isEmpty)
                ? 'Select your region or district.'
                : null,
            decoration: InputDecoration(
              labelText: externalLabels ? null : regionLabel,
              helperText: regionHelperText,
              hintText: externalLabels ? 'Select region or district' : null,
            ),
            items: [
              for (final location in regions)
                DropdownMenuItem(
                  value: location.region,
                  child: Text(
                    location.region,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: selectedState == null ? null : onRegionChanged,
          ),
        ),
      ],
    );
  }
}

class _AddressFieldShell extends StatelessWidget {
  const _AddressFieldShell({required this.child, this.label});

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
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF667A72),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
