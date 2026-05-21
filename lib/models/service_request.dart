class ServiceRequest {
  final String originalInput;
  final String detectedLanguage;
  final String serviceType;
  final String serviceCategory;
  final String location;
  final String timePreference;
  final String urgency;
  final String reasoning;

  const ServiceRequest({
    required this.originalInput,
    required this.detectedLanguage,
    required this.serviceType,
    required this.serviceCategory,
    required this.location,
    required this.timePreference,
    required this.urgency,
    required this.reasoning,
  });
}
