class MalaysiaAddressLocation {
  const MalaysiaAddressLocation({
    required this.state,
    required this.region,
    this.weatherLocation,
  });

  final String state;
  final String region;
  final String? weatherLocation;

  String get queryName => weatherLocation ?? region;
}

class MalaysiaLocations {
  const MalaysiaLocations._();

  static const byState = <String, List<MalaysiaAddressLocation>>{
    'Johor': [
      MalaysiaAddressLocation(state: 'Johor', region: 'Batu Pahat'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Johor Bahru'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Kluang'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Kota Tinggi'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Mersing'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Muar'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Pontian'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Segamat'),
      MalaysiaAddressLocation(state: 'Johor', region: 'Tangkak'),
    ],
    'Kedah': [
      MalaysiaAddressLocation(state: 'Kedah', region: 'Alor Setar'),
      MalaysiaAddressLocation(state: 'Kedah', region: 'Baling'),
      MalaysiaAddressLocation(state: 'Kedah', region: 'Kulim'),
      MalaysiaAddressLocation(state: 'Kedah', region: 'Langkawi'),
      MalaysiaAddressLocation(state: 'Kedah', region: 'Sungai Petani'),
    ],
    'Kelantan': [
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Bachok'),
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Gua Musang'),
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Kota Bharu'),
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Kuala Krai'),
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Pasir Mas'),
      MalaysiaAddressLocation(state: 'Kelantan', region: 'Tanah Merah'),
    ],
    'Melaka': [
      MalaysiaAddressLocation(state: 'Melaka', region: 'Alor Gajah'),
      MalaysiaAddressLocation(state: 'Melaka', region: 'Jasin'),
      MalaysiaAddressLocation(state: 'Melaka', region: 'Melaka Tengah'),
    ],
    'Negeri Sembilan': [
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Jelebu'),
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Kuala Pilah'),
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Port Dickson'),
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Rembau'),
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Seremban'),
      MalaysiaAddressLocation(state: 'Negeri Sembilan', region: 'Tampin'),
    ],
    'Pahang': [
      MalaysiaAddressLocation(state: 'Pahang', region: 'Bentong'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Cameron Highlands'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Kuantan'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Maran'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Pekan'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Raub'),
      MalaysiaAddressLocation(state: 'Pahang', region: 'Temerloh'),
    ],
    'Penang': [
      MalaysiaAddressLocation(state: 'Penang', region: 'Bukit Mertajam'),
      MalaysiaAddressLocation(state: 'Penang', region: 'Butterworth'),
      MalaysiaAddressLocation(state: 'Penang', region: 'George Town'),
      MalaysiaAddressLocation(state: 'Penang', region: 'Nibong Tebal'),
    ],
    'Perak': [
      MalaysiaAddressLocation(state: 'Perak', region: 'Ipoh'),
      MalaysiaAddressLocation(state: 'Perak', region: 'Kuala Kangsar'),
      MalaysiaAddressLocation(state: 'Perak', region: 'Lumut'),
      MalaysiaAddressLocation(state: 'Perak', region: 'Taiping'),
      MalaysiaAddressLocation(state: 'Perak', region: 'Teluk Intan'),
    ],
    'Perlis': [
      MalaysiaAddressLocation(state: 'Perlis', region: 'Arau'),
      MalaysiaAddressLocation(state: 'Perlis', region: 'Kangar'),
      MalaysiaAddressLocation(state: 'Perlis', region: 'Padang Besar'),
    ],
    'Sabah': [
      MalaysiaAddressLocation(state: 'Sabah', region: 'Beaufort'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Keningau'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Kota Kinabalu'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Kudat'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Lahad Datu'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Sandakan'),
      MalaysiaAddressLocation(state: 'Sabah', region: 'Tawau'),
    ],
    'Sarawak': [
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Bintulu'),
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Kuching'),
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Limbang'),
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Miri'),
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Sibu'),
      MalaysiaAddressLocation(state: 'Sarawak', region: 'Sri Aman'),
    ],
    'Selangor': [
      MalaysiaAddressLocation(state: 'Selangor', region: 'Gombak'),
      MalaysiaAddressLocation(state: 'Selangor', region: 'Klang'),
      MalaysiaAddressLocation(state: 'Selangor', region: 'Kuala Selangor'),
      MalaysiaAddressLocation(state: 'Selangor', region: 'Petaling Jaya'),
      MalaysiaAddressLocation(state: 'Selangor', region: 'Sepang'),
      MalaysiaAddressLocation(state: 'Selangor', region: 'Shah Alam'),
    ],
    'Terengganu': [
      MalaysiaAddressLocation(state: 'Terengganu', region: 'Besut'),
      MalaysiaAddressLocation(state: 'Terengganu', region: 'Dungun'),
      MalaysiaAddressLocation(state: 'Terengganu', region: 'Kemaman'),
      MalaysiaAddressLocation(state: 'Terengganu', region: 'Kuala Terengganu'),
      MalaysiaAddressLocation(state: 'Terengganu', region: 'Marang'),
    ],
    'Kuala Lumpur': [
      MalaysiaAddressLocation(state: 'Kuala Lumpur', region: 'Kuala Lumpur'),
    ],
    'Labuan': [
      MalaysiaAddressLocation(state: 'Labuan', region: 'Labuan'),
    ],
    'Putrajaya': [
      MalaysiaAddressLocation(state: 'Putrajaya', region: 'Putrajaya'),
    ],
  };

  static List<String> get states => byState.keys.toList(growable: false);

  static List<MalaysiaAddressLocation> regionsFor(String? state) {
    if (state == null || state.trim().isEmpty) return const [];
    return byState[state] ?? const [];
  }

  static MalaysiaAddressLocation? find(String? state, String? region) {
    if (state == null || region == null) return null;
    for (final location in regionsFor(state)) {
      if (location.region == region) return location;
    }
    return null;
  }
}
