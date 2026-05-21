import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../providers/auth_provider.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String userQuery;
  const ProcessingScreen({super.key, required this.userQuery});
  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      ref.read(bookingProvider.notifier).runPipeline(widget.userQuery, user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);

    ref.listen<BookingState>(bookingProvider, (prev, next) {
      if (next.isDone && mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && context.mounted) context.go('/results');
        });
      }
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && context.mounted) context.go('/home');
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Processing...')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Query: "${widget.userQuery}"', style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: state.traces.length,
                itemBuilder: (context, i) {
                  final trace = state.traces[i];
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(trace.agentName),
                    subtitle: Text(trace.reasoning),
                    trailing: Text(trace.durationLabel),
                  );
                },
              ),
            ),
            if (state.isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
