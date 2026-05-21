class ProviderModel {
  final String id;
  final String name;
  final String category;
  final String area;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalReviews;
  final String priceRange;
  final Map<String, List<String>> availability;
  final String phone;
  final bool verified;
  final String? profileImageUrl;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.totalReviews,
    required this.priceRange,
    required this.availability,
    required this.phone,
    required this.verified,
    this.profileImageUrl,
  });

  ProviderModel copyWith({
    String? id,
    String? name,
    String? category,
    String? area,
    double? latitude,
    double? longitude,
    double? rating,
    int? totalReviews,
    String? priceRange,
    Map<String, List<String>>? availability,
    String? phone,
    bool? verified,
    String? profileImageUrl,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      priceRange: priceRange ?? this.priceRange,
      availability: availability ?? this.availability,
      phone: phone ?? this.phone,
      verified: verified ?? this.verified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
