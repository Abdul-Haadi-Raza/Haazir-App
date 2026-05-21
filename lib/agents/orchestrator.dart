import '../models/booking_model.dart';
import '../models/provider_model.dart';
import '../models/service_request.dart';
import 'concierge_agent.dart';

class PipelineResult {
  final ServiceRequest request;
  final List<ProviderModel> providers;
  final List<ProviderModel> rankedProviders;
  final ProviderModel topProvider;
  final String matchReasoning;
  final BookingModel booking;
  final ConciergeSchedule schedule;

  const PipelineResult({
    required this.request,
    required this.providers,
    required this.rankedProviders,
    required this.topProvider,
    required this.matchReasoning,
    required this.booking,
    required this.schedule,
  });
  PipelineResult copyWith({
    ServiceRequest? request,
    List<ProviderModel>? providers,
    List<ProviderModel>? rankedProviders,
    ProviderModel? topProvider,
    String? matchReasoning,
    BookingModel? booking,
    ConciergeSchedule? schedule,
  }) {
    return PipelineResult(
      request: request ?? this.request,
      providers: providers ?? this.providers,
      rankedProviders: rankedProviders ?? this.rankedProviders,
      topProvider: topProvider ?? this.topProvider,
      matchReasoning: matchReasoning ?? this.matchReasoning,
      booking: booking ?? this.booking,
      schedule: schedule ?? this.schedule,
    );
  }
}
