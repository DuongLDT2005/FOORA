import '../repositories/membership_repository.dart';

class UpdateAutoRenew {
  const UpdateAutoRenew(this.repository);

  final MembershipRepository repository;

  Future<void> call(bool enabled) => repository.updateAutoRenew(enabled);
}
