import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final file = File(
      r'C:\Users\HP\.gemini\antigravity\brain\09386de7-c058-4c3c-967f-4bd366d7883f\.system_generated\steps\1097\output.txt',
    );
    final content = file.readAsStringSync();
    final json = jsonDecode(content);

    // Stitch tool output structure: { "screens": [ { "name": "...", "displayName": "..." }, ... ] }
    final screens = json['screens'] as List<dynamic>? ?? [];

    // ignore: avoid_print
    print('Found ${screens.length} screens:');
    for (var screen in screens) {
      if (screen is Map) {
        final title =
            screen['title'] ??
            screen['displayName'] ??
            screen['id'] ??
            'Unknown';
        final id = screen['screenId'] ?? screen['name'] ?? 'Unknown';
        // ignore: avoid_print
        print('Screen: $title (ID: $id)');
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('Error: $e');
  }
}
