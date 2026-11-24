import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Brand Palette & Config (Khayr Ummah Association)
// ---------------------------------------------------------------------------
const Color kBlueDeep = Color(0xFF1B4460);
const Color kBlueDark = Color(0xFF255575);
const Color kBlueMain = Color(0xFF4383AC);
const Color kBlueLight = Color(0xFF6DABC6);
const Color kBlueSoft = Color(0xFFEBF4F9);
const Color kGold = Color(0xFFB6966C);
const Color kGoldDark = Color(0xFF96764E);
const Color kGoldSoft = Color(0xFFF8F3EC);
const Color kNavy = Color(0xFF142938);
const Color kCanvas = Color(0xFFEEF3F7);
const Color kGreen = Color(0xFF16A34A);
const Color kRed = Color(0xFFDC2626);

const String kSupabaseUrl = 'https://qnzmgybtysahnlfzhozz.supabase.co';
const String kSupabaseKey = 'sb_publishable_6bIOMApXiu-l74eYXRkjSw_qTPZHFlg';
const String kSupabaseTable = 'app_state';

const String kStorageKey = 'khayr_ummah_native_data_v1';
const String kRecentKey = 'khayr_ummah_native_recent_v1';

const List<String> kArabicMonths = [
  'كانون الثاني / يناير',
  'شباط / فبراير',
  'آذار / مارس',
  'نيسان / أبريل',
  'أيار / مايو',
  'حزيران / يونيو',
  'تموز / يوليو',
  'آب / أغسطس',
  'أيلول / سبتمبر',
  'تشرين الأول / أكتوبر',
  'تشرين الثاني / نوفمبر',
  'كانون الأول / ديسمبر',
];

String normalizeArabic(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'و\s+ال'), 'وال')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
}

final String kExpectedTeacherPass = normalizeArabic('سبحان الله و الحمد لله 33');

bool verifyTeacherPassword(String input) =>
    normalizeArabic(input) == kExpectedTeacherPass;

String monthLabel(int month, int year) {
  final idx = (month - 1).clamp(0, 11);
  return '${kArabicMonths[idx]} $year';
}

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------
class TasmiEntry {
  String text;
  String grade;
  String note;

  TasmiEntry({required this.text, required this.grade, this.note = ''});

  Map<String, dynamic> toJson() => {'text': text, 'grade': grade, 'note': note};

  factory TasmiEntry.fromJson(Map<String, dynamic> j) => TasmiEntry(
        text: (j['text'] ?? '').toString(),
        grade: (j['grade'] ?? 'ممتاز').toString(),
        note: (j['note'] ?? '').toString(),
      );
}

class MonthRecord {
  String key;
  int year;
  int month;
  String label;
  bool archived;
  Map<String, TasmiEntry?> tasmi;
  Map<String, String> attendance; // 'present' | 'absent' | 'none'

  MonthRecord({
    required this.key,
    required this.year,
    required this.month,
    required this.label,
    required this.archived,
    required this.tasmi,
    required this.attendance,
  });

  factory MonthRecord.empty(int year, int month, {bool archived = false}) {
    final t = <String, TasmiEntry?>{};
    final a = <String, String>{};
    for (int d = 1; d <= 30; d++) {
      t['$d'] = null;
      a['$d'] = 'none';
    }
    return MonthRecord(
      key: monthKey(year, month),
      year: year,
      month: month,
      label: monthLabel(month, year),
      archived: archived,
      tasmi: t,
      attendance: a,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'year': year,
        'month': month,
        'label': label,
        'archived': archived,
        'tasmi': tasmi.map((k, v) => MapEntry(k, v?.toJson())),
        'attendance': attendance,
      };

  factory MonthRecord.fromJson(Map<String, dynamic> j) {
    final tRaw = (j['tasmi'] as Map<String, dynamic>?) ?? {};
    final aRaw = (j['attendance'] as Map<String, dynamic>?) ?? {};
    final t = <String, TasmiEntry?>{};
    final a = <String, String>{};
    for (int d = 1; d <= 30; d++) {
      final dk = '$d';
      final tv = tRaw[dk];
      t[dk] = tv is Map<String, dynamic> ? TasmiEntry.fromJson(tv) : null;
      a[dk] = (aRaw[dk] ?? 'none').toString();
    }
    final y = (j['year'] is int) ? j['year'] as int : DateTime.now().year;
    final m = (j['month'] is int) ? j['month'] as int : DateTime.now().month;
    return MonthRecord(
      key: (j['key'] ?? monthKey(y, m)).toString(),
      year: y,
      month: m,
      label: (j['label'] ?? monthLabel(m, y)).toString(),
      archived: j['archived'] == true,
      tasmi: t,
      attendance: a,
    );
  }
}

class StudentModel {
  String id;
  String name;
  String age;
  String activeMonthKey;
  Map<String, MonthRecord> months;

  StudentModel({
    required this.id,
    required this.name,
    required this.age,
    required this.activeMonthKey,
    required this.months,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'activeMonthKey': activeMonthKey,
        'months': months.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory StudentModel.fromJson(Map<String, dynamic> j) {
    final mRaw = (j['months'] as Map<String, dynamic>?) ?? {};
    final parsedMonths = <String, MonthRecord>{};
    mRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        parsedMonths[k] = MonthRecord.fromJson(v);
      }
    });
    if (parsedMonths.isEmpty) {
      final now = DateTime.now();
      final empty = MonthRecord.empty(now.year, now.month);
      parsedMonths[empty.key] = empty;
    }
    return StudentModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      age: (j['age'] ?? '').toString(),
      activeMonthKey:
          (j['activeMonthKey'] ?? parsedMonths.keys.last).toString(),
      months: parsedMonths,
    );
  }
}

class CircleModel {
  String id;
  String name;
  String mosque;
  String teacher;
  String schedule;
  List<StudentModel> students;

  CircleModel({
    required this.id,
    required this.name,
    required this.mosque,
    required this.teacher,
    required this.schedule,
    required this.students,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mosque': mosque,
        'teacher': teacher,
        'schedule': schedule,
        'students': students.map((s) => s.toJson()).toList(),
      };

  factory CircleModel.fromJson(Map<String, dynamic> j) {
    final sRaw = (j['students'] as List<dynamic>?) ?? [];
    return CircleModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      mosque: (j['mosque'] ?? '').toString(),
      teacher: (j['teacher'] ?? '').toString(),
      schedule: (j['schedule'] ?? '').toString(),
      students: sRaw
          .whereType<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList(),
    );
  }
}

class AiAnalysis {
  final int present;
  final int absent;
  final int tasmiCount;
  final int attendanceRate;
  final int avgGrade;
  final int overallScore;
  final int maxStreak;
  final String level;
  final Color badgeBg;
  final Color badgeText;
  final List<String> insights;
  final List<int> weeklyPresent;
  final List<int> weeklyTasmi;
  final List<int> weeklyAbsent;

  AiAnalysis({
    required this.present,
    required this.absent,
    required this.tasmiCount,
    required this.attendanceRate,
    required this.avgGrade,
    required this.overallScore,
    required this.maxStreak,
    required this.level,
    required this.badgeBg,
    required this.badgeText,
    required this.insights,
    required this.weeklyPresent,
    required this.weeklyTasmi,
    required this.weeklyAbsent,
  });

  factory AiAnalysis.compute(MonthRecord rec, MonthRecord? prev) {
    int present = 0, absent = 0, tasmiCount = 0, gradePts = 0, streak = 0, maxStreak = 0;
    final wp = [0, 0, 0, 0];
    final wt = [0, 0, 0, 0];
    final wa = [0, 0, 0, 0];
    const gMap = {'ممتاز': 100, 'جيد جداً': 85, 'جيد': 70, 'يحتاج مراجعة': 50};

    for (int d = 1; d <= 30; d++) {
      final w = d <= 7 ? 0 : d <= 15 ? 1 : d <= 22 ? 2 : 3;
      final att = rec.attendance['$d'] ?? 'none';
      if (att == 'present') {
        present++;
        streak++;
        if (streak > maxStreak) maxStreak = streak;
        wp[w]++;
      } else if (att == 'absent') {
        absent++;
        streak = 0;
        wa[w]++;
      }
      final t = rec.tasmi['$d'];
      if (t != null && t.text.trim().isNotEmpty) {
        tasmiCount++;
        gradePts += gMap[t.grade] ?? 80;
        wt[w]++;
      }
    }

    final recorded = present + absent;
    final attRate = recorded > 0 ? ((present / recorded) * 100).round() : 0;
    final avgGrade = tasmiCount > 0 ? (gradePts / tasmiCount).round() : 0;
    final pace = present > 0
        ? ((tasmiCount / (present < 16 ? present : 16)) * 100).round().clamp(0, 100)
        : 0;
    final overall = (recorded > 0 || tasmiCount > 0)
        ? (attRate * 0.45 + avgGrade * 0.35 + pace * 0.20).round()
        : 0;

    String level = 'بانتظار تسجيل البيانات';
    Color bBg = const Color(0xFFF1F5F9);
    Color bTxt = const Color(0xFF475569);
    if (recorded > 0 || tasmiCount > 0) {
      if (overall >= 85) {
        level = 'متفوق ومنضبط';
        bBg = const Color(0xFFDCFCE7);
        bTxt = const Color(0xFF15803D);
      } else if (overall >= 70) {
        level = 'جيد جداً ومستقر';
        bBg = kBlueSoft;
        bTxt = kBlueDark;
      } else if (overall >= 55) {
        level = 'متوسط — يحتاج تشجيع';
        bBg = const Color(0xFFFEF3C7);
        bTxt = const Color(0xFFB45309);
      } else {
        level = 'يحتاج متابعة عاجلة';
        bBg = const Color(0xFFFEE2E2);
        bTxt = kRed;
      }
    }

    final insights = <String>[];
    if (recorded == 0 && tasmiCount == 0) {
      insights.add('لم يتم تسجيل حضور أو تسميع لهذا الشهر بعد. سيبدأ التحليل الذكي تلقائياً فور تسجيل أول يوم.');
    } else {
      if (attRate >= 90) {
        insights.add('انضباط ممتاز في الحضور بنسبة $attRate% مع أطول التزام متتالي بلغ $maxStreak أيام.');
      } else if (attRate >= 75) {
        insights.add('مستوى الحضور جيد ($attRate%) مع تسجيل $absent أيام غياب؛ تقليل الغياب سيرفع التقدم بسرعة.');
      } else {
        insights.add('تنبيه غياب: تم تسجيل $absent أيام غياب (الحضور $attRate%)؛ يُنصح بالتواصل مع ولي الأمر.');
      }
      if (tasmiCount >= 10 && avgGrade >= 85) {
        insights.add('إنجاز قوي في التسميع ($tasmiCount جلسات بمتوسط جودة $avgGrade%) يعكس حفظاً متيناً.');
      } else if (tasmiCount >= 5) {
        insights.add('تم إنجاز $tasmiCount جلسات تسميع هذا الشهر بمتوسط جودة $avgGrade%.');
      } else if (tasmiCount > 0) {
        insights.add('عدد جلسات التسميع ($tasmiCount) ما زال محدوداً؛ يُنصح بتكثيف الورد اليومي.');
      } else {
        insights.add('تم تسجيل الحضور ولكن لم يُسجل تسميع يومي بعد في هذا الشهر.');
      }
      if (prev != null) {
        final p = AiAnalysis.compute(prev, null);
        if (p.present + p.absent > 0) {
          final diff = overall - p.overallScore;
          if (diff >= 5) {
            insights.add('مقارنة بشهر ${prev.label}: تطوّر إيجابي بمقدار +$diff نقطة.');
          } else if (diff <= -5) {
            insights.add('مقارنة بشهر ${prev.label}: تراجع بمقدار ${diff.abs()} نقطة، يُنصح بالمراجعة.');
          } else {
            insights.add('الأداء مستقر ومتقارب مع شهر ${prev.label} (${p.overallScore}%).');
          }
        }
      }
    }

    return AiAnalysis(
      present: present,
      absent: absent,
      tasmiCount: tasmiCount,
      attendanceRate: attRate,
      avgGrade: avgGrade,
      overallScore: overall,
      maxStreak: maxStreak,
      level: level,
      badgeBg: bBg,
      badgeText: bTxt,
      insights: insights,
      weeklyPresent: wp,
      weeklyTasmi: wt,
      weeklyAbsent: wa,
    );
  }
}

// ---------------------------------------------------------------------------
// App Controller (Local Cache + Live Supabase Cloud Sync)
// ---------------------------------------------------------------------------
class AppStore extends ChangeNotifier {
  List<CircleModel> circles = [];
  List<Map<String, String>> recentSearches = [];
  bool teacherAuthed = false;
  bool isSyncing = false;

  Future<void> init() async {
    await _loadLocal();
    unawaited(syncFromCloud());
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final list = (decoded['circles'] as List<dynamic>?) ?? [];
        circles = list
            .whereType<Map<String, dynamic>>()
            .map(CircleModel.fromJson)
            .toList();
      } catch (_) {}
    }
    final recRaw = prefs.getString(kRecentKey);
    if (recRaw != null && recRaw.isNotEmpty) {
      try {
        final list = jsonDecode(recRaw) as List<dynamic>;
        recentSearches = list
            .whereType<Map<String, dynamic>>()
            .map((e) => {
                  'circleId': (e['circleId'] ?? '').toString(),
                  'studentId': (e['studentId'] ?? '').toString(),
                })
            .toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kStorageKey,
      jsonEncode({'circles': circles.map((c) => c.toJson()).toList()}),
    );
  }

  Future<void> saveRecent(String circleId, String studentId) async {
    recentSearches.removeWhere(
        (x) => x['circleId'] == circleId && x['studentId'] == studentId);
    recentSearches.insert(0, {'circleId': circleId, 'studentId': studentId});
    if (recentSearches.length > 6) {
      recentSearches = recentSearches.sublist(0, 6);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRecentKey, jsonEncode(recentSearches));
    notifyListeners();
  }

  Future<void> clearRecent() async {
    recentSearches.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kRecentKey);
    notifyListeners();
  }

  Future<bool> syncFromCloud() async {
    isSyncing = true;
    notifyListeners();
    try {
      final uri = Uri.parse(
          '$kSupabaseUrl/rest/v1/$kSupabaseTable?id=eq.main&select=data,updated_at');
      final res = await http.get(uri, headers: {
        'apikey': kSupabaseKey,
        'Accept': 'application/json',
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rows = jsonDecode(res.body) as List<dynamic>;
        if (rows.isNotEmpty && rows.first is Map<String, dynamic>) {
          final data = rows.first['data'];
          if (data is Map<String, dynamic> && data['circles'] is List) {
            circles = (data['circles'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CircleModel.fromJson)
                .toList();
            await _saveLocal();
          }
        }
        isSyncing = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    isSyncing = false;
    notifyListeners();
    return false;
  }

  Future<void> persist() async {
    notifyListeners();
    await _saveLocal();
    try {
      final uri = Uri.parse(
          '$kSupabaseUrl/rest/v1/$kSupabaseTable?on_conflict=id');
      await http.post(
        uri,
        headers: {
          'apikey': kSupabaseKey,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode({
          'id': 'main',
          'data': {'circles': circles.map((c) => c.toJson()).toList()},
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  CircleModel? findCircle(String id) {
    for (final c in circles) {
      if (c.id == id) return c;
    }
    return null;
  }

  StudentModel? findStudent(String circleId, String studentId) {
    final c = findCircle(circleId);
    if (c == null) return null;
    for (final s in c.students) {
      if (s.id == studentId) return s;
    }
    return null;
  }

  List<({CircleModel circle, StudentModel student})> searchStudents(String q) {
    final nq = normalizeArabic(q);
    if (nq.isEmpty) return [];
    final out = <({CircleModel circle, StudentModel student})>[];
    for (final c in circles) {
      for (final s in c.students) {
        if (normalizeArabic(s.name).contains(nq)) {
          out.add((circle: c, student: s));
        }
      }
    }
    return out;
  }
}

final AppStore store = AppStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  store.init();
  runApp(const KhayrUmmahApp());
}

class KhayrUmmahApp extends StatelessWidget {
  const KhayrUmmahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBlueMain,
        primary: kBlueMain,
        secondary: kGold,
      ),
    );
    return MaterialApp(
      title: 'خير أمة',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.notoNaskhArabicTextTheme(baseTheme.textTheme),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI Widgets (Curved Header + Bottom Tab Bar: Back + Home + Action)
// ---------------------------------------------------------------------------
class AppBottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onHome;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppBottomBar({
    super.key,
    this.onBack,
    required this.onHome,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2ECF3))),
        boxShadow: [
          BoxShadow(
            color: Color(0x14142938),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.arrow_forward_rounded,
                label: 'رجوع',
                bg: const Color(0xFFF1F5F9),
                fg: kNavy,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              _NavItem(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                bg: kBlueMain,
                fg: Colors.white,
                labelColor: kBlueDark,
                onTap: onHome,
              ),
              if (actionLabel != null && actionIcon != null && onAction != null)
                _NavItem(
                  icon: actionIcon!,
                  label: actionLabel!,
                  bg: kGoldSoft,
                  fg: kGoldDark,
                  labelColor: kGoldDark,
                  onTap: onAction!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color? labelColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: labelColor ?? const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurvedHeader extends StatelessWidget {
  final String subtitle;
  final String title;
  final String? caption;
  final Widget? trailing;

  const CurvedHeader({
    super.key,
    required this.subtitle,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 18, 20, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kBlueDark, kBlueMain, kBlueLight],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 12)),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(caption!,
                      style: const TextStyle(
                          color: Color(0xFFE0F2FE), fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
        ],
      ),
    );
  }
}

void goHomeRoute(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (_) => false,
  );
}

// ---------------------------------------------------------------------------
// SCREEN 1: Splash Screen (Matches user's Canva design)
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goNext,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5A91B1),
                Color(0xFF366C8E),
                Color(0xFF214B66),
                Color(0xFF2D5A77),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 155,
              height: 155,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x400F2434),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 2: Home / Role Selection (أذكر اللّٰه + معلم + طالب — No bottom logo)
// ---------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF275878), kBlueDeep],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.elliptical(220, 38),
                bottomRight: Radius.elliptical(220, 38),
              ),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text(
                  'أذكر اللّٰه',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        if (store.teacherAuthed) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const TeacherCirclesScreen()));
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const TeacherLoginScreen()));
                        }
                      },
                      child: const Text(
                        'معــلم',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlueMain,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        store.syncFromCloud();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const StudentSearchScreen()));
                      },
                      child: const Text(
                        'طـالـب',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700),
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
}

