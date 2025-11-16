import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/subscription_item.dart';
import '../models/subscription.dart';


// Модальное окно для добавления новой подписки
class AddSubscriptionModal extends StatefulWidget {
  @override
  _AddSubscriptionModalState createState() => _AddSubscriptionModalState();
}

class _AddSubscriptionModalState extends State<AddSubscriptionModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '3');
  
  bool _isTrial = false;
  DateTime? _selectedDate;
  BillingCycle _billingCycle = BillingCycle.monthly;
  String _selectedCategory = 'Другое';

  // Список категорий
  final List<String> _categories = ['Музыка', 'Видео', 'Книги', 'Соцсети', 'Игры', 'Образование', 'Другое'];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  void _addSubscription() {
    if (_formKey.currentState!.validate()) {
      // Если пробная подписка, устанавливаем стоимость 0
      final amount = _isTrial ? 0 : int.tryParse(_amountController.text);
      
      // Извлекаем день списания из выбранной даты
      final billingDay = _selectedDate?.day ?? DateTime.now().day;

      final newSubscription = Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        nextPaymentDate: _selectedDate ?? DateTime.now(),
        currentAmount: amount,
        icon: _getIconForCategory(_selectedCategory),
        color: _getColorForCategory(_selectedCategory),
        category: _selectedCategory,
        connectedDate: DateTime.now(),
        priceHistory: [
          PriceHistory(
            startDate: DateTime.now(),
            amount: amount ?? 0,
          ),
        ],
        isTrial: _isTrial,
        notifyDays: int.tryParse(_daysController.text) ?? 3,
        billingCycle: _billingCycle,
        billingDay: billingDay,
      );

      Navigator.of(context).pop(newSubscription);
    }
  }

  // Функция для получения иконки по категории
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Музыка':
        return Icons.music_note;
      case 'Видео':
        return Icons.movie;
      case 'Книги':
        return Icons.menu_book;
      case 'Соцсети':
        return Icons.chat;
      case 'Игры':
        return Icons.sports_esports;
      case 'Образование':
        return Icons.school;
      default:
        return Icons.receipt;
    }
  }

  // Функция для получения цвета по категории
  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Музыка':
        return Colors.green;
      case 'Видео':
        return Colors.orange;
      case 'Книги':
        return Colors.blue;
      case 'Соцсети':
        return Colors.blue[400]!;
      case 'Игры':
        return Colors.purple;
      case 'Образование':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Добавить подписку',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                
                // Название подписки
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название подписки',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите название';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Выбор категории
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'Другое';
                    });
                  },
                ),
                SizedBox(height: 16),
                
                // Поле стоимости с логикой для пробной подписки
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  enabled: !_isTrial,
                  decoration: InputDecoration(
                    labelText: _isTrial ? 'Стоимость (бесплатный пробный период)' : 'Стоимость',
                    border: OutlineInputBorder(),
                    suffixText: 'руб.',
                    hintText: _isTrial ? '0' : null,
                  ),
                  validator: (value) {
                    if (!_isTrial && (value == null || value.isEmpty)) {
                      return 'Пожалуйста, введите стоимость';
                    }
                    if (!_isTrial && int.tryParse(value!) == null) {
                      return 'Пожалуйста, введите число';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Поле даты с изменяющимся лейблом
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _selectDate,
                  decoration: InputDecoration(
                    labelText: _isTrial ? 'Дата окончания пробного периода' : 'Дата следующего списания',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, выберите дату';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Периодичность (скрываем для пробной подписки)
                if (!_isTrial) ...[
                  DropdownButtonFormField<BillingCycle>(
                    value: _billingCycle,
                    decoration: InputDecoration(
                      labelText: 'Периодичность',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: BillingCycle.monthly,
                        child: Text('Ежемесячно'),
                      ),
                      DropdownMenuItem(
                        value: BillingCycle.quarterly,
                        child: Text('Ежеквартально'),
                      ),
                      DropdownMenuItem(
                        value: BillingCycle.yearly,
                        child: Text('Ежегодно'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _billingCycle = value ?? BillingCycle.monthly;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                ],
                
                // Чекбокс пробной подписки
                Row(
                  children: [
                    Checkbox(
                      value: _isTrial,
                      onChanged: (bool? value) {
                        setState(() {
                          _isTrial = value ?? false;
                          if (_isTrial) {
                            // Если стала пробной - устанавливаем стоимость 0
                            _amountController.text = '0';
                          } else {
                            // Если перестала быть пробной - очищаем поле стоимости
                            _amountController.clear();
                          }
                        });
                      },
                    ),
                    Text('Пробная подписка'),
                  ],
                ),
                SizedBox(height: 16),
                
                // Поле дней для оповещения
                TextFormField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Оповестить за',
                    border: OutlineInputBorder(),
                    suffixText: 'дней',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите количество дней';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Пожалуйста, введите число';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32),
                
                // Кнопка добавления
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _addSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Добавить подписку',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _daysController.dispose();
    super.dispose();
  }
}