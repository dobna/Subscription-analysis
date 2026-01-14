import 'package:flutter/material.dart' hide Notification;
import '../models/notification.dart';
import '../models/notification_group.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  // Состояние
  List<NotificationGroup> _notificationGroups = [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoaded = false;
  int _totalUnread = 0;
  
  String? _authToken;
  NotificationService? _notificationService;

  // Геттеры для доступа к состоянию из UI
  List<NotificationGroup> get notificationGroups => _notificationGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;
  int get totalUnread => _totalUnread;
  String? get authToken => _authToken;

  // 🔥 ДОБАВЬТЕ ЭТИ ГЕТТЕРЫ:
  bool get isInitialized => _notificationService != null && _authToken != null;
  
  NotificationService _getService() {
    if (_notificationService == null) {
      throw Exception('Сервис не инициализирован. Авторизуйтесь.');
    }
    return _notificationService!;
  }

  // Общее количество уведомлений
  int get totalNotifications {
    return _notificationGroups.fold(
      0,
      (sum, group) => sum + group.notifications.length,
    );
  }

  // Список всех уведомлений (разгруппированный)
  List<Notification> get allNotifications {
    return _notificationGroups
        .expand((group) => group.notifications)
        .toList();
  }

  // Установка токена авторизации
  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _notificationService = NotificationService(authToken: token);
    } else {
      _notificationService = null;
    }
    _error = null; // Очищаем ошибку при установке токена
    notifyListeners();
  }

  // 🔥 Инициализация с токеном (обновленный метод)
  void initializeWithToken(String token) {
    _authToken = token;
    _notificationService = NotificationService(authToken: token);
    _error = null;
    _hasLoaded = false; // Позволяем перезагрузить данные
    notifyListeners();
  }

  // 🔥 Ручная установка ошибки
  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  // Загрузка группированных уведомлений
  Future<void> loadNotificationGroups({bool forceRefresh = false}) async {
    if (_isLoading || (_hasLoaded && !forceRefresh)) return;

    // Проверяем авторизацию перед загрузкой
    if (!isInitialized) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = _getService();
      final groups = await service.getGroupedNotifications();
      _notificationGroups = groups;

      _updateUnreadCount();
      
      _hasLoaded = true;
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки уведомлений: ${e.toString()}';
      print('Ошибка загрузки уведомлений: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Notification>> loadSubscriptionNotifications(int subscriptionId) async {

  if (!isInitialized) {
    throw Exception('Сервис не инициализирован. Авторизуйтесь.');
  }

  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final service = _getService();
    final notifications = await service.getSubscriptionNotifications(subscriptionId);
 
    _error = null;
    return notifications;
  } catch (e) {

    final errorMessage = e.toString();
    
    if (errorMessage.contains('Failed to fetch') || 
        errorMessage.contains('Ошибка сети') ||
        errorMessage.contains('ClientException')) {
      _error = 'Ошибка подключения к серверу.\nПроверьте:\n1. Интернет-соединение\n2. Запущен ли бэкенд на localhost:8000\n3. Не блокирует ли брандмауэр';
    } else if (errorMessage.contains('401')) {
      _error = 'Требуется авторизация. Пожалуйста, войдите заново.';
    } else if (errorMessage.contains('404')) {
      _error = 'Подписка не найдена. Возможно, она была удалена.';
    } else {
      _error = 'Ошибка загрузки уведомлений: $errorMessage';
    }
    
    print('Ошибка загрузки уведомлений по подписке: $e');
    rethrow;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  void _updateUnreadCount() {
    _totalUnread = _notificationGroups.fold(
      0,
      (sum, group) => sum + group.unreadCount,
    );
  }

  Future<bool> markSubscriptionAsRead(int subscriptionId) async {

    if (!isInitialized) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = _getService();

      await service.markSubscriptionNotificationsAsRead(subscriptionId);

      final index = _notificationGroups.indexWhere(
        (group) => group.subscriptionId == subscriptionId,
      );
      
      if (index != -1) {

        final updatedGroup = _notificationGroups[index].createCopyWithAllRead();
        _notificationGroups[index] = updatedGroup;

        _updateUnreadCount();
      }
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка пометки уведомлений как прочитанных: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshToken(String newToken) async {
    try {
      setAuthToken(newToken);
      return true;
    } catch (e) {
      _error = 'Ошибка обновления токена: $e';
      notifyListeners();
      return false;
    }
  }

  Future<int?> getSubscriptionUnreadCount(int subscriptionId) async {
    if (!isInitialized) {
      return null;
    }

    try {
      final service = _getService();
      final count = await service.getSubscriptionUnreadCount(subscriptionId);
      return count;
    } catch (e) {
      print('Ошибка получения количества непрочитанных: $e');
      return null;
    }
  }

  void clearData() {
    _notificationGroups = [];
    _isLoading = false;
    _error = null;
    _hasLoaded = false;
    _totalUnread = 0;
    _authToken = null;
    _notificationService = null;
    notifyListeners();
  }

  List<NotificationGroup> search(String query) {
    if (query.isEmpty) return _notificationGroups;
    
    return _notificationGroups.where((group) {

      if (group.subscriptionName.toLowerCase().contains(query.toLowerCase())) {
        return true;
      }

      return group.notifications.any((notification) =>
        notification.message.toLowerCase().contains(query.toLowerCase()) ||
        notification.title.toLowerCase().contains(query.toLowerCase())
      );
    }).toList();
  }

  List<NotificationGroup> filterByType(String type) {
    if (type == 'Все') return _notificationGroups;
    
    return _notificationGroups.map((group) {
      final filteredNotifications = group.notifications
          .where((notification) => notification.type == type)
          .toList();
      
      if (filteredNotifications.isEmpty) return null;
      
      return group.copyWith(
        notifications: filteredNotifications,
        unreadCount: filteredNotifications
            .where((n) => !n.read)
            .length,
      );
    }).where((group) => group != null).cast<NotificationGroup>().toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!isInitialized) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return;
    }

    _hasLoaded = false;
    await loadNotificationGroups(forceRefresh: true);
  }

  NotificationGroup? getGroupBySubscriptionId(int subscriptionId) {
    try {
      return _notificationGroups.firstWhere(
        (group) => group.subscriptionId == subscriptionId,
      );
    } catch (e) {
      return null;
    }
  }

  List<Notification> getNotificationsBySubscriptionId(int subscriptionId) {
    final group = getGroupBySubscriptionId(subscriptionId);
    if (group == null) return [];

    return group.sortedNotifications;
  }

  bool get hasUnreadNotifications => _totalUnread > 0;

  List<NotificationGroup> get groupsWithUnread {
    return _notificationGroups.where((group) => group.unreadCount > 0).toList();
  }

  List<int> get subscriptionIdsWithNotifications {
    return _notificationGroups.map((group) => group.subscriptionId).toList();
  }

  void updateAuthStatus(bool isAuthenticated, String? token) {
    if (isAuthenticated && token != null) {

      if (_authToken != token) {
        initializeWithToken(token);
      }
    } else {

      clearData();
    }
  }
}