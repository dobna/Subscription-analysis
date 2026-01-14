import 'package:flutter/material.dart';
import '../models/analytics.dart';
import '../models/subscription.dart';
import '../services/analytics_service.dart';
import '../utils/category_styles.dart';

class AnalyticsProvider extends ChangeNotifier {

  AnalyticsService? _analyticsService;
  String? _authToken;

  AnalyticsPeriod _currentPeriod = AnalyticsPeriod(
    type: 'month',
    month: 1,
    year: 2026,
  );
  List<GeneralAnalytics> _generalAnalytics = [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoaded = false;

  List<CategoryAnalytics>? _categoryDetails;
  String? _selectedCategory;
  bool _isLoadingDetails = false;
  String? _detailsError;

  AnalyticsPeriod get currentPeriod => _currentPeriod;
  List<GeneralAnalytics> get generalAnalytics => _generalAnalytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalAmount =>
      _generalAnalytics.fold(0, (sum, cat) => sum + cat.total);
  bool get hasLoaded => _hasLoaded;
  String? get authToken => _authToken;

  List<CategoryAnalytics>? get categoryDetails => _categoryDetails;
  String? get selectedCategory => _selectedCategory;
  bool get isLoadingDetails => _isLoadingDetails;
  String? get detailsError => _detailsError;
  double get totalAmountByCategory {
    if (_categoryDetails == null) return 0;
    return _categoryDetails!.fold(0, (sum, cat) => sum + cat.total);
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _analyticsService = AnalyticsService(authToken: token);
    } else {
      _analyticsService = null;
    }
    _error = null;
    notifyListeners();
  }

  void initializeWithToken(String token) {
    _authToken = token;
    _analyticsService = AnalyticsService(authToken: token);
    _error = null;
    _hasLoaded = false;
    notifyListeners();
  }

  bool get isInitialized => _analyticsService != null && _authToken != null;

  AnalyticsService _getService() {
    if (_analyticsService == null) {
      throw Exception('Сервис не инициализирован. Авторизуйтесь.');
    }
    return _analyticsService!;
  }

  String _convertPeriodToEnglish(String period) {
    switch (period.toLowerCase()) {
      case 'месяц':
        return 'month';
      case 'квартал':
        return 'quarter';
      case 'год':
        return 'year';
      default:
        return period;
    }
  }

  Future<void> loadGeneralAnalytics({bool forceRefresh = false}) async {
    if (_isLoading || (_hasLoaded && !forceRefresh)) return;

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
      final englishPeriod = _convertPeriodToEnglish(_currentPeriod.type);

      final data = await service.getAnalyticsSummary(
        period: englishPeriod,
        month: _currentPeriod.month,
        quarter: _currentPeriod.quarter,
        year: _currentPeriod.year,
      );

      _generalAnalytics = _mapApiToGeneralAnalytics(data);
      _hasLoaded = true;
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки аналитики: $e';
      _generalAnalytics = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategoryAnalytics(String category) async {
    if (!isInitialized) {
      _detailsError = 'Сервис не инициализирован. Авторизуйтесь.';
      _isLoadingDetails = false;
      notifyListeners();
      return;
    }

    _selectedCategory = category;
    _isLoadingDetails = true;
    _detailsError = null;
    notifyListeners();

    try {
      final service = _getService();
      final englishPeriod = _convertPeriodToEnglish(_currentPeriod.type);

      final data = await service.getCategoryAnalytics(
        category: category,
        period: englishPeriod,
        month: _currentPeriod.month,
        quarter: _currentPeriod.quarter,
        year: _currentPeriod.year,
      );

      _categoryDetails = _mapApiToCategoryAnalytics(data);
      _detailsError = null;
    } catch (e) {
      _detailsError = 'Ошибка загрузки деталей категории: $e';
      _categoryDetails = null;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void updatePeriod({String? type, int? month, int? quarter, int? year}) {
    _currentPeriod = AnalyticsPeriod(
      type: type ?? _currentPeriod.type,
      month: month ?? _currentPeriod.month,
      quarter: quarter ?? _currentPeriod.quarter,
      year: year ?? _currentPeriod.year,
    );
    notifyListeners();

    loadGeneralAnalytics();

    if (_selectedCategory != null) {
      loadCategoryAnalytics(_selectedCategory!);
    }
  }

  void setPeriodType(String type) => updatePeriod(type: type);
  void selectMonth(int month) => updatePeriod(month: month, quarter: null);
  void selectQuarter(int quarter) =>
      updatePeriod(month: null, quarter: quarter);
  void selectYear(int year) => updatePeriod(year: year);

  void clearCategoryDetails() {
    _selectedCategory = null;
    _categoryDetails = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearDetailsError() {
    _detailsError = null;
    notifyListeners();
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

  void clearData() {
    _generalAnalytics = [];
    _categoryDetails = null;
    _selectedCategory = null;
    _isLoading = false;
    _isLoadingDetails = false;
    _error = null;
    _detailsError = null;
    _hasLoaded = false;
    _authToken = null;
    _analyticsService = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!isInitialized) {
      _error = 'Сервис не инициализирован. Авторизуйтесь.';
      notifyListeners();
      return;
    }

    _hasLoaded = false;
    await loadGeneralAnalytics(forceRefresh: true);
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

  List<GeneralAnalytics> _mapApiToGeneralAnalytics(
    Map<String, dynamic> apiData,
  ) {
    if (apiData['categories'] == null) return [];

    return (apiData['categories'] as List).map((cat) {
      final apiCategory = cat['category'].toString();

      return GeneralAnalytics(
        category: _convertApiCategory(apiCategory),
        total: (cat['total'] as num).toDouble(),
        percentage: (cat['percentage'] as num).toDouble(),
        color: CategoryStyles.getColorByApiString(apiCategory),
        icon: CategoryStyles.getIconByApiString(apiCategory),
      );
    }).toList();
  }

  List<CategoryAnalytics> _mapApiToCategoryAnalytics(
    Map<String, dynamic> apiData,
  ) {
    final List<CategoryAnalytics> result = [];
    final subscriptions = apiData['subscriptions'] as List<dynamic>;

    for (var sub in subscriptions) {
      final subTotal = (sub['total'] as num).toDouble();

      result.add(
        CategoryAnalytics(
          subscriptionId: sub['id'].toString(),
          name: sub['name'].toString(),
          total: subTotal,
          percentage: (sub['percentage'] as num).toDouble(),
          color: _generateColorForSubscription(sub['id'].toString()),
        ),
      );
    }

    return result;
  }

  Color _generateColorForSubscription(String id) {
    final hash = id.hashCode;
    return Color(hash & 0xFFFFFF).withOpacity(1.0);
  }

  SubscriptionCategory _convertApiCategory(String apiCategory) {
    switch (apiCategory) {
      case 'music':
        return SubscriptionCategory.music;
      case 'video':
        return SubscriptionCategory.video;
      case 'books':
        return SubscriptionCategory.books;
      case 'games':
        return SubscriptionCategory.games;
      case 'education':
        return SubscriptionCategory.education;
      case 'social':
        return SubscriptionCategory.social;
      default:
        return SubscriptionCategory.other;
    }
  }
}
