import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Period Tracker',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}

class CycleData {
  DateTime? lastPeriod;
  int cycleLength = 28;
  int periodLength = 5;
  DateTime? nextPeriod;
  DateTimeRange? fertileWindow;
  List<DateTime> periodDays = [];
  Map<DateTime, String> symptoms = {};
  Map<DateTime, String> moods = {};

  CycleData();

  Map<String, dynamic> toJson() => {
    'lastPeriod': lastPeriod?.toIso8601String(),
    'cycleLength': cycleLength,
    'periodLength': periodLength,
    'nextPeriod': nextPeriod?.toIso8601String(),
    'fertileWindowStart': fertileWindow?.start.toIso8601String(),
    'fertileWindowEnd': fertileWindow?.end.toIso8601String(),
    'periodDays': periodDays.map((date) => date.toIso8601String()).toList(),
  };

  factory CycleData.fromJson(Map<String, dynamic> json) {
    final data = CycleData();
    data.lastPeriod = json['lastPeriod'] != null ? DateTime.parse(json['lastPeriod']) : null;
    data.cycleLength = json['cycleLength'] ?? 28;
    data.periodLength = json['periodLength'] ?? 5;
    data.nextPeriod = json['nextPeriod'] != null ? DateTime.parse(json['nextPeriod']) : null;
    if (json['fertileWindowStart'] != null && json['fertileWindowEnd'] != null) {
      data.fertileWindow = DateTimeRange(
        start: DateTime.parse(json['fertileWindowStart']),
        end: DateTime.parse(json['fertileWindowEnd']),
      );
    }
    if (json['periodDays'] != null) {
      data.periodDays = (json['periodDays'] as List)
          .map((dateStr) => DateTime.parse(dateStr))
          .toList();
    }
    return data;
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CycleData cycleData = CycleData();
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('periodData');
    if (savedData != null) {
      setState(() {
        cycleData = CycleData.fromJson(Map<String, dynamic>.from(json.decode(savedData)));
      });
    }
  }

