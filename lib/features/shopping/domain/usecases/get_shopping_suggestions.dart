import '../entities/shopping_suggestion.dart';
import '../repositories/shopping_repository.dart';

class GetShoppingSuggestionsUseCase {
  final ShoppingRepository _repository;

  const GetShoppingSuggestionsUseCase(this._repository);

  Future<List<ShoppingSuggestion>> call(String householdId) =>
      _repository.getSuggestions(householdId);
}
