import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://syfxfpcjmftziihznqjd.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5ZnhmcGNqbWZ0emlpaHpucWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4MjA5NjYsImV4cCI6MjA5MTM5Njk2Nn0.7KlVR7IK6WcQivptCF6bMlS41vfUWE8cl3iwwY5fghs',
    );
  }
}