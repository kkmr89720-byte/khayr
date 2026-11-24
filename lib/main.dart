import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Brand Palettes (Male: Damascene Blue + Sandy Gold | Female: Rose Pink + Rose Gold)
// ---------------------------------------------------------------------------
const Color kBlueDeep = Color(0xFF1B4460);
const Color kBlueDark = Color(0xFF255575);
const Color kBlueMain = Color(0xFF4383AC);
const Color kBlueLight = Color(0xFF6DABC6);
const Color kBlueSoft = Color(0xFFEBF4F9);
const Color kGold = Color(0xFFB6966C);
const Color kGoldDark = Color(0xFF96764E);
const Color kGoldSoft = Color(0xFFF8F3EC);

const Color kPinkDeep = Color(0xFF8C3B52);
const Color kPinkMain = Color(0xFFB45B73);
const Color kPinkLight = Color(0xFFD48B9B);
const Color kPinkSoft = Color(0xFFFCEEF2);
const Color kRoseGold = Color(0xFFC8967E);
const Color kRoseGoldDark = Color(0xFF9E6E58);

const Color kNavy = Color(0xFF142938);
const Color kCanvasLight = Color(0xFFEEF3F7);
const Color kCanvasDark = Color(0xFF0E1D28);
const Color kCardDark = Color(0xFF162A3A);
const Color kGreen = Color(0xFF16A34A);
const Color kAmber = Color(0xFFD97706);
const Color kRed = Color(0xFFDC2626);

const String kSupabaseUrl = 'https://qnzmgybtysahnlfzhozz.supabase.co';
const String kSupabaseKey = 'sb_publishable_6bIOMApXiu-l74eYXRkjSw_qTPZHFlg';
const String kSupabaseTable = 'app_state';

const String kStorageKey = 'khayr_ummah_native_data_v1';
const String kRecentKey = 'khayr_ummah_native_recent_v1';
const String kDarkKey = 'khayr_ummah_dark_mode_v1';

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

final String kTeacherPassNorm = normalizeArabic('سبحان الله و الحمد لله 33');
final String kAdminPassNorm = normalizeArabic('خير أمة 2026');

bool verifyTeacherPassword(String input) =>
    normalizeArabic(input) == kTeacherPassNorm;

bool verifyAdminPassword(String input) =>
    normalizeArabic(input) == kAdminPassNorm;

String monthLabel(int month, int year) {
  final idx = (month - 1).clamp(0, 11);
  return '${kArabicMonths[idx]} $year';
}

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

// Helper for circle-gender dynamic theme colors
class CirclePalette {
  final bool isFemale;
  final Color deep;
  final Color main;
  final Color light;
  final Color soft;
  final Color accent;
  final Color accentDark;
  final String studentWord;
  final String teacherWord;

  const CirclePalette({
    required this.isFemale,
    required this.deep,
    required this.main,
    required this.light,
    required this.soft,
    required this.accent,
    required this.accentDark,
    required this.studentWord,
    required this.teacherWord,
  });

  factory CirclePalette.forGender(String gender) {
    if (gender == 'female') {
      return const CirclePalette(
        isFemale: true,
        deep: kPinkDeep,
        main: kPinkMain,
        light: kPinkLight,
        soft: kPinkSoft,
        accent: kRoseGold,
        accentDark: kRoseGoldDark,
        studentWord: 'الطالبة',
        teacherWord: 'معلمة الحلقة',
      );
    }
    return const CirclePalette(
      isFemale: false,
      deep: kBlueDark,
      main: kBlueMain,
      light: kBlueLight,
      soft: kBlueSoft,
      accent: kGold,
      accentDark: kGoldDark,
      studentWord: 'الطالب',
      teacherWord: 'معلم الحلقة',
    );
  }
}

// ---------------------------------------------------------------------------
// Data Models (100% Backward Compatible with Existing Supabase Data)
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
  Map<String, String> attendance; // 'present' | 'excused' | 'absent' | 'none'

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
  int juzCount; // 0..30 memorized Juz
  String activeMonthKey;
  Map<String, MonthRecord> months;

  StudentModel({
    required this.id,
    required this.name,
    required this.age,
    this.juzCount = 0,
    required this.activeMonthKey,
    required this.months,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'juzCount': juzCount,
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
    final juzRaw = j['juzCount'];
    final juz = juzRaw is int ? juzRaw.clamp(0, 30) : 0;
    return StudentModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      age: (j['age'] ?? '').toString(),
      juzCount: juz,
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
  String gender; // 'male' | 'female'
  String password; // per-circle password set inside app
  String announcement; // circle announcements board
  List<StudentModel> students;

  CircleModel({
    required this.id,
    required this.name,
    required this.mosque,
    required this.teacher,
    required this.schedule,
    this.gender = 'male',
    this.password = '',
    this.announcement = '',
    required this.students,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mosque': mosque,
        'teacher': teacher,
        'schedule': schedule,
        'gender': gender,
        'password': password,
        'announcement': announcement,
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
      gender: (j['gender'] == 'female') ? 'female' : 'male',
      password: (j['password'] ?? '').toString(),
      announcement: (j['announcement'] ?? '').toString(),
      students: sRaw
          .whereType<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList(),
    );
  }
}

class AiAnalysis {
  final int present;
  final int excused;
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
  final List<({String title, IconData icon, Color color})> badges;

  AiAnalysis({
    required this.present,
    required this.excused,
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
    required this.badges,
  });

  factory AiAnalysis.compute(MonthRecord rec, MonthRecord? prev) {
    int present = 0,
        excused = 0,
        absent = 0,
        tasmiCount = 0,
        gradePts = 0,
        streak = 0,
        maxStreak = 0;
    const gMap = {'ممتاز': 100, 'جيد جداً': 85, 'جيد': 70, 'يحتاج مراجعة': 50};

    for (int d = 1; d <= 30; d++) {
      final att = rec.attendance['$d'] ?? 'none';
      if (att == 'present') {
        present++;
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else if (att == 'excused') {
        excused++;
      } else if (att == 'absent') {
        absent++;
        streak = 0;
      }
      final t = rec.tasmi['$d'];
      if (t != null && t.text.trim().isNotEmpty) {
        tasmiCount++;
        gradePts += gMap[t.grade] ?? 80;
      }
    }

    // Excused absences do not penalize attendance rate
    final counted = present + absent;
    final attRate = counted > 0
        ? ((present / counted) * 100).round()
        : (excused > 0 ? 100 : 0);
    final avgGrade = tasmiCount > 0 ? (gradePts / tasmiCount).round() : 0;
    final pace = present > 0
        ? ((tasmiCount / (present < 16 ? present : 16)) * 100)
            .round()
            .clamp(0, 100)
        : 0;
    final overall = (counted > 0 || tasmiCount > 0)
        ? (attRate * 0.45 + avgGrade * 0.35 + pace * 0.20).round()
        : 0;

    String level = 'بانتظار تسجيل البيانات';
    Color bBg = const Color(0xFFF1F5F9);
    Color bTxt = const Color(0xFF475569);
    if (counted > 0 || tasmiCount > 0) {
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
    if (counted == 0 && excused == 0 && tasmiCount == 0) {
      insights.add(
          'لم يتم تسجيل حضور أو تسميع لهذا الشهر بعد. سيبدأ التحليل الذكي تلقائياً فور تسجيل أول يوم.');
    } else {
      if (attRate >= 90) {
        insights.add(
            'انضباط ممتاز في الحضور بنسبة $attRate% مع أطول التزام متتالي بلغ $maxStreak أيام.');
      } else if (attRate >= 75) {
        insights.add(
            'مستوى الحضور جيد ($attRate%) مع تسجيل $absent أيام غياب بدون عذر${excused > 0 ? ' و$excused بعذر' : ''}.');
      } else {
        insights.add(
            'تنبيه غياب: تم تسجيل $absent أيام غياب بدون عذر (الحضور $attRate%)؛ يُنصح بالتواصل مع ولي الأمر.');
      }
      if (tasmiCount >= 10 && avgGrade >= 85) {
        insights.add(
            'إنجاز قوي في التسميع ($tasmiCount جلسات بمتوسط جودة $avgGrade%) يعكس حفظاً متيناً.');
      } else if (tasmiCount >= 5) {
        insights.add(
            'تم إنجاز $tasmiCount جلسات تسميع هذا الشهر بمتوسط جودة $avgGrade%.');
      } else if (tasmiCount > 0) {
        insights.add(
            'عدد جلسات التسميع ($tasmiCount) ما زال محدوداً؛ يُنصح بتكثيف الورد اليومي.');
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
            insights.add(
                'مقارنة بشهر ${prev.label}: تراجع بمقدار ${diff.abs()} نقطة، يُنصح بالمراجعة.');
          } else {
            insights.add(
                'الأداء مستقر ومتقارب مع شهر ${prev.label} (${p.overallScore}%).');
          }
        }
      }
    }

    // Automatic Achievement Badges
    final badges = <({String title, IconData icon, Color color})>[];
    if (present >= 8 && absent == 0) {
      badges.add((
        title: 'بطل الالتزام',
        icon: Icons.verified_rounded,
        color: kGreen,
      ));
    }
    if (tasmiCount >= 15) {
      badges.add((
        title: 'مثابر التسميع',
        icon: Icons.menu_book_rounded,
        color: kBlueMain,
      ));
    }
    if (overall >= 90 && (present + tasmiCount) >= 5) {
      badges.add((
        title: 'نجم التميّز',
        icon: Icons.workspace_premium_rounded,
        color: kGoldDark,
      ));
    }

    return AiAnalysis(
      present: present,
      excused: excused,
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
      badges: badges,
    );
  }
}

// ---------------------------------------------------------------------------
// App Store (Local Cache + Live Supabase Cloud Sync + Dark Mode)
// ---------------------------------------------------------------------------
class AppStore extends ChangeNotifier {
  List<CircleModel> circles = [];
  List<Map<String, String>> recentSearches = [];
  final Set<String> unlockedCircleIds = {};
  bool teacherAuthed = false;
  bool darkMode = false;
  bool isSyncing = false;
  bool shownStarsBanner = false;

  Future<void> init() async {
    await _loadLocal();
    unawaited(syncFromCloud());
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(kDarkKey) ?? false;
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

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDarkKey, darkMode);
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
      final uri =
          Uri.parse('$kSupabaseUrl/rest/v1/$kSupabaseTable?on_conflict=id');
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

  // Top 3 Students of the Month ("نجوم الشهر") across all circles
  List<({StudentModel student, CircleModel circle, int score})> getTopThreeStars() {
    final scored = <({StudentModel student, CircleModel circle, int score})>[];
    for (final c in circles) {
      for (final s in c.students) {
        final rec = s.months[s.activeMonthKey] ?? s.months.values.last;
        final ai = AiAnalysis.compute(rec, null);
        if (ai.overallScore > 0) {
          scored.add((student: s, circle: c, score: ai.overallScore));
        }
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).toList();
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
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final isDark = store.darkMode;
        final base = isDark
            ? ThemeData.dark(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: kCanvasDark,
                cardColor: kCardDark,
                colorScheme: ColorScheme.fromSeed(
                  brightness: Brightness.dark,
                  seedColor: kBlueMain,
                  primary: kBlueLight,
                  secondary: kGold,
                ),
              )
            : ThemeData.light(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: kCanvasLight,
                cardColor: Colors.white,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: kBlueMain,
                  primary: kBlueMain,
                  secondary: kGold,
                ),
              );

        return MaterialApp(
          title: 'خير أمة',
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: GoogleFonts.notoNaskhArabicTextTheme(base.textTheme),
          ),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------
class AppBottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onHome;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color accentColor;

  const AppBottomBar({
    super.key,
    this.onBack,
    required this.onHome,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.accentColor = kBlueMain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = store.darkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kCardDark : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? const Color(0xFF243B4E) : const Color(0xFFE2ECF3)),
        ),
        boxShadow: const [
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
                bg: isDark ? const Color(0xFF213749) : const Color(0xFFF1F5F9),
                fg: isDark ? Colors.white : kNavy,
                labelColor: isDark ? Colors.white70 : const Color(0xFF475569),
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              _NavItem(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                bg: accentColor,
                fg: Colors.white,
                labelColor: isDark ? Colors.white : accentColor,
                onTap: onHome,
              ),
              if (actionLabel != null && actionIcon != null && onAction != null)
                _NavItem(
                  icon: actionIcon!,
                  label: actionLabel!,
                  bg: isDark ? const Color(0xFF2A3B48) : kGoldSoft,
                  fg: kGold,
                  labelColor: isDark ? const Color(0xFFE7CEAC) : kGoldDark,
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
  final Color labelColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.labelColor,
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
                color: labelColor,
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
  final List<Color> gradientColors;

  const CurvedHeader({
    super.key,
    required this.subtitle,
    required this.title,
    this.caption,
    this.trailing,
    this.gradientColors = const [kBlueDark, kBlueMain, kBlueLight],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 18, 20, 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.only(
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700)),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(caption!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              Container(
                width: 46,
                height: 46,
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

Future<bool> askAdminPassword(BuildContext context, String actionTitle) async {
  final ctrl = TextEditingController();
  bool obscure = true;
  String? err;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(actionTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يتطلب هذا الإجراء إدخال رمز الإدارة الخاص بالحلقات:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'رمز الإدارة',
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!,
                  style: const TextStyle(
                      color: kRed, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kBlueMain, foregroundColor: Colors.white),
            onPressed: () {
              if (verifyAdminPassword(ctrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                setS(() => err = 'رمز الإدارة غير صحيح');
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ),
  );
  return result == true;
}

// ---------------------------------------------------------------------------
// SCREEN 1: Splash Screen
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
// SCREEN 2: Home Screen ("اذكر اللّه" + Upgraded Buttons + "نجوم الشهر" Card)
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeNotifyTopStars());
  }

  void _maybeNotifyTopStars() {
    if (store.shownStarsBanner || !mounted) return;
    final stars = store.getTopThreeStars();
    if (stars.isEmpty) return;
    store.shownStarsBanner = true;
    final names = stars.map((e) => e.student.name).join(' • ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kBlueDeep,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Color(0xFFF3D5A5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'نجوم الشهر: $names',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final isDark = store.darkMode;
        final stars = store.getTopThreeStars();

        return Scaffold(
          backgroundColor: isDark ? kCanvasDark : const Color(0xFFF7FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              children: [
                // Top Curved Header with "اذكر اللّه" in Amiri Calligraphy + Dark Mode Toggle
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 12,
                      bottom: 34,
                      left: 18,
                      right: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF275878), kBlueDeep],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.elliptical(240, 34),
                      bottomRight: Radius.elliptical(240, 34),
                    ),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                          onPressed: () => store.toggleDarkMode(),
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      Text(
                        'اذكر اللّه',
                        style: GoogleFonts.amiri(
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Elevated Pill Buttons ("معلم" & "طالب") — Cleanly Spaced Above "نجوم الشهر"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _RoleGradientButton(
                        label: 'معلم',
                        icon: Icons.school_rounded,
                        colors: const [Color(0xFFC4A47A), Color(0xFF9E7C52)],
                        onTap: () {
                          if (store.teacherAuthed) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const TeacherCirclesScreen()));
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const TeacherLoginScreen()));
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _RoleGradientButton(
                        label: 'طالب',
                        icon: Icons.menu_book_rounded,
                        colors: const [Color(0xFF4C8DB6), Color(0xFF2B6082)],
                        onTap: () {
                          store.syncFromCloud();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const StudentSearchScreen()));
                        },
                      ),
                    ],
                  ),
                ),

                // Generous clean whitespace between "طالب" button and "نجوم الشهر" badge (ZERO overlap!)
                const SizedBox(height: 36),

                // Layered Arched "نجوم الشهر" Card (Exact Reference Style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 30),
                        decoration: BoxDecoration(
                          color: isDark ? kCardDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.25 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Curved Blue Decorative Top Band
                            Container(
                              height: 36,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [kBlueDeep, kBlueMain],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: kGold, width: 2),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 34, 14, 16),
                              child: stars.isEmpty
                                  ? Text(
                                      'سيظهر هنا أفضل 3 طلاب لهذا الشهر تلقائياً فور تسجيل التسميع والحضور.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF64748B),
                                      ),
                                    )
                                  : Column(
                                      children:
                                          stars.asMap().entries.map((entry) {
                                        final rank = entry.key + 1;
                                        final item = entry.value;
                                        final rankColor = rank == 1
                                            ? kGold
                                            : rank == 2
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFFB87333);
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 9),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1D3548)
                                                : const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF28465E)
                                                  : const Color(0xFFE5EEF5),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: rankColor,
                                                      width: 2.5),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$rank',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: rankColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.student.name,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: isDark
                                                            ? Colors.white
                                                            : kNavy,
                                                      ),
                                                    ),
                                                    Text(
                                                      item.circle.name,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors.white60
                                                            : const Color(
                                                                0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: kBlueSoft,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  '${item.score}%',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: kBlueDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      // Protruding Gold Inner-Framed Title Badge ("نجوم الشهر")
                      Container(
                        width: 112,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFC9AA80), Color(0xFF9F7E54)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33142938),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.65),
                                width: 1.2),
                          ),
                          child: const Text(
                            'نجوم\nالشهر',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _RoleGradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _RoleGradientButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(icon, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 3: Teacher Login Screen
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
      setState(() => _error = 'كلمة السر غير صحيحة، يرجى المحاولة مرة أخرى.');
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
                  const Text('جمعية خير أمة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700)),
                  const Text('بوابة المعلم',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFE0F2FE), fontSize: 13)),
                  const SizedBox(height: 28),
                  const Text('أهلاً بك!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
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
                        borderSide:
                            BorderSide(color: Colors.white70, width: 1.5),
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
                        color: kRed.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
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
                    child: const Text('دخول المعلم',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
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
// SCREEN 4: Student Search by Name (Auto-themes Student Page to Pink/Blue)
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
      setState(() =>
          _error = 'يوجد أكثر من طالب بهذا الاسم، اختر الاسم من النتائج بالأسفل.');
    } else {
      setState(() => _error =
          'لم يتم العثور على طالب بهذا الاسم. تأكد من كتابة الاسم كما سجله المعلم.');
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
        final isDark = store.darkMode;
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
                  content: Text(
                      ok ? 'تم تحديث البيانات من السحابة' : 'تعذر الاتصال بالسحابة'),
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
                            color: isDark ? kCardDark : Colors.white,
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
                              const Text('أدخل اسم الطالب أو الطالبة',
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
                                  hintText: 'اكتب الاسم هنا...',
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF1F3547)
                                      : kCanvasLight,
                                  prefixIcon: const Icon(
                                      Icons.person_search_rounded,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: _submitSearch,
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('عرض الصفحة',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
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
                              color: isDark ? kCardDark : Colors.white,
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
                                      child: Text(
                                          'لا يوجد اسم مطابق حالياً.',
                                          style: TextStyle(
                                              color: Color(0xFF64748B))),
                                    ),
                                  )
                                else
                                  ...liveMatches.map((m) {
                                    final pal = CirclePalette.forGender(
                                        m.circle.gender);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        tileColor: isDark
                                            ? const Color(0xFF1F3547)
                                            : pal.soft,
                                        leading: CircleAvatar(
                                          backgroundColor: pal.main,
                                          foregroundColor: Colors.white,
                                          child: Text(m.student.name.isNotEmpty
                                              ? m.student.name[0]
                                              : 'ط'),
                                        ),
                                        title: Text(m.student.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        subtitle: Text(
                                            '${m.circle.name} • ${m.circle.mosque}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        trailing: Text('فتح ←',
                                            style: TextStyle(
                                                color: pal.main,
                                                fontWeight: FontWeight.w700)),
                                        onTap: () =>
                                            _openStudent(m.circle, m.student),
                                      ),
                                    );
                                  }),
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
                              color: isDark ? kCardDark : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.history_rounded,
                                            color: kGold, size: 18),
                                        SizedBox(width: 6),
                                        Text('عمليات البحث الأخيرة (المحفوظات)',
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => store.clearRecent(),
                                      child: const Text('مسح',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ),
                                  ],
                                ),
                                ...recentList.map((m) {
                                  final pal =
                                      CirclePalette.forGender(m.circle.gender);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      tileColor: isDark
                                          ? const Color(0xFF1F3547)
                                          : pal.soft,
                                      leading: CircleAvatar(
                                        backgroundColor: pal.accent,
                                        foregroundColor: Colors.white,
                                        child: Text(m.student.name.isNotEmpty
                                            ? m.student.name[0]
                                            : 'ط'),
                                      ),
                                      title: Text(m.student.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                          '${m.circle.name} • ${m.circle.mosque}',
                                          style: const TextStyle(fontSize: 12)),
                                      trailing: Text('فتح ←',
                                          style: TextStyle(
                                              color: pal.accentDark,
                                              fontWeight: FontWeight.w700)),
                                      onTap: () =>
                                          _openStudent(m.circle, m.student),
                                    ),
                                  );
                                }),
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
// SCREEN 5: Teacher Circles List (Admin-Protected Create + Per-Circle Pass + Edit/Delete)
// ---------------------------------------------------------------------------
class TeacherCirclesScreen extends StatelessWidget {
  const TeacherCirclesScreen({super.key});

  Future<void> _openCircle(BuildContext context, CircleModel c) async {
    if (c.password.trim().isEmpty || store.unlockedCircleIds.contains(c.id)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CircleStudentsScreen(circleId: c.id)),
      );
      return;
    }

    final ctrl = TextEditingController();
    bool obscure = true;
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('دخول ${c.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل كلمة مرور هذه الحلقة للمتابعة:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'كلمة مرور الحلقة',
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!,
                    style: const TextStyle(
                        color: kRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CirclePalette.forGender(c.gender).main,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final v = ctrl.text.trim();
                if (normalizeArabic(v) == normalizeArabic(c.password) ||
                    verifyAdminPassword(v)) {
                  store.unlockedCircleIds.add(c.id);
                  Navigator.pop(ctx, true);
                } else {
                  setS(() => err = 'كلمة مرور الحلقة غير صحيحة');
                }
              },
              child: const Text('دخول'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CircleStudentsScreen(circleId: c.id)),
      );
    }
  }

  Future<void> _showCircleForm(BuildContext context, {CircleModel? edit}) async {
    final authorized = await askAdminPassword(
      context,
      edit == null ? 'إنشاء حلقة جديدة' : 'تعديل بيانات الحلقة',
    );
    if (!authorized || !context.mounted) return;

    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final mosqueCtrl = TextEditingController(text: edit?.mosque ?? '');
    final teacherCtrl = TextEditingController(text: edit?.teacher ?? '');
    final schedCtrl = TextEditingController(text: edit?.schedule ?? '');
    final passCtrl = TextEditingController(text: edit?.password ?? '');
    String gender = edit?.gender ?? 'male';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(edit == null ? 'إضافة حلقة جديدة' : 'تعديل الحلقة',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      labelText: 'اسم المسجد *',
                      hintText: 'مثال: مسجد الفرقان'),
                ),
                TextField(
                  controller: teacherCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المعلم / المعلمة'),
                ),
                TextField(
                  controller: schedCtrl,
                  decoration: const InputDecoration(
                      labelText: 'موعد الحلقة',
                      hintText: 'مثال: يومياً بعد صلاة العصر'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كلمة مرور خاصة بالحلقة *',
                    hintText: 'يستخدمها معلم هذه الحلقة فقط',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('نوع الحلقة (يحدّد ألوان الصفحات تلقائياً):',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('ذكور (أزرق)')),
                        selected: gender == 'male',
                        selectedColor: kBlueMain,
                        labelStyle: TextStyle(
                            color: gender == 'male' ? Colors.white : null,
                            fontWeight: FontWeight.w700),
                        onSelected: (_) => setS(() => gender = 'male'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('إناث (وردي)')),
                        selected: gender == 'female',
                        selectedColor: kPinkMain,
                        labelStyle: TextStyle(
                            color: gender == 'female' ? Colors.white : null,
                            fontWeight: FontWeight.w700),
                        onSelected: (_) => setS(() => gender = 'female'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gender == 'female' ? kPinkMain : kBlueMain,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final n = nameCtrl.text.trim();
                final m = mosqueCtrl.text.trim();
                if (n.isEmpty || m.isEmpty) return;
                if (edit == null) {
                  final newC = CircleModel(
                    id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                    name: n,
                    mosque: m,
                    teacher: teacherCtrl.text.trim().isEmpty
                        ? (gender == 'female' ? 'معلمة الحلقة' : 'معلم الحلقة')
                        : teacherCtrl.text.trim(),
                    schedule: schedCtrl.text.trim().isEmpty
                        ? 'يومياً'
                        : schedCtrl.text.trim(),
                    gender: gender,
                    password: passCtrl.text.trim(),
                    students: [],
                  );
                  store.circles.add(newC);
                  store.unlockedCircleIds.add(newC.id);
                } else {
                  edit.name = n;
                  edit.mosque = m;
                  edit.teacher = teacherCtrl.text.trim();
                  edit.schedule = schedCtrl.text.trim();
                  edit.gender = gender;
                  edit.password = passCtrl.text.trim();
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

  Future<void> _deleteCircle(BuildContext context, CircleModel c) async {
    final authorized = await askAdminPassword(context, 'حذف الحلقة');
    if (!authorized || !context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('تأكيد حذف الحلقة',
            style: TextStyle(fontWeight: FontWeight.w700, color: kRed)),
        content: Text(
            'هل أنت متأكد من حذف "${c.name}" مع جميع طلابها (${c.students.length})؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      store.circles.removeWhere((x) => x.id == c.id);
      store.persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final isDark = store.darkMode;
        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            onHome: () => goHomeRoute(context),
            actionLabel: 'حلقة جديدة',
            actionIcon: Icons.add_rounded,
            onAction: () => _showCircleForm(context),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const CurvedHeader(
                  subtitle: 'بوابة المعلم',
                  title: 'حلقات التحفيظ',
                  caption: 'اختر حلقتك للدخول بكلمة مرور الحلقة',
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
                              color: isDark ? kCardDark : Colors.white,
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
                                        fontSize: 16)),
                                SizedBox(height: 4),
                                Text(
                                    'اضغط «إضافة حلقة جديدة» وأدخل رمز الإدارة للبدء.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          )
                        else
                          ...store.circles.map((c) {
                            final pal = CirclePalette.forGender(c.gender);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => _openCircle(context, c),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? kCardDark : Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border(
                                      right: BorderSide(
                                          color: pal.main, width: 4),
                                    ),
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
                                              color: pal.soft,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              c.password.isNotEmpty
                                                  ? Icons.lock_outline_rounded
                                                  : Icons.book_rounded,
                                              color: pal.main,
                                            ),
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
                                                            FontWeight.w700)),
                                                Text(
                                                    '${c.mosque} • ${c.schedule}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                            0xFF64748B))),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'edit') {
                                                _showCircleForm(context,
                                                    edit: c);
                                              } else if (v == 'delete') {
                                                _deleteCircle(context, c);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('تعديل الحلقة')),
                                              PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('حذف الحلقة',
                                                      style: TextStyle(
                                                          color: kRed))),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              '${c.teacher} • ${c.students.length} ${pal.isFemale ? 'طالبات' : 'طلاب'}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: pal.main,
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
                            onPressed: () => _showCircleForm(context),
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
// SCREEN 6: Circle Students (Auto-Themed Pink/Blue + Announcements + Edit/Delete/Transfer)
// ---------------------------------------------------------------------------
class CircleStudentsScreen extends StatelessWidget {
  final String circleId;
  const CircleStudentsScreen({super.key, required this.circleId});

  void _editAnnouncement(BuildContext context, CircleModel circle) {
    final ctrl = TextEditingController(text: circle.announcement);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('لوحة إعلانات الحلقة',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'مثال: الخميس اختبار جزء عمّ أو موعد رحلة الحلقة...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              circle.announcement = '';
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('مسح الإعلان', style: TextStyle(color: kRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CirclePalette.forGender(circle.gender).main,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              circle.announcement = ctrl.text.trim();
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('نشر الإعلان'),
          ),
        ],
      ),
    );
  }

  void _showStudentForm(BuildContext context, CircleModel circle,
      {StudentModel? edit}) {
    final pal = CirclePalette.forGender(circle.gender);
    final nameCtrl = TextEditingController(text: edit?.name ?? '');
    final ageCtrl = TextEditingController(text: edit?.age ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            edit == null
                ? 'إضافة ${pal.isFemale ? 'طالبة جديدة' : 'طالب جديد'}'
                : 'تعديل بيانات ${pal.studentWord}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: 'اسم ${pal.studentWord} الكامل *'),
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
                backgroundColor: pal.main, foregroundColor: Colors.white),
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              if (edit == null) {
                final now = DateTime.now();
                final m = MonthRecord.empty(now.year, now.month);
                circle.students.add(StudentModel(
                  id: 's_${DateTime.now().millisecondsSinceEpoch}',
                  name: n,
                  age: ageCtrl.text.trim(),
                  activeMonthKey: m.key,
                  months: {m.key: m},
                ));
              } else {
                edit.name = n;
                edit.age = ageCtrl.text.trim();
              }
              store.persist();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(
      BuildContext context, CircleModel circle, StudentModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('تأكيد الحذف',
            style: TextStyle(fontWeight: FontWeight.w700, color: kRed)),
        content: Text('هل أنت متأكد من حذف "${s.name}" مع كامل سجله؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      circle.students.removeWhere((x) => x.id == s.id);
      store.persist();
    }
  }

  Future<void> _transferStudent(
      BuildContext context, CircleModel fromCircle, StudentModel s) async {
    final others = store.circles.where((c) => c.id != fromCircle.id).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد حلقة أخرى للنقل إليها بعد.')));
      return;
    }

    // Protected by Admin Circle-Creation Password ("خير أمة 2026")
    final authorized = await askAdminPassword(context, 'نقل طالب إلى حلقة أخرى');
    if (!authorized || !context.mounted) return;

    String targetId = others.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('نقل ${s.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر الحلقة التي سينتقل إليها مع كامل سجله وأرشيفه:'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: targetId,
                items: others
                    .map((c) => DropdownMenuItem(
                        value: c.id, child: Text('${c.name} (${c.mosque})')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setS(() => targetId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kBlueMain, foregroundColor: Colors.white),
              onPressed: () {
                final dest = store.findCircle(targetId);
                if (dest != null) {
                  fromCircle.students.removeWhere((x) => x.id == s.id);
                  dest.students.add(s);
                  store.persist();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تم نقل ${s.name} إلى ${dest.name} بنجاح')));
                }
              },
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
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
        final pal = CirclePalette.forGender(circle.gender);
        final isDark = store.darkMode;

        return Scaffold(
          bottomNavigationBar: AppBottomBar(
            accentColor: pal.main,
            onHome: () => goHomeRoute(context),
            actionLabel: pal.isFemale ? 'إضافة طالبة' : 'إضافة طالب',
            actionIcon: Icons.person_add_alt_1_rounded,
            onAction: () => _showStudentForm(context, circle),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                CurvedHeader(
                  gradientColors: [pal.deep, pal.main, pal.light],
                  subtitle: '${circle.mosque} • ${circle.teacher}',
                  title: circle.name,
                  caption:
                      '${pal.isFemale ? 'أسماء الطالبات' : 'أسماء الطلاب'} (${circle.students.length})',
                  trailing: IconButton(
                    tooltip: 'إعلان الحلقة',
                    onPressed: () => _editAnnouncement(context, circle),
                    icon: const Icon(Icons.campaign_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Circle Announcement Banner
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _editAnnouncement(context, circle),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: isDark ? kCardDark : pal.soft,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: pal.accent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.campaign_rounded, color: pal.main),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    circle.announcement.isEmpty
                                        ? 'اضغط هنا لكتابة إعلان يظهر لجميع طلاب وأهالي الحلقة'
                                        : 'إعلان الحلقة: ${circle.announcement}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: circle.announcement.isEmpty
                                          ? FontWeight.normal
                                          : FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (circle.students.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: isDark ? kCardDark : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.groups_rounded,
                                    color: pal.accent, size: 42),
                                const SizedBox(height: 10),
                                Text(
                                    pal.isFemale
                                        ? 'لا توجد طالبات في هذه الحلقة بعد'
                                        : 'لا يوجد طلاب في هذه الحلقة بعد',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                              ],
                            ),
                          )
                        else
                          ...circle.students.map((s) {
                            final activeRec = s.months[s.activeMonthKey] ??
                                s.months.values.last;
                            final ai = AiAnalysis.compute(activeRec, null);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                tileColor: isDark ? kCardDark : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: pal.main,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                      s.name.isNotEmpty ? s.name[0] : 'ط',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    'حضور ${ai.attendanceRate}% • التقدم ${ai.overallScore}% • ${s.juzCount} جزء',
                                    style: const TextStyle(fontSize: 12)),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _showStudentForm(context, circle,
                                          edit: s);
                                    } else if (v == 'transfer') {
                                      _transferStudent(context, circle, s);
                                    } else if (v == 'delete') {
                                      _deleteStudent(context, circle, s);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text('تعديل البيانات')),
                                    PopupMenuItem(
                                        value: 'transfer',
                                        child: Text('نقل لحلقة أخرى (برمز الإدارة)')),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text('حذف',
                                            style: TextStyle(color: kRed))),
                                  ],
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
                              backgroundColor: pal.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _showStudentForm(context, circle),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                                pal.isFemale
                                    ? 'إضافة طالبة جديدة'
                                    : 'إضافة طالب جديد',
                                style: const TextStyle(
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
// SCREEN 7: Student Profile (Auto-Themed + Announcements + Juz Bar + Badges + Excused Yellow)
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
  String _brush = 'toggle'; // 'toggle' | 'present' | 'excused' | 'absent'

  void _openTasmiModal(
      StudentModel student, MonthRecord rec, int day, bool canEdit, Color mainCol) {
    final existing = rec.tasmi['$day'];
    if (!canEdit) {
      if (existing == null || existing.text.isEmpty) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('تسميع يوم $day (${rec.label})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'))
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
              style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  decoration: const InputDecoration(
                      labelText: 'ملاحظة للأهل (اختياري)'),
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
                  backgroundColor: mainCol, foregroundColor: Colors.white),
              onPressed: () {
                final t = textCtrl.text.trim();
                rec.tasmi['$day'] = t.isEmpty
                    ? null
                    : TasmiEntry(
                        text: t, grade: grade, note: noteCtrl.text.trim());
                if (t.isNotEmpty &&
                    (rec.attendance['$day'] ?? 'none') == 'none') {
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
            style: TextStyle(fontWeight: FontWeight.w700)),
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
              student.months
                  .putIfAbsent(nk, () => MonthRecord.empty(nextY, nextM));
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

        final pal = CirclePalette.forGender(circle.gender);
        final isDark = store.darkMode;
        final cardBg = isDark ? kCardDark : Colors.white;

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
            accentColor: pal.main,
            onHome: () => goHomeRoute(context),
            actionLabel: widget.isTeacher
                ? (pal.isFemale ? 'طالبات الحلقة' : 'طلاب الحلقة')
                : 'بحث جديد',
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
                  gradientColors: [pal.deep, pal.main, pal.light],
                  subtitle:
                      '${circle.name} • ${circle.mosque} • ${widget.isTeacher ? 'وضع المعلم' : 'متابعة الأهل'}',
                  title: student.name,
                  caption: current.label,
                  trailing: widget.isTeacher && !current.archived
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pal.accent,
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
                        // Circle Announcement Card (Visible to Student/Parent & Teacher)
                        if (circle.announcement.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F3547) : pal.soft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: pal.accent.withOpacity(0.55)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.campaign_rounded, color: pal.main),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'إعلان الحلقة: ${circle.announcement}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Automatic Achievement Badges
                        if (ai.badges.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: ai.badges
                                  .map((b) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: b.color.withOpacity(0.14),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: b.color.withOpacity(0.45)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(b.icon,
                                                size: 16, color: b.color),
                                            const SizedBox(width: 4),
                                            Text(b.title,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: b.color)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),

                        // Memorized Juz Progress Bar (0..30)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('شريط الأجزاء المحفوظة (الختمة)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  Row(
                                    children: [
                                      if (widget.isTeacher)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: student.juzCount > 0
                                              ? () {
                                                  student.juzCount--;
                                                  store.persist();
                                                }
                                              : null,
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 20),
                                        ),
                                      Text('${student.juzCount} / 30 جزء',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: pal.main)),
                                      if (widget.isTeacher)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: student.juzCount < 30
                                              ? () {
                                                  student.juzCount++;
                                                  store.persist();
                                                }
                                              : null,
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 20),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: student.juzCount / 30.0,
                                  minHeight: 10,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1F3547)
                                      : pal.soft,
                                  color: pal.accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Year & Month Archive Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
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
                                          fontSize: 12.5)),
                                  ...years.map((y) => ChoiceChip(
                                        label: Text('سنة $y'),
                                        selected: y == selYear,
                                        selectedColor: pal.deep,
                                        labelStyle: TextStyle(
                                            color:
                                                y == selYear ? Colors.white : null,
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
                                        selectedColor: pal.main,
                                        labelStyle: TextStyle(
                                            color: isSel ? Colors.white : null,
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
                            color: cardBg,
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
                                          fontWeight: FontWeight.w700)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: pal.soft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('منجز ${ai.tasmiCount} / 30',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: pal.deep)),
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
                                    onTap: () => _openTasmiModal(student,
                                        current, day, canEdit, pal.main),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? pal.main.withOpacity(
                                                isDark ? 0.28 : 0.12)
                                            : (isDark
                                                ? const Color(0xFF1C3042)
                                                : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: filled
                                              ? pal.main.withOpacity(0.55)
                                              : (isDark
                                                  ? const Color(0xFF294358)
                                                  : const Color(0xFFE2E8F0)),
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
                                                      ? pal.main
                                                      : const Color(0xFFCBD5E1),
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
                                                            : kNavy)),
                                              ),
                                              if (filled)
                                                Flexible(
                                                  child: Text(entry.grade,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : pal.deep)),
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
                                                  ? (isDark
                                                      ? Colors.white
                                                      : kNavy)
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

                        // TABLE 2: 30-Square Attendance (Green Present | Yellow Excused | Red Absent)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'الحضور والغياب (أخضر حاضر • أصفر بعذر • أحمر غائب)',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                              if (canEdit) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('تبديل'),
                                      selected: _brush == 'toggle',
                                      onSelected: (_) =>
                                          setState(() => _brush = 'toggle'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('حاضر'),
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
                                      label: const Text('بعذر'),
                                      selected: _brush == 'excused',
                                      selectedColor: kAmber,
                                      labelStyle: TextStyle(
                                          color: _brush == 'excused'
                                              ? Colors.white
                                              : kAmber),
                                      onSelected: (_) =>
                                          setState(() => _brush = 'excused'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('غائب'),
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
                                  const SizedBox(width: 6),
                                  _StatBox('بعذر', '${ai.excused}',
                                      const Color(0xFFFEF3C7), kAmber),
                                  const SizedBox(width: 6),
                                  _StatBox('غائب', '${ai.absent}',
                                      const Color(0xFFFEE2E2), kRed),
                                  const SizedBox(width: 6),
                                  _StatBox('الالتزام', '${ai.attendanceRate}%',
                                      pal.soft, pal.deep),
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
                                      : st == 'excused'
                                          ? kAmber
                                          : st == 'absent'
                                              ? kRed
                                              : (isDark
                                                  ? const Color(0xFF1F3547)
                                                  : const Color(0xFFF1F5F9));
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
                                            } else if (_brush == 'excused') {
                                              current.attendance['$day'] =
                                                  st == 'excused'
                                                      ? 'none'
                                                      : 'excused';
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
                                                          ? 'excused'
                                                          : st == 'excused'
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
                                          if (st == 'excused')
                                            Text('بعذر',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: fg))
                                          else
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
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border(
                                top: BorderSide(color: pal.accent, width: 4)),
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
                                          fontWeight: FontWeight.w700)),
                                  TextButton.icon(
                                    onPressed: () {
                                      final report = [
                                        'تقرير المتابعة الشهري — جمعية خير أمة',
                                        '${pal.studentWord}: ${student.name}',
                                        'الحلقة: ${circle.name} — ${circle.mosque}',
                                        'الأجزاء المحفوظة: ${student.juzCount} / 30',
                                        'الشهر: ${current.label}',
                                        'الحضور: ${ai.present} | بعذر: ${ai.excused} | غياب: ${ai.absent} (${ai.attendanceRate}%)',
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
                                  backgroundColor: isDark
                                      ? const Color(0xFF1F3547)
                                      : kCanvasLight,
                                  color: pal.main,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...ai.insights.map((line) => Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C3042)
                                          : kCanvasLight,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(line,
                                        style: const TextStyle(fontSize: 13)),
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
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
            Text(val,
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}
