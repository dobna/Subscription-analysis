import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import 'auth_provider.dart';

class SubscriptionProvider extends ChangeNotifier {

  List<Subscription> _activeSubscriptions = [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoaded = false;

  List<Subscription> _archivedSubscriptions = [];
  bool _isLoadingArchived = false;
  String? _errorArchived;
  bool _hasLoadedArchived = false;

  String? _authToken;
  SubscriptionService? _subscriptionService;

  List<Subscription> get activeSubscriptions => _activeSubscriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;

  List<Subscription> get archivedSubscriptions => _archivedSubscriptions;
  bool get isLoadingArchived => _isLoadingArchived;
  String? get errorArchived => _errorArchived;
  bool get hasLoadedArchived => _hasLoadedArchived;

  String? get authToken => _authToken; 

  void setAuthToken(String? token) {
    _authToken = token;
    _subscriptionService = SubscriptionService(authToken: token);
  }

  void clearData() {
    _activeSubscriptions.clear();
    _archivedSubscriptions.clear();
    _hasLoaded = false;
    _hasLoadedArchived = false;
    _authToken = null;
    _error = null;
    _errorArchived = null;
    notifyListeners();
  }

  Future<void> loadSubscriptions({bool forceRefresh = false}) async {
    if (_isLoading || (_hasLoaded && !forceRefresh)) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_subscriptionService == null) {
        throw Exception('Сервис не инициализирован. Авторизуйтесь.');
      }

      final subscriptions = await _subscriptionService!.getSubscriptions(archived: false);
      _activeSubscriptions = subscriptions;
      _hasLoaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Ошибка загрузки активных подписок: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArchivedSubscriptions({bool forceRefresh = false}) async {
    if (_isLoadingArchived || (_hasLoadedArchived && !forceRefresh)) return;
    
    _isLoadingArchived = true;
    _errorArchived = null;
    notifyListeners();

    try {
      if (_subscriptionService == null) {
        throw Exception('Сервис не инициализирован. Авторизуйтесь.');
      }

      _archivedSubscriptions = await _subscriptionService!.getArchivedSubscriptions();
      _hasLoadedArchived = true;
      _errorArchived = null;
    } catch (e) {
      _errorArchived = e.toString();
      print('Ошибка загрузки архивных подписок: $e');

      if (e.toString().contains('Эндпоинт не найден') || 
          e.toString().contains('404')) {
        _filterArchivedLocally();
      }
    } finally {
      _isLoadingArchived = false;
      notifyListeners();
    }
  }

  void _filterArchivedLocally() {
    try {

      final allSubscriptions = [..._activeSubscriptions];
      _archivedSubscriptions = allSubscriptions.where((sub) => sub.isArchived).toList();
      _hasLoadedArchived = true;
      _errorArchived = null;
      print('Локальная фильтрация: найдено ${_archivedSubscriptions.length} архивных подписок');
    } catch (e) {
      _errorArchived = 'Ошибка локальной фильтрации: $e';
    }
  }

  Future<void> refreshArchived() async {
    _hasLoadedArchived = false;
    await loadArchivedSubscriptions(forceRefresh: true);
  }

  Future<Subscription?> createSubscription(Subscription subscription) async {
    if (_subscriptionService == null) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdSubscription = await _subscriptionService!.createSubscription(subscription);
      _activeSubscriptions.add(createdSubscription);
      _error = null;
      notifyListeners();
      return createdSubscription;
    } catch (e) {
      _error = 'Ошибка создания подписки: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Subscription?> updateSubscription(Subscription subscription) async {
    if (_subscriptionService == null) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedSubscription = await _subscriptionService!.updateSubscription(subscription);

      int index = _activeSubscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _activeSubscriptions[index] = updatedSubscription;
      }

      index = _archivedSubscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _archivedSubscriptions[index] = updatedSubscription;
      }
      
      _error = null;
      notifyListeners();
      return updatedSubscription;
    } catch (e) {
      _error = 'Ошибка обновления подписки: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> archiveSubscription(String subscriptionId) async {
    if (_subscriptionService == null) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final archivedSubscription = await _subscriptionService!.archiveSubscription(subscriptionId);

      _activeSubscriptions.removeWhere((s) => s.id == subscriptionId);
      _archivedSubscriptions.add(archivedSubscription);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка архивации подписки: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreFromArchive(String subscriptionId) async {
    if (_subscriptionService == null) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {

      final subscription = _archivedSubscriptions.firstWhere(
        (s) => s.id == subscriptionId,
        orElse: () => throw Exception('Подписка не найдена в архиве'),
      );
      
      final restoredSubscription = subscription.copyWith(
        archivedDate: null,
      );
      
      final updatedSubscription = await _subscriptionService!.updateSubscription(restoredSubscription);

      _archivedSubscriptions.removeWhere((s) => s.id == subscriptionId);
      _activeSubscriptions.add(updatedSubscription);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка восстановления подписки: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSubscription(String subscriptionId) async {
    if (_subscriptionService == null) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _subscriptionService!.deleteSubscription(subscriptionId);

      _activeSubscriptions.removeWhere((s) => s.id == subscriptionId);
      _archivedSubscriptions.removeWhere((s) => s.id == subscriptionId);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка удаления подписки: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Subscription> filterByCategory(String category) {
    if (category == 'Все') return activeSubscriptions;
    
    return activeSubscriptions.where((sub) {
      switch (sub.category) {
        case SubscriptionCategory.music: return category == 'Музыка';
        case SubscriptionCategory.video: return category == 'Видео';
        case SubscriptionCategory.books: return category == 'Книги';
        case SubscriptionCategory.games: return category == 'Игры';
        case SubscriptionCategory.education: return category == 'Образование';
        case SubscriptionCategory.social: return category == 'Соцсети';
        case SubscriptionCategory.other: return category == 'Другое';
        default: return false;
      }
    }).toList();
  }

  List<Subscription> search(String query) {
    if (query.isEmpty) return activeSubscriptions;
    
    return activeSubscriptions.where((sub) =>
      sub.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearArchivedError() {
    _errorArchived = null;
    notifyListeners();
  }

  void refresh() {
    _hasLoaded = false;
    loadSubscriptions(forceRefresh: true);
  }

  void refreshAll() {
    _hasLoaded = false;
    _hasLoadedArchived = false;
    loadSubscriptions(forceRefresh: true);
    loadArchivedSubscriptions(forceRefresh: true);
  }
}