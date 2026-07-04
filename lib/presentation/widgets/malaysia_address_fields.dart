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
    this.regionHelperText = 'Used to request weather forecasts from data.gov.my',
  });

  final TextEditingController addressController;
  final String? selectedState;
  final String? selectedRegion;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onRegionChanged;
  final bool addressRequired;
  final String addressLabel;
  final String addressHelperText;
  final String regionHelperText;

  @override
  Widget build(BuildContext context) {
    final regions = MalaysiaLocations.regionsFor(selectedState);
    final hasSelectedRegion = regions.any(
      (location) => location.region == selectedRegion,
    );

    return Column(
      children: [
        TextFormField(
          controller: addressController,
          maxLength: AppValidators.maxAddressLength,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => AppValidators.address(
            value ?? '',
            required: addressRequired,
          ),
          decoration: InputDecoration(
            labelText: addressLabel,
            helperText: addressHelperText,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedState?.isEmpty == true ? null : selectedState,
          isExpanded: true,
          validator: (_) =>
              addressRequired &&
                  (selectedState == null || selectedState!.trim().isEmpty)
              ? 'Select your state.'
              : null,
          decoration: const InputDecoration(
            labelText: 'State / federal territory',
          ),
          items: [
            for (final state in MalaysiaLocations.states)
              DropdownMenuItem(value: state, child: Text(state)),
          ],
          onChanged: onStateChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: hasSelectedRegion ? selectedRegion : null,
          isExpanded: true,
          validator: (_) =>
              addressRequired &&
                  (selectedRegion == null || selectedRegion!.trim().isEmpty)
              ? 'Select your region or district.'
              : null,
          decoration: InputDecoration(
            labelText: 'Region / district',
            helperText: regionHelperText,
          ),
          items: [
            for (final location in regions)
              DropdownMenuItem(
                value: location.region,
                child: Text(location.region),
              ),
          ],
          onChanged: selectedState == null ? null : onRegionChanged,
        ),
      ],
    );
  }
}
