class UserModel {
  final String id;
  final String phone;
  final String name;
  final String role; // 'customer' or 'provider'
  final String? address;
  final String? pinnedLocation;
  final String? profileImageUrl;
  final String? cnic;
  final String? cnicUrl;
  final List<Map<String, dynamic>>? savedAddresses;
  
  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    this.role = 'customer',
    this.address,
    this.pinnedLocation,
    this.profileImageUrl,
    this.cnic,
    this.cnicUrl,
    this.savedAddresses,
  });

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? role,
    String? address,
    String? pinnedLocation,
    String? profileImageUrl,
    String? cnic,
    String? cnicUrl,
    List<Map<String, dynamic>>? savedAddresses,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      address: address ?? this.address,
      pinnedLocation: pinnedLocation ?? this.pinnedLocation,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      cnic: cnic ?? this.cnic,
      cnicUrl: cnicUrl ?? this.cnicUrl,
      savedAddresses: savedAddresses ?? this.savedAddresses,
    );
  }
}
