import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/models.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// Get current user ID - MUST be authenticated (no fallback)
final currentUserIdProvider = Provider<String>((ref) {
  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('User not authenticated - please sign in');
  }
  return user.id;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  final data = await supabase.from('users').select().eq('id', user.id).maybeSingle();
  if (data == null) return null;
  return UserModel.fromJson(data);
});

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(() => AuthNotifier());

class AuthNotifier extends Notifier<AsyncValue<UserModel?>> {
  SupabaseClient get _supabase => ref.read(supabaseProvider);

  @override
  AsyncValue<UserModel?> build() => const AsyncValue.loading();

  Future<void> signUp({required String email, required String password, required String name, required String businessName}) async {
    state = const AsyncValue.loading();
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null && res.session != null) {
        // User created and confirmed (or auto-confirmed)
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'name': name,
          'business_name': businessName,
          'plan': 'free',
        });
        final data = await _supabase.from('users').select().eq('id', res.user!.id).single();
        state = AsyncValue.data(UserModel.fromJson(data));
      } else if (res.user != null) {
        // User created but needs email confirmation
        state = const AsyncValue.data(null);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);

      if (res.user != null) {
        // Check if user exists in users table, if not create them
        var data = await _supabase.from('users').select().eq('id', res.user!.id).maybeSingle();

        if (data == null) {
          // Create user record if not exists
          await _supabase.from('users').insert({
            'id': res.user!.id,
            'email': email,
            'name': res.user!.userMetadata?['name'] ?? 'User',
            'business_name': res.user!.userMetadata?['business_name'] ?? 'My Business',
            'plan': 'free',
          });
          data = await _supabase.from('users').select().eq('id', res.user!.id).single();
        }

        state = AsyncValue.data(UserModel.fromJson(data));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }
}