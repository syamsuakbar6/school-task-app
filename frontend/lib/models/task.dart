class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.isClosed,
  });

  final int id;
  final String title;
  final String description;
  final DateTime? deadline;
  final bool isClosed;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: DateTime.tryParse(json['deadline'] as String? ?? ''),
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }
}