  _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('periodData', json.encode(cycleData.toJson()));
  }

  _recordPeriodStart() {
    final today = DateTime.now();
    final nextPeriod = today.add(Duration(days: cycleData.cycleLength));
    final fertileStart = today.add(Duration(days: 10));
    final fertileEnd = today.add(Duration(days: 16));

    // Generate period days
    final periodDays = List.generate(cycleData.periodLength, 
        (index) => today.add(Duration(days: index)));

    setState(() {
      cycleData.lastPeriod = today;
      cycleData.nextPeriod = nextPeriod;
      cycleData.fertileWindow = DateTimeRange(start: fertileStart, end: fertileEnd);
      cycleData.periodDays = periodDays;
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Period recorded for today!')),
    );
  }

  // Add new function to record period for any date
  _recordPeriodForDate(DateTime date) {
    final nextPeriod = date.add(Duration(days: cycleData.cycleLength));
    final fertileStart = date.add(Duration(days: 10));
    final fertileEnd = date.add(Duration(days: 16));

    // Generate period days
    final periodDays = List.generate(cycleData.periodLength, 
        (index) => date.add(Duration(days: index)));

    setState(() {
      cycleData.lastPeriod = date;
      cycleData.nextPeriod = nextPeriod;
      cycleData.fertileWindow = DateTimeRange(start: fertileStart, end: fertileEnd);
      cycleData.periodDays = periodDays;
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Period recorded for ${DateFormat('MMM dd, yyyy').format(date)}!')),
    );
  }

  int _calculateDaysUntilNext() {
    if (cycleData.nextPeriod == null) return 0;
    final next = cycleData.nextPeriod!;
    final today = DateTime.now();
    final difference = next.difference(today).inDays;
    return difference >= 0 ? difference : 0;
  }

  String _getCyclePhase() {
    if (cycleData.lastPeriod == null) return 'Not tracking';
    
    final today = DateTime.now();
    final daysSinceLast = today.difference(cycleData.lastPeriod!).inDays;
    
    if (daysSinceLast <= cycleData.periodLength) return 'Period';
    if (daysSinceLast <= 16) return 'Follicular Phase';
    if (daysSinceLast <= 28) return 'Luteal Phase';
    return 'Waiting for next cycle';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Period Tracker'),
        backgroundColor: Colors.purple,
        elevation: 0,
      ),
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
      ),
      floatingActionButton: _currentPageIndex == 1 ? FloatingActionButton(
        onPressed: () => _showDatePicker(),
        child: Icon(Icons.add),
        backgroundColor: Colors.purple,
      ) : null,
    );
  }

  // Add function to show date picker for recording past periods
  _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _recordPeriodForDate(picked);
    }
  }

  Widget _getCurrentPage() {
    switch (_currentPageIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return CalendarScreen(cycleData: cycleData, onDataChanged: _saveData);
      case 2:
        return StatsScreen(cycleData: cycleData);
      case 3:
        return SettingsScreen(
          cycleData: cycleData,
          onSettingsChanged: () {
            _saveData();
            setState(() {});
          },
        );
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final daysUntil = _calculateDaysUntilNext();
    final currentDayInCycle = _getCurrentDayInCycle();
    final cycleProgress = _getCycleProgress();
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with greeting
          Text(
            'Hello!',
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.bold,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your cycle overview',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          
          // Current Status Card with enhanced design
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade300, Colors.purple.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (cycleData.lastPeriod != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Day $currentDayInCycle',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(
                        Icons.circle, 
                        color: _getStatusColor(), 
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getCyclePhase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  if (cycleData.lastPeriod != null) ...[
                    _buildInfoRow(
                      'Last period:', 
                      DateFormat('MMM dd, yyyy').format(cycleData.lastPeriod!),
                      Colors.white70,
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      'Next period:', 
                      DateFormat('MMM dd, yyyy').format(cycleData.nextPeriod!),
                      Colors.white70,
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      'Days until next:', 
                      '$daysUntil days',
                      Colors.white70,
                    ),
                  ] else
                    Text(
                      'No period recorded yet', 
                      style: TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 25),
          
          // Progress section
          if (cycleData.lastPeriod != null) ...[
            Text(
              'Cycle Progress',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.purple[800],
              ),
            ),
            SizedBox(height: 15),
            Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 20,
                      width: constraints.maxWidth * cycleProgress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink.shade300, Colors.purple.shade300],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $currentDayInCycle',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${cycleData.cycleLength} days',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 25),
          ],
          
          // Quick Actions with enhanced design
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(height: 15),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildActionButton(
                    icon: Icons.event,
                    label: 'Start Period',
                    color: Colors.pink.shade400,
                    onPressed: () => _showDatePicker(),
                  ),
                  _buildActionButton(
                    icon: Icons.mood,
                    label: 'Log Mood',
                    color: Colors.purple.shade400,
                    onPressed: () => _showMoodDialog(DateTime.now()),
                  ),
                  _buildActionButton(
                    icon: Icons.local_hospital,
                    label: 'Log Symptoms',
                    color: Colors.blue.shade400,
                    onPressed: () => _showSymptomDialog(DateTime.now()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
      ),
    );
  }

  Color _getStatusColor() {
    final phase = _getCyclePhase();
    switch (phase) {
      case 'Period': return Colors.pink;
      case 'Follicular Phase': return Colors.blue;
      case 'Luteal Phase': return Colors.purple;
      default: return Colors.grey;
    }
  }

  double _getCycleProgress() {
    if (cycleData.lastPeriod == null) return 0.0;
    final currentDay = _getCurrentDayInCycle();
    return currentDay / cycleData.cycleLength;
  }

  int _getCurrentDayInCycle() {
    if (cycleData.lastPeriod == null) return 0;
    final today = DateTime.now();
    return today.difference(cycleData.lastPeriod!).inDays + 1;
  }

  void _showMoodDialog(DateTime date) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Mood'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'How are you feeling?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  cycleData.moods[date] = controller.text;
                });
                _saveData();
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSymptomDialog(DateTime date) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Symptom'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Any symptoms today?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  cycleData.symptoms[date] = controller.text;
                });
                _saveData();
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  final CycleData cycleData;
  final Function onDataChanged;

  CalendarScreen({required this.cycleData, required this.onDataChanged});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, date, events) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
                todayBuilder: (context, date, events) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purple.shade200, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(color: Colors.purple.shade400),
                    ),
                  );
                },
                markerBuilder: (context, date, events) {
                  List<Widget> markers = [];
                  
                  // Period day marker
                  if (widget.cycleData.periodDays.any((periodDay) => isSameDay(periodDay, date))) {
                    markers.add(
                      Positioned(
                        bottom: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Fertile window marker
                  if (widget.cycleData.fertileWindow != null &&
                      date.isAfter(widget.cycleData.fertileWindow!.start.subtract(Duration(days: 1))) &&
                      date.isBefore(widget.cycleData.fertileWindow!.end.add(Duration(days: 1)))) {
                    markers.add(
                      Positioned(
                        top: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Mood marker
                  if (widget.cycleData.moods.containsKey(date)) {
                    markers.add(
                      Positioned(
                        left: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Symptom marker
                  if (widget.cycleData.symptoms.containsKey(date)) {
                    markers.add(
                      Positioned(
                        right: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return markers.isEmpty ? SizedBox.shrink() : Stack(
                    children: markers,
                    alignment: Alignment.center,
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                weekendDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                defaultDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple.shade200, width: 1),
                ),
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                formatButtonTextStyle: TextStyle(color: Colors.purple.shade800),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.grey[700]),
                weekendStyle: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ),
          
          if (_selectedDay != null) ...[
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Selected Day: ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCalendarButton(
                          label: 'Log Period',
                          color: Colors.pink.shade400,
                          onPressed: () => _logPeriodDay(_selectedDay!),
                        ),
                        _buildCalendarButton(
                          label: 'Log Mood',
                          color: Colors.purple.shade400,
                          onPressed: () {
                            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                            if (homeState != null) {
                              homeState.showMoodDialog(_selectedDay!);
                            }
                          },
                        ),
                        _buildCalendarButton(
                          label: 'Log Symptoms',
                          color: Colors.blue.shade400,
                          onPressed: () {
                            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                            if (homeState != null) {
                              homeState.showSymptomDialog(_selectedDay!);
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    // Show existing mood and symptom if any
                    if (widget.cycleData.moods.containsKey(_selectedDay!)) 
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mood, color: Colors.purple.shade400, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Mood: ${widget.cycleData.moods[_selectedDay!]}', 
                              style: TextStyle(
                                color: Colors.purple.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.cycleData.symptoms.containsKey(_selectedDay!)) 
                      Container(
                        padding: EdgeInsets.all(10),
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_hospital, color: Colors.blue.shade400, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Symptom: ${widget.cycleData.symptoms[_selectedDay!]}', 
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 2,
        minimumSize: Size(100, 40),
      ),
    );
  }

  void _logPeriodDay(DateTime date) {
    setState(() {
      if (!widget.cycleData.periodDays.any((d) => isSameDay(d, date))) {
        widget.cycleData.periodDays.add(date);
      } else {
        widget.cycleData.periodDays.removeWhere((d) => isSameDay(d, date));
      }
      widget.onDataChanged();
    });
  }
}

class StatsScreen extends StatelessWidget {
  final CycleData cycleData;

  StatsScreen({required this.cycleData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle Statistics',
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  if (cycleData.lastPeriod != null) ...[
                    _buildStatCard(
                      icon: Icons.timelapse,
                      title: 'Cycle Length',
                      value: '${cycleData.cycleLength} days',
                      color: Colors.pink.shade300,
                    ),
                    SizedBox(height: 15),
                    _buildStatCard(
                      icon: Icons.event,
                      title: 'Period Length',
                      value: '${cycleData.periodLength} days',
                      color: Colors.purple.shade300,
                    ),
                    SizedBox(height: 15),
                    _buildStatCard(
                      icon: Icons.calendar_today,
                      title: 'Last Period',
                      value: DateFormat('MMM dd, yyyy').format(cycleData.lastPeriod!),
                      color: Colors.blue.shade300,
                    ),
                  ] else
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.bar_chart, 
                            size: 60, 
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No data available yet.\nStart tracking to see statistics.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final CycleData cycleData;
  final Function onSettingsChanged;

  SettingsScreen({required this.cycleData, required this.onSettingsChanged});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cycleLengthController = TextEditingController();
  final _periodLengthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cycleLengthController.text = widget.cycleData.cycleLength.toString();
    _periodLengthController.text = widget.cycleData.periodLength.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle Settings',
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  TextField(
                    controller: _cycleLengthController,
                    decoration: InputDecoration(
                      labelText: 'Cycle Length (days)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                      ),
                      prefixIcon: Icon(Icons.timelapse, color: Colors.purple.shade400),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final newLength = int.tryParse(value);
                      if (newLength != null && newLength > 0) {
                        widget.cycleData.cycleLength = newLength;
                        widget.onSettingsChanged();
                      }
                    },
                  ),
                  
                  SizedBox(height: 20),
                  
                  TextField(
                    controller: _periodLengthController,
                    decoration: InputDecoration(
                      labelText: 'Period Length (days)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                      ),
                      prefixIcon: Icon(Icons.event, color: Colors.purple.shade400),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final newLength = int.tryParse(value);
                      if (newLength != null && newLength > 0) {
                        widget.cycleData.periodLength = newLength;
                        widget.onSettingsChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 25),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Management',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  SizedBox(height: 15),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _clearAllData,
                      icon: Icon(Icons.delete, color: Colors.white),
                      label: Text(
                        'Clear All Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Data?'),
        content: Text('This will delete all your period history and settings. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Implement clear data logic
              Navigator.pop(context);
            },
            child: Text('Clear', style: TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cycleLengthController.dispose();
    _periodLengthController.dispose();
    super.dispose();
  }
}