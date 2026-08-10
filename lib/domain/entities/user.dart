class AppUser {
  final String id;
  final String username;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final String? countryCode;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? kcc;
  final String? department;
  final String? membershipStatus;
  final String? nin;
  final String? bvn;
  final String? transactionPin;
  final String? address;
  final bool isOnline;
  final bool ninVerified;
  final bool bvnVerified;
  final String role;
  final bool isServiceTeamMember;
  final bool isGeneralMarried;
  final bool isInHouseMarried;

  const AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.countryCode,
    this.gender,
    this.dateOfBirth,
    this.kcc,
    this.department,
    this.membershipStatus,
    this.nin,
    this.bvn,
    this.transactionPin,
    this.address,
    this.isOnline = false,
    this.ninVerified = false,
    this.bvnVerified = false,
    this.role = 'user',
    this.isServiceTeamMember = false,
    this.isGeneralMarried = false,
    this.isInHouseMarried = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'],
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      phoneNumber: json['phone_number'],
      countryCode: json['country_code'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.tryParse(json['date_of_birth']) 
          : null,
      kcc: json['kcc'],
      department: json['department'],
      membershipStatus: json['membership_status'],
      nin: json['nin'],
      bvn: json['bvn'],
      address: json['address'],
      isOnline: json['is_online'] ?? false,
      ninVerified: json['nin_verified'] ?? (json['nin'] != null && json['nin'].toString().isNotEmpty),
      bvnVerified: json['bvn_verified'] ?? (json['bvn'] != null && json['bvn'].toString().isNotEmpty),
      role: json['role'] ?? 'user',
      isServiceTeamMember: json['is_service_team_member'] ?? false,
      isGeneralMarried: json['is_general_married'] ?? false,
      isInHouseMarried: json['is_in_house_married'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'email': email,
      'photo_url': photoUrl,
      'phone_number': phoneNumber,
      'country_code': countryCode,
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'kcc': kcc,
      'department': department,
      'membership_status': membershipStatus,
      'nin': nin,
      'bvn': bvn,
      'transaction_pin': transactionPin,
      'address': address,
      'is_online': isOnline,
      'nin_verified': ninVerified,
      'bvn_verified': bvnVerified,
      'role': role,
      'is_service_team_member': isServiceTeamMember,
      'is_general_married': isGeneralMarried,
      'is_in_house_married': isInHouseMarried,
    };
  }

  String get fullName {
    return '$firstName $lastName'.trim();
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? countryCode,
    String? gender,
    DateTime? dateOfBirth,
    String? kcc,
    String? department,
    String? membershipStatus,
    String? nin,
    String? bvn,
    String? transactionPin,
    String? address,
    bool? isOnline,
    bool? ninVerified,
    bool? bvnVerified,
    String? role,
    bool? isServiceTeamMember,
    bool? isGeneralMarried,
    bool? isInHouseMarried,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      kcc: kcc ?? this.kcc,
      department: department ?? this.department,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      nin: nin ?? this.nin,
      bvn: bvn ?? this.bvn,
      transactionPin: transactionPin ?? this.transactionPin,
      address: address ?? this.address,
      isOnline: isOnline ?? this.isOnline,
      ninVerified: ninVerified ?? this.ninVerified,
      bvnVerified: bvnVerified ?? this.bvnVerified,
      role: role ?? this.role,
      isServiceTeamMember: isServiceTeamMember ?? this.isServiceTeamMember,
      isGeneralMarried: isGeneralMarried ?? this.isGeneralMarried,
      isInHouseMarried: isInHouseMarried ?? this.isInHouseMarried,
    );
  }
}

class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  static const List<CountryCode> countries = [
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
    CountryCode(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    CountryCode(name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
    CountryCode(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
    CountryCode(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
    CountryCode(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
    CountryCode(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
  ];
}
