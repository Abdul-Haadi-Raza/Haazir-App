class BookingModel {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String customerName;
  final String customerPhone;
  final String serviceCategory;
  final String serviceType;
  final String location;
  final DateTime slot;
  final String status;
  final String priceEstimate;
  final String confirmationMessage;
  final DateTime createdAt;

  const BookingModel({
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.customerName,
    required this.customerPhone,
    required this.serviceCategory,
    required this.serviceType,
    required this.location,
    required this.slot,
    required this.status,
    required this.priceEstimate,
    required this.confirmationMessage,
    required this.createdAt,
  });

  BookingModel copyWith({
    String? bookingId,
    String? providerId,
    String? providerName,
    String? providerPhone,
    String? customerName,
    String? customerPhone,
    String? serviceCategory,
    String? serviceType,
    String? location,
    DateTime? slot,
    String? status,
    String? priceEstimate,
    String? confirmationMessage,
    DateTime? createdAt,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      serviceType: serviceType ?? this.serviceType,
      location: location ?? this.location,
      slot: slot ?? this.slot,
      status: status ?? this.status,
      priceEstimate: priceEstimate ?? this.priceEstimate,
      confirmationMessage: confirmationMessage ?? this.confirmationMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
