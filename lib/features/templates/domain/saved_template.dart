/// A reusable message with optional {first_name}/{last_name}/{full_name}
/// placeholders.
class SavedTemplate {
  const SavedTemplate({
    required this.id,
    required this.title,
    required this.body,
  });

  factory SavedTemplate.fromJson(Map<String, dynamic> json) => SavedTemplate(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  final String id;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};

  /// Shown until the user saves or deletes templates of their own.
  static const starters = [
    SavedTemplate(
      id: 'starter-greeting',
      title: 'Greeting',
      body: 'Hi {first_name}! 👋 Hope you’re doing well.',
    ),
    SavedTemplate(
      id: 'starter-eid',
      title: 'Eid greeting',
      body:
          'Eid Mubarak, {first_name}! 🌙 Wishing you and your family joy, '
          'peace and blessings.',
    ),
    SavedTemplate(
      id: 'starter-meeting',
      title: 'Meeting reminder',
      body:
          'Hi {first_name}, a quick reminder about our meeting tomorrow. '
          'See you there!',
    ),
  ];
}
