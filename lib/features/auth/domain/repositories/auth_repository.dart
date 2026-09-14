import '../entities/user.dart';

abstract class AuthRepository {
  /// Stream that emits current User entity on auth changes (or null when logged out)
  Stream<User?> get authStateChanges;

  /// Get current cached/synced user entity
  User? get currentUser;

  /// Sign in with email and password
  Future<User> login({required String email, required String password});

  /// Register a new user account with full name, email and password
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// Sign in using Google OAuth provider
  Future<User> signInWithGoogle();

  /// Send password reset link to user's email
  Future<void> sendPasswordResetEmail({required String email});

  /// Sign out current user
  Future<void> logout();
}
