import 'package:flutter_test/flutter_test.dart';
import 'package:foora/core/constants/app_enums.dart';
import 'package:foora/features/profile/domain/entities/bug_report.dart';
import 'package:foora/features/profile/domain/entities/profile.dart';
import 'package:foora/features/profile/domain/repositories/profile_repository.dart';
import 'package:foora/features/profile/domain/usecases/change_password.dart';
import 'package:foora/features/profile/domain/usecases/delete_account.dart';
import 'package:foora/features/profile/domain/usecases/get_profile.dart';
import 'package:foora/features/profile/domain/usecases/submit_bug_report.dart';
import 'package:foora/features/profile/domain/usecases/update_email.dart';
import 'package:foora/features/profile/domain/usecases/update_profile.dart';
import 'package:foora/features/profile/domain/usecases/upload_avatar.dart';
import 'package:foora/features/profile/domain/usecases/watch_profile.dart';

class MockProfileRepository implements ProfileRepository {
  Profile? mockProfile;
  bool isAccountDeleted = false;
  String? updatedEmail;
  String? updatedPassword;
  BugReport? submittedBugReport;

  @override
  Stream<Profile> watchProfile(String userId) {
    if (mockProfile != null) {
      return Stream.value(mockProfile!);
    }
    throw Exception('Profile not found');
  }

  @override
  Future<Profile> getProfile(String userId) async {
    if (mockProfile != null) {
      return mockProfile!;
    }
    throw Exception('Profile not found');
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    if (mockProfile != null) {
      mockProfile = Profile(
        id: userId,
        fullName: fullName,
        email: mockProfile!.email,
        role: mockProfile!.role,
        membershipId: mockProfile!.membershipId,
        avatarUrl: avatarUrl ?? mockProfile!.avatarUrl,
        createdAt: mockProfile!.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    return 'https://storage.googleapis.com/foora/avatars/$userId.jpg';
  }

  @override
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    if (currentPassword == 'wrong_pass') {
      throw Exception('Mật khẩu không chính xác');
    }
    updatedEmail = newEmail;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword == 'wrong_pass') {
      throw Exception('Mật khẩu không chính xác');
    }
    updatedPassword = newPassword;
  }

  @override
  Future<void> submitBugReport(BugReport report, String? screenshotPath) async {
    submittedBugReport = report;
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    isAccountDeleted = true;
  }
}

void main() {
  late MockProfileRepository mockRepository;
  late Profile testProfile;

  setUp(() {
    mockRepository = MockProfileRepository();
    testProfile = Profile(
      id: 'user-123',
      fullName: 'Nguyễn Văn A',
      email: 'nguyenvana@gmail.com',
      role: UserRole.member,
      membershipId: 'free',
      avatarUrl: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    mockRepository.mockProfile = testProfile;
  });

  group('Profile Domain UseCases', () {
    test('GetProfileUseCase returns profile correctly', () async {
      final useCase = GetProfileUseCase(mockRepository);
      final result = await useCase('user-123');

      expect(result.id, 'user-123');
      expect(result.fullName, 'Nguyễn Văn A');
      expect(result.initials, 'NA');
    });

    test('WatchProfileUseCase emits stream with correct profile', () async {
      final useCase = WatchProfileUseCase(mockRepository);
      final stream = useCase('user-123');

      expect(await stream.first, testProfile);
    });

    test('UpdateProfileUseCase updates full name and avatar', () async {
      final useCase = UpdateProfileUseCase(mockRepository);
      await useCase(
        userId: 'user-123',
        fullName: 'Nguyễn Văn B',
        avatarUrl: 'https://new-avatar.jpg',
      );

      final updated = await mockRepository.getProfile('user-123');
      expect(updated.fullName, 'Nguyễn Văn B');
      expect(updated.avatarUrl, 'https://new-avatar.jpg');
    });

    test('UploadAvatarUseCase returns valid storage URL', () async {
      final useCase = UploadAvatarUseCase(mockRepository);
      final url = await useCase(
        userId: 'user-123',
        filePath: '/data/local/avatar.jpg',
      );

      expect(url, contains('user-123.jpg'));
    });

    test('UpdateEmailUseCase succeeds with valid password', () async {
      final useCase = UpdateEmailUseCase(mockRepository);
      await useCase(
        newEmail: 'newemail@gmail.com',
        currentPassword: 'correct_pass',
      );

      expect(mockRepository.updatedEmail, 'newemail@gmail.com');
    });

    test('UpdateEmailUseCase throws exception with wrong password', () async {
      final useCase = UpdateEmailUseCase(mockRepository);

      expect(
        () => useCase(
          newEmail: 'newemail@gmail.com',
          currentPassword: 'wrong_pass',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('ChangePasswordUseCase succeeds with correct password', () async {
      final useCase = ChangePasswordUseCase(mockRepository);
      await useCase(
        currentPassword: 'correct_pass',
        newPassword: 'new_secure_password',
      );

      expect(mockRepository.updatedPassword, 'new_secure_password');
    });

    test('SubmitBugReportUseCase saves bug report', () async {
      final useCase = SubmitBugReportUseCase(mockRepository);
      final bugReport = BugReport(
        id: 'bug-1',
        userId: 'user-123',
        userEmail: 'nguyenvana@gmail.com',
        category: 'receipt',
        title: 'OCR nhận sai ngày',
        description: 'Ngày 25/12 nhận thành 25/11',
        createdAt: DateTime.now(),
      );

      await useCase(bugReport, null);
      expect(mockRepository.submittedBugReport?.title, 'OCR nhận sai ngày');
    });

    test('DeleteAccountUseCase marks account deleted', () async {
      final useCase = DeleteAccountUseCase(mockRepository);
      await useCase(password: '123456');

      expect(mockRepository.isAccountDeleted, isTrue);
    });
  });
}