// ---------------------------------------------------------------------------
// SCREEN 3: Teacher Password Login
// ---------------------------------------------------------------------------
class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _submit() {
    if (verifyTeacherPassword(_ctrl.text)) {
      store.teacherAuthed = true;
      store.syncFromCloud();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TeacherCirclesScreen()),
      );
    } else {
      setState(() {
        _error = 'كلمة السر غير صحيحة، يرجى المحاولة مرة أخرى.';
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AppBottomBar(onHome: () => goHomeRoute(context)),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [kBlueLight, kBlueMain, kBlueDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x33142938),
                              blurRadius: 18,
                              offset: Offset(0, 8)),
                        ],
                      ),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'جمعية خير أمة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'بوابة المعلم',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFE0F2FE), fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'أهلاً بك!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ctrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة سر المعلم',
                      labelStyle: const TextStyle(color: Color(0xFFE0F2FE)),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70, width: 1.5),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kBlueDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                      elevation: 6,
                    ),
                    onPressed: _submit,
                    child: const Text(
                      'دخول المعلم',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 4: Student Search by Name (+ Saved Recent Searches, zero flashing)
// ---------------------------------------------------------------------------
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _error;

  void _openStudent(CircleModel c, StudentModel s) {
    store.saveRecent(c.id, s.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudentProfileScreen(
        circleId: c.id,
        studentId: s.id,
        isTeacher: false,
      ),
    ));
  }

  void _submitSearch() {
    final matches = store.searchStudents(_query);
    if (matches.length == 1) {
      _openStudent(matches.first.circle, matches.first.student);
    } else if (matches.length > 1) {
      setState(() => _error = 'يوجد أكثر من طالب بهذا الاسم، اختر الطالب من النتائج بالأسفل.');
    } else {
      setState(() => _error = 'لم يتم العثور على طالب بهذا الاسم. تأكد من كتابة الاسم كما سجله المعلم.');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final liveMatches = _query.trim().isEmpty
            ? <({CircleModel circle, StudentModel student})>[]
            : store.searchStudents(_query);

        final recentList = <({CircleModel circle, StudentModel student})>[];
        for (final r in store.recentSearches) {
          final c = store.findCircle(r['circleId'] ?? '');
          final s = store.findStudent(r['circleId'] ?? '', r['studentId'] ?? '');
          if (c != null && s != null) recentList.add((circle: c, student: s));
        }

        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            onHome: () => goHomeRoute(context),
            actionLabel: 'تحديث',
            actionIcon: Icons.refresh_rounded,
            onAction: () async {
              final ok = await store.syncFromCloud();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'تم تحديث البيانات من السحابة' : 'تعذر الاتصال بالسحابة'),
                ));
              }
            },
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const CurvedHeader(
                  subtitle: 'بوابة الطالب وولي الأمر',
                  title: 'ابحث عن الطالب',
                  caption: 'أدخل اسم الطالب لتفتح صفحته وجدول التسميع والغياب مباشرة',
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x18142938),
                                  blurRadius: 18,
                                  offset: Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('أدخل اسم الطالب',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() {
                                  _query = v;
                                  _error = null;
                                }),
                                onSubmitted: (_) => _submitSearch(),
                                decoration: InputDecoration(
                                  hintText: 'اكتب اسم الطالب هنا...',
                                  filled: true,
                                  fillColor: kCanvas,
                                  prefixIcon: const Icon(Icons.person_search_rounded,
                                      color: kBlueMain),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: kRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBlueMain,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: _submitSearch,
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('عرض صفحة الطالب',
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        if (_query.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('نتائج البحث (${liveMatches.length}):',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B))),
                                const SizedBox(height: 10),
                                if (liveMatches.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text('لا يوجد طالب مطابق لهذا الاسم حالياً.',
                                          style: TextStyle(color: Color(0xFF64748B))),
                                    ),
                                  )
                                else
                                  ...liveMatches.map((m) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16)),
                                          tileColor: kCanvas,
                                          leading: CircleAvatar(
                                            backgroundColor: kGreen,
                                            foregroundColor: Colors.white,
                                            child: Text(m.student.name.isNotEmpty
                                                ? m.student.name[0]
                                                : 'ط'),
                                          ),
                                          title: Text(m.student.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: kNavy)),
                                          subtitle: Text(
                                              '${m.circle.name} • ${m.circle.mosque}',
                                              style: const TextStyle(fontSize: 12)),
                                          trailing: const Text('فتح ←',
                                              style: TextStyle(
                                                  color: kBlueDark,
                                                  fontWeight: FontWeight.w700)),
                                          onTap: () => _openStudent(m.circle, m.student),
                                        ),
                                      )),
                              ],
                            ),
                          ),
                        ],
                        if (recentList.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.history_rounded,
                                            color: kGold, size: 18),
                                        SizedBox(width: 6),
                                        Text('عمليات البحث الأخيرة (المحفوظات)',
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: kNavy)),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => store.clearRecent(),
                                      child: const Text('مسح',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ),
                                  ],
                                ),
                                ...recentList.map((m) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        tileColor: kGoldSoft,
                                        leading: CircleAvatar(
                                          backgroundColor: kGold,
                                          foregroundColor: Colors.white,
                                          child: Text(m.student.name.isNotEmpty
                                              ? m.student.name[0]
                                              : 'ط'),
                                        ),
                                        title: Text(m.student.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: kNavy)),
                                        subtitle: Text(
                                            '${m.circle.name} • ${m.circle.mosque}',
                                            style: const TextStyle(fontSize: 12)),
                                        trailing: const Text('فتح ←',
                                            style: TextStyle(
                                                color: kGoldDark,
                                                fontWeight: FontWeight.w700)),
                                        onTap: () => _openStudent(m.circle, m.student),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 5: Teacher Circles List
// ---------------------------------------------------------------------------
class TeacherCirclesScreen extends StatelessWidget {
  const TeacherCirclesScreen({super.key});

  void _showAddCircleDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final mosqueCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final schedCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('إضافة حلقة جديدة',
            style: TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم الحلقة *',
                    hintText: 'مثال: حلقة أبو بكر الصديق'),
              ),
              TextField(
                controller: mosqueCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم المسجد *', hintText: 'مثال: مسجد الفرقان'),
              ),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(labelText: 'اسم المعلم'),
              ),
              TextField(
                controller: schedCtrl,
                decoration: const InputDecoration(
                    labelText: 'موعد الحلقة',
                    hintText: 'مثال: يومياً بعد صلاة العصر'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kBlueMain, foregroundColor: Colors.white),
            onPressed: () {
              final n = nameCtrl.text.trim();
              final m = mosqueCtrl.text.trim();
              if (n.isEmpty || m.isEmpty) return;
              store.circles.add(CircleModel(
                id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                name: n,
                mosque: m,
                teacher: teacherCtrl.text.trim().isEmpty
                    ? 'معلم الحلقة'
                    : teacherCtrl.text.trim(),
                schedule: schedCtrl.text.trim().isEmpty
                    ? 'يومياً'
                    : schedCtrl.text.trim(),
                students: [],
              ));
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ الحلقة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            onHome: () => goHomeRoute(context),
            actionLabel: 'حلقة جديدة',
            actionIcon: Icons.add_rounded,
            onAction: () => _showAddCircleDialog(context),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const CurvedHeader(
                  subtitle: 'بوابة المعلم',
                  title: 'حلقات التحفيظ',
                  caption: 'اختر الحلقة لعرض أسماء الطلاب أو أضف حلقة جديدة',
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (store.circles.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.menu_book_rounded,
                                    color: kBlueMain, size: 42),
                                SizedBox(height: 10),
                                Text('لا توجد حلقات مضافة بعد',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: kNavy)),
                                SizedBox(height: 4),
                                Text(
                                    'اضغط على «إضافة حلقة جديدة» بالأسفل للبدء.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          )
                        else
                          ...store.circles.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CircleStudentsScreen(circleId: c.id),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x14142938),
                                            blurRadius: 16,
                                            offset: Offset(0, 6)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: kBlueSoft,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                  Icons.book_rounded,
                                                  color: kBlueMain),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(c.name,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: kNavy)),
                                                  Text(
                                                      '${c.mosque} • ${c.schedule}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                              0xFF64748B))),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: kGoldSoft,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                  '${c.students.length} طلاب',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: kGoldDark)),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 20),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('المعلم: ${c.teacher}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B))),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: kBlueMain,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text('فتح الحلقة',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _showAddCircleDialog(context),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('إضافة حلقة جديدة',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 6: Circle Students List (Add by Name Directly — No Codes)
// ---------------------------------------------------------------------------
class CircleStudentsScreen extends StatelessWidget {
  final String circleId;
  const CircleStudentsScreen({super.key, required this.circleId});

  void _showAddStudentDialog(BuildContext context, CircleModel circle) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('إضافة طالب جديد',
            style: TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الطالب *', hintText: 'أدخل اسم الطالب الكامل'),
            ),
            TextField(
              controller: ageCtrl,
              decoration: const InputDecoration(
                  labelText: 'العمر (اختياري)', hintText: 'مثال: 12 سنة'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kBlueMain, foregroundColor: Colors.white),
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              final now = DateTime.now();
              final m = MonthRecord.empty(now.year, now.month);
              circle.students.add(StudentModel(
                id: 's_${DateTime.now().millisecondsSinceEpoch}',
                name: n,
                age: ageCtrl.text.trim(),
                activeMonthKey: m.key,
                months: {m.key: m},
              ));
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ الطالب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final circle = store.findCircle(circleId);
        if (circle == null) return const SizedBox.shrink();

        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            onHome: () => goHomeRoute(context),
            actionLabel: 'إضافة طالب',
            actionIcon: Icons.person_add_alt_1_rounded,
            onAction: () => _showAddStudentDialog(context, circle),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                CurvedHeader(
                  subtitle: '${circle.mosque} • ${circle.teacher}',
                  title: circle.name,
                  caption: 'أسماء الطلاب (${circle.students.length}) — اضغط على اسم الطالب لفتح الجدول',
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (circle.students.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.groups_rounded,
                                    color: kGold, size: 42),
                                SizedBox(height: 10),
                                Text('لا يوجد طلاب في هذه الحلقة بعد',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: kNavy)),
                              ],
                            ),
                          )
                        else
                          ...circle.students.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final s = entry.value;
                            final activeRec = s.months[s.activeMonthKey] ??
                                s.months.values.last;
                            final ai = AiAnalysis.compute(activeRec, null);
                            final bg = idx % 3 == 0
                                ? kBlueMain
                                : idx % 3 == 1
                                    ? kGold
                                    : kGreen;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                tileColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: bg,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                      s.name.isNotEmpty ? s.name[0] : 'ط',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: kNavy)),
                                subtitle: Text(
                                    'حضور ${ai.attendanceRate}% • التقدم ${ai.overallScore}%',
                                    style: const TextStyle(fontSize: 12)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kBlueMain,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text('الجدول',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StudentProfileScreen(
                                      circleId: circle.id,
                                      studentId: s.id,
                                      isTeacher: true,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () =>
                                _showAddStudentDialog(context, circle),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('إضافة طالب جديد',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 7: Student Profile (30-day Tasmi + 30-square Attendance + AI + Year)
// ---------------------------------------------------------------------------
class StudentProfileScreen extends StatefulWidget {
  final String circleId;
  final String studentId;
  final bool isTeacher;

  const StudentProfileScreen({
    super.key,
    required this.circleId,
    required this.studentId,
    required this.isTeacher,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  int? _selectedYear;
  String? _selectedMonthKey;
  String _brush = 'toggle'; // 'toggle' | 'present' | 'absent'

  void _openTasmiModal(
      StudentModel student, MonthRecord rec, int day, bool canEdit) {
    final existing = rec.tasmi['$day'];
    if (!canEdit) {
      if (existing == null || existing.text.isEmpty) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('تسميع يوم $day (${rec.label})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مقدار التسميع: ${existing.text}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('التقييم: ${existing.grade}'),
              if (existing.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('ملاحظة المعلم: ${existing.note}'),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
          ],
        ),
      );
      return;
    }

    final textCtrl = TextEditingController(text: existing?.text ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String grade = existing?.grade ?? 'ممتاز';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('تسجيل تسميع يوم $day',
              style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(
                      labelText: 'السورة / مقدار التسميع',
                      hintText: 'مثال: سورة الملك 1-15'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: grade,
                  decoration: const InputDecoration(labelText: 'التقييم'),
                  items: const ['ممتاز', 'جيد جداً', 'جيد', 'يحتاج مراجعة']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => grade = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظة للأهل (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                rec.tasmi['$day'] = null;
                store.persist();
                Navigator.pop(ctx);
              },
              child: const Text('مسح', style: TextStyle(color: kRed)),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kBlueMain, foregroundColor: Colors.white),
              onPressed: () {
                final t = textCtrl.text.trim();
                rec.tasmi['$day'] = t.isEmpty
                    ? null
                    : TasmiEntry(
                        text: t, grade: grade, note: noteCtrl.text.trim());
                if (t.isNotEmpty && (rec.attendance['$day'] ?? 'none') == 'none') {
                  rec.attendance['$day'] = 'present';
                }
                store.persist();
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _archiveAndNextMonth(StudentModel student, MonthRecord current) {
    int nextM = current.month + 1;
    int nextY = current.year;
    if (nextM > 12) {
      nextM = 1;
      nextY += 1;
    }
    final nextLbl = monthLabel(nextM, nextY);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('أرشفة الشهر وتفعيل شهر جديد',
            style: TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
        content: Text(
            'سيتم حفظ سجل ${current.label} ضمن خانة سنة ${current.year} وتفعيل شهر $nextLbl.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kGold, foregroundColor: Colors.white),
            onPressed: () {
              current.archived = true;
              final nk = monthKey(nextY, nextM);
              student.months.putIfAbsent(
                  nk, () => MonthRecord.empty(nextY, nextM));
              student.months[nk]!.archived = false;
              student.activeMonthKey = nk;
              setState(() {
                _selectedYear = nextY;
                _selectedMonthKey = nk;
              });
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد التفعيل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final circle = store.findCircle(widget.circleId);
        final student = store.findStudent(widget.circleId, widget.studentId);
        if (circle == null || student == null) return const SizedBox.shrink();

        final years = student.months.values
            .map((m) => m.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final selYear = (_selectedYear != null && years.contains(_selectedYear))
            ? _selectedYear!
            : years.first;

        final yearMonths = student.months.values
            .where((m) => m.year == selYear)
            .toList()
          ..sort((a, b) => a.month.compareTo(b.month));

        final selKey = (_selectedMonthKey != null &&
                yearMonths.any((m) => m.key == _selectedMonthKey))
            ? _selectedMonthKey!
            : yearMonths
                .firstWhere((m) => m.key == student.activeMonthKey,
                    orElse: () => yearMonths.last)
                .key;

        final current = student.months[selKey]!;
        final allSorted = student.months.values.toList()
          ..sort((a, b) => (a.year * 100 + a.month)
              .compareTo(b.year * 100 + b.month));
        final curIdx = allSorted.indexWhere((m) => m.key == current.key);
        final prev = curIdx > 0 ? allSorted[curIdx - 1] : null;
        final ai = AiAnalysis.compute(current, prev);
        final canEdit = widget.isTeacher && !current.archived;

        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            onHome: () => goHomeRoute(context),
            actionLabel: widget.isTeacher ? 'طلاب الحلقة' : 'بحث جديد',
            actionIcon: widget.isTeacher
                ? Icons.groups_rounded
                : Icons.search_rounded,
            onAction: () => Navigator.of(context).pop(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                CurvedHeader(
                  subtitle:
                      '${circle.name} • ${circle.mosque} • ${widget.isTeacher ? 'وضع المعلم' : 'متابعة الأهل'}',
                  title: student.name,
                  caption: current.label,
                  trailing: widget.isTeacher && !current.archived
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () =>
                              _archiveAndNextMonth(student, current),
                          child: const Text('شهر جديد',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      : null,
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        // Year & Month Archive Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('خانة السنة:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          color: kNavy)),
                                  ...years.map((y) => ChoiceChip(
                                        label: Text('سنة $y'),
                                        selected: y == selYear,
                                        selectedColor: kNavy,
                                        labelStyle: TextStyle(
                                            color: y == selYear
                                                ? Colors.white
                                                : kNavy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                        onSelected: (_) => setState(() {
                                          _selectedYear = y;
                                          _selectedMonthKey = null;
                                        }),
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: yearMonths.map((m) {
                                    final isSel = m.key == current.key;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                            '${m.label} ${m.archived ? '(مؤرشف)' : '(نشط)'}'),
                                        selected: isSel,
                                        selectedColor: kBlueMain,
                                        labelStyle: TextStyle(
                                            color:
                                                isSel ? Colors.white : kNavy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                        onSelected: (_) => setState(
                                            () => _selectedMonthKey = m.key),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // TABLE 1: 30-day Daily Recitation
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('التسميع اليومي (30 خانة)',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: kNavy)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kBlueSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('منجز ${ai.tasmiCount} / 30',
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: kBlueDark)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 30,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.35,
                                ),
                                itemBuilder: (_, i) {
                                  final day = i + 1;
                                  final entry = current.tasmi['$day'];
                                  final filled =
                                      entry != null && entry.text.isNotEmpty;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _openTasmiModal(
                                        student, current, day, canEdit),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? kBlueSoft.withOpacity(0.6)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: filled
                                              ? kBlueMain.withOpacity(0.45)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: filled
                                                      ? kBlueMain
                                                      : const Color(0xFFE2E8F0),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text('يوم $day',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: filled
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF475569))),
                                              ),
                                              if (filled)
                                                Flexible(
                                                  child: Text(entry.grade,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: kBlueDark)),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            filled
                                                ? entry.text
                                                : (canEdit ? '+ تسميع' : '—'),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: filled
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                              color: filled
                                                  ? kNavy
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // TABLE 2: 30-Square Attendance & Absences
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'الحضور والغياب (30 مربع — أخضر حاضر / أحمر غائب)',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: kNavy)),
                              if (canEdit) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('تبديل'),
                                      selected: _brush == 'toggle',
                                      onSelected: (_) =>
                                          setState(() => _brush = 'toggle'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('أخضر (حاضر)'),
                                      selected: _brush == 'present',
                                      selectedColor: kGreen,
                                      labelStyle: TextStyle(
                                          color: _brush == 'present'
                                              ? Colors.white
                                              : kGreen),
                                      onSelected: (_) =>
                                          setState(() => _brush = 'present'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('أحمر (غائب)'),
                                      selected: _brush == 'absent',
                                      selectedColor: kRed,
                                      labelStyle: TextStyle(
                                          color: _brush == 'absent'
                                              ? Colors.white
                                              : kRed),
                                      onSelected: (_) =>
                                          setState(() => _brush = 'absent'),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _StatBox('حاضر', '${ai.present}',
                                      const Color(0xFFDCFCE7), kGreen),
                                  const SizedBox(width: 8),
                                  _StatBox('غائب', '${ai.absent}',
                                      const Color(0xFFFEE2E2), kRed),
                                  const SizedBox(width: 8),
                                  _StatBox('الالتزام', '${ai.attendanceRate}%',
                                      kBlueSoft, kBlueDark),
                                ],
                              ),
                              const SizedBox(height: 10),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 30,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  mainAxisSpacing: 7,
                                  crossAxisSpacing: 7,
                                  childAspectRatio: 1.05,
                                ),
                                itemBuilder: (_, i) {
                                  final day = i + 1;
                                  final st =
                                      current.attendance['$day'] ?? 'none';
                                  final bg = st == 'present'
                                      ? kGreen
                                      : st == 'absent'
                                          ? kRed
                                          : const Color(0xFFF1F5F9);
                                  final fg = st == 'none'
                                      ? const Color(0xFF64748B)
                                      : Colors.white;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: !canEdit
                                        ? null
                                        : () {
                                            if (_brush == 'present') {
                                              current.attendance['$day'] =
                                                  st == 'present'
                                                      ? 'none'
                                                      : 'present';
                                            } else if (_brush == 'absent') {
                                              current.attendance['$day'] =
                                                  st == 'absent'
                                                      ? 'none'
                                                      : 'absent';
                                            } else {
                                              current.attendance['$day'] =
                                                  st == 'none'
                                                      ? 'present'
                                                      : st == 'present'
                                                          ? 'absent'
                                                          : 'none';
                                            }
                                            store.persist();
                                          },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('$day',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: fg)),
                                          Icon(
                                            st == 'present'
                                                ? Icons.check_rounded
                                                : st == 'absent'
                                                    ? Icons.close_rounded
                                                    : Icons.remove_rounded,
                                            size: 15,
                                            color: fg,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // AI Progress Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: const Border(
                                top: BorderSide(color: kGold, width: 4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('خانة التقدم بالذكاء الاصطناعي',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: kNavy)),
                                  TextButton.icon(
                                    onPressed: () {
                                      final report = [
                                        'تقرير المتابعة الشهري — جمعية خير أمة',
                                        'الطالب: ${student.name}',
                                        'الحلقة: ${circle.name} — ${circle.mosque}',
                                        'الشهر: ${current.label}',
                                        'الحضور: ${ai.present} | الغياب: ${ai.absent} (${ai.attendanceRate}%)',
                                        'التسميع: ${ai.tasmiCount} | التقدم: ${ai.overallScore}% (${ai.level})',
                                        'ملخص الذكاء الاصطناعي: ${ai.insights.join(' ')}',
                                      ].join('\n');
                                      Clipboard.setData(
                                          ClipboardData(text: report));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'تم نسخ التقرير الشهري بنجاح')));
                                    },
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 16),
                                    label: const Text('نسخ التقرير',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ai.badgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('${ai.level} — ${ai.overallScore}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ai.badgeText)),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: ai.overallScore / 100.0,
                                  minHeight: 11,
                                  backgroundColor: kCanvas,
                                  color: kBlueMain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...ai.insights.map((line) => Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: kCanvas,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(line,
                                        style: const TextStyle(
                                            fontSize: 13, color: kNavy)),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String val;
  final Color bg;
  final Color fg;

  const _StatBox(this.label, this.val, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            Text(val,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}
