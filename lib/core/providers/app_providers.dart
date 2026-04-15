import 'package:accounting_system/core/db/app_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final appInitializerProvider = FutureProvider<void>((ref) async {
  // Initialize all async dependencies
  await AppDatabase.instance.database;
});
