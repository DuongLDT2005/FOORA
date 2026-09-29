import '../entities/bug_report.dart';
import '../repositories/profile_repository.dart';

class SubmitBugReportUseCase {
  final ProfileRepository repository;

  SubmitBugReportUseCase(this.repository);

  Future<void> call(BugReport report, String? screenshotPath) {
    return repository.submitBugReport(report, screenshotPath);
  }
}
