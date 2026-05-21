class AgentTrace {
  final String agentName;
  final String role;
  final String icon;
  final String input;
  final String output;
  final String reasoning;
  final String durationLabel;

  const AgentTrace({
    required this.agentName,
    required this.role,
    required this.icon,
    required this.input,
    required this.output,
    required this.reasoning,
    required this.durationLabel,
  });
}
