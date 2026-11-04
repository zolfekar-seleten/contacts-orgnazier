/// The ways the app can reach a contact.
enum CommunicationKind {
  call('Call'),
  whatsApp('WhatsApp'),
  sms('SMS');

  const CommunicationKind(this.label);
  final String label;

  /// Name of the app the user finishes the action in.
  String get appName => switch (this) {
    CommunicationKind.call => 'Phone',
    CommunicationKind.whatsApp => 'WhatsApp',
    CommunicationKind.sms => 'Messages',
  };
}
