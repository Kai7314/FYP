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
  });

  final TextEditingController addressController;
  final String? selectedState;
  final String? selectedRegion;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onRegionChanged;
  final bool addressRequired;

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
          decoration: const InputDecoration(
            labelText: 'Home address',
            helperText: 'House/unit, street, building, or nearby landmark',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedState?.isEmpty == true ? null : selectedState,
          isExpanded: true,
          validator: (_) => addressRequired && selectedState == null
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
          value: hasSelectedRegion ? selectedRegion : null,
          isExpanded: true,
          validator: (_) => addressRequired && selectedRegion == null
              ? 'Select your region or district.'
              : null,
          decoration: const InputDecoration(
            labelText: 'Region / district',
            helperText: 'Used to request weather forecasts from data.gov.my',
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
