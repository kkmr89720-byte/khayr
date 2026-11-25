import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Brand Palettes & Constants (Khayr Ummah Association v1.2)
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

const String kStorageKey = 'khayr_ummah_native_data_v12';
const String kPendingKey = 'khayr_ummah_native_pending_v12';
const String kPinnedKey = 'khayr_ummah_native_pinned_v12';
const String kRecentKey = 'khayr_ummah_native_recent_v1';
const String kDarkKey = 'khayr_ummah_dark_mode_v1';
const String kLockoutKey = 'khayr_ummah_admin_lockout_v12';
const String kDhikrIdxKey = 'khayr_ummah_dhikr_idx_v12';

// Director password stored ONLY as SHA-256 hash (never plaintext)
const String kDirectorPassSha256 =
    '364b5c39785b97c779bcc50af31c883b8e4569899c5def3e6d279d3741768c11';

const List<String> kAdhkar = [
  'اذكر اللّه',
  'سبحان اللّه وبحمده',
  'لا إله إلا اللّه',
  'لا حول ولا قوة إلا باللّه',
  'اللّه أكبر',
  'الحمد للّه رب العالمين',
  'اللهم صلِّ وسلّم على سيدنا محمد',
  'أستغفر اللّه العظيم وأتوب إليه',
  'سبحان اللّه العظيم',
  'حسبي اللّه ونعم الوكيل',
];

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

const List<String> kGrades = ['ممتاز', 'جيد جداً', 'جيد', 'يحتاج مراجعة'];

const List<Map<String, String>> kContactTypes = [
  {'id': 'whatsapp', 'label': 'واتساب', 'icon': '💬'},
  {'id': 'phone', 'label': 'اتصال هاتفي', 'icon': '📞'},
  {'id': 'instagram', 'label': 'إنستغرام', 'icon': '📸'},
  {'id': 'facebook', 'label': 'فيسبوك', 'icon': '📘'},
  {'id': 'telegram', 'label': 'تيليغرام', 'icon': '✈️'},
  {'id': 'custom', 'label': 'نص / عنوان', 'icon': '📍'},
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

// Pure-Dart SHA-256 (FIPS 180-4) — zero external crypto package needed
String sha256Hex(String input) {
  final bytes = utf8.encode(input);
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  final h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  final l = bytes.length;
  final bitLen = l * 8;
  final padLen = (l + 9 + 63) & ~63;
  final buf = Uint8List(padLen);
  buf.setRange(0, l, bytes);
  buf[l] = 0x80;
  final bd = ByteData.sublistView(buf);
  bd.setUint32(padLen - 8, bitLen ~/ 0x100000000, Endian.big);
  bd.setUint32(padLen - 4, bitLen & 0xFFFFFFFF, Endian.big);

  int rotr(int x, int n) => ((x >> n) | ((x << (32 - n)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  final w = List<int>.filled(64, 0);

  for (int i = 0; i < padLen; i += 64) {
    for (int t = 0; t < 16; t++) {
      w[t] = bd.getUint32(i + t * 4, Endian.big);
    }
    for (int t = 16; t < 64; t++) {
      final s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
      final s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
    }
    int a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (int t = 0; t < 64; t++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final temp1 = (hh + s1 + ch + k[t] + w[t]) & 0xFFFFFFFF;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}

bool verifyDirectorPassword(String input) =>
    sha256Hex(normalizeArabic(input)) == kDirectorPassSha256;

String monthLabel(int month, int year) {
  final idx = (month - 1).clamp(0, 11);
  return '${kArabicMonths[idx]} $year';
}

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

String todayIso() => DateTime.now().toIso8601String().substring(0, 10);

String genId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

class CirclePalette {
  final bool isFemale;
  final Color deep;
  final Color main;
  final Color light;
  final Color soft;
  final Color accent;
  final Color accentDark;
  final String studentWord;
  final String studentsWord;
  final String teacherWord;
  final String genderLabel;

  const CirclePalette({
    required this.isFemale,
    required this.deep,
    required this.main,
    required this.light,
    required this.soft,
    required this.accent,
    required this.accentDark,
    required this.studentWord,
    required this.studentsWord,
    required this.teacherWord,
    required this.genderLabel,
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
        studentsWord: 'الطالبات',
        teacherWord: 'معلمة الحلقة',
        genderLabel: 'حلقة إناث',
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
      studentsWord: 'الطلاب',
      teacherWord: 'معلم الحلقة',
      genderLabel: 'حلقة ذكور',
    );
  }
}

// ---------------------------------------------------------------------------
// Data Models (100% Compatible with Web v1.2 & Supabase app_state)
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
  int daysCount; // default 15, expandable up to 30
  Map<String, TasmiEntry?> tasmi;
  Map<String, String> attendance;

  MonthRecord({
    required this.key,
    required this.year,
    required this.month,
    required this.label,
    required this.archived,
    this.daysCount = 15,
    required this.tasmi,
    required this.attendance,
  });

  factory MonthRecord.empty(int year, int month, {bool archived = false, int daysCount = 15}) {
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
      daysCount: daysCount.clamp(15, 30),
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
        'daysCount': daysCount,
        'tasmi': tasmi.map((k, v) => MapEntry(k, v?.toJson())),
        'attendance': attendance,
      };

  factory MonthRecord.fromJson(Map<String, dynamic> j) {
    final tRaw = (j['tasmi'] as Map<String, dynamic>?) ?? {};
    final aRaw = (j['attendance'] as Map<String, dynamic>?) ?? {};
    final t = <String, TasmiEntry?>{};
    final a = <String, String>{};
    int maxUsed = (j['daysCount'] is int) ? (j['daysCount'] as int).clamp(15, 30) : 15;
    for (int d = 1; d <= 30; d++) {
      final dk = '$d';
      final tv = tRaw[dk];
      if (tv is Map<String, dynamic> && (tv['text'] ?? '').toString().trim().isNotEmpty) {
        t[dk] = TasmiEntry.fromJson(tv);
        if (d > maxUsed) maxUsed = d;
      } else {
        t[dk] = null;
      }
      final av = (aRaw[dk] ?? 'none').toString();
      if (av == 'present' || av == 'excused' || av == 'absent') {
        a[dk] = av;
        if (d > maxUsed) maxUsed = d;
      } else {
        a[dk] = 'none';
      }
    }
    final y = (j['year'] is int) ? j['year'] as int : DateTime.now().year;
    final m = (j['month'] is int) ? j['month'] as int : DateTime.now().month;
    return MonthRecord(
      key: (j['key'] ?? monthKey(y, m)).toString(),
      year: y,
      month: m,
      label: (j['label'] ?? monthLabel(m, y)).toString(),
      archived: j['archived'] == true,
      daysCount: maxUsed.clamp(15, 30),
      tasmi: t,
      attendance: a,
    );
  }
}

class PointsLogEntry {
  String id;
  int delta;
  String reason;
  String date;

  PointsLogEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'delta': delta,
        'reason': reason,
        'date': date,
      };

  factory PointsLogEntry.fromJson(Map<String, dynamic> j) => PointsLogEntry(
        id: (j['id'] ?? genId('ph')).toString(),
        delta: (j['delta'] is num) ? (j['delta'] as num).toInt() : 0,
        reason: (j['reason'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
      );
}

class StudentModel {
  String id;
  String name;
  String age;
  int juzCount;
  int points;
  List<PointsLogEntry> pointsHistory;
  String activeMonthKey;
  Map<String, MonthRecord> months;

  StudentModel({
    required this.id,
    required this.name,
    required this.age,
    this.juzCount = 0,
    this.points = 0,
    List<PointsLogEntry>? pointsHistory,
    required this.activeMonthKey,
    required this.months,
  }) : pointsHistory = pointsHistory ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'juzCount': juzCount,
        'points': points,
        'pointsHistory': pointsHistory.map((e) => e.toJson()).toList(),
        'activeMonthKey': activeMonthKey,
        'months': months.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory StudentModel.fromJson(Map<String, dynamic> j) {
    final mRaw = (j['months'] as Map<String, dynamic>?) ?? {};
    final parsedMonths = <String, MonthRecord>{};
    mRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) parsedMonths[k] = MonthRecord.fromJson(v);
    });
    if (parsedMonths.isEmpty) {
      final now = DateTime.now();
      final empty = MonthRecord.empty(now.year, now.month);
      parsedMonths[empty.key] = empty;
    }
    final phRaw = (j['pointsHistory'] as List<dynamic>?) ?? [];
    return StudentModel(
      id: (j['id'] ?? genId('st')).toString(),
      name: (j['name'] ?? '').toString(),
      age: (j['age'] ?? '').toString(),
      juzCount: (j['juzCount'] is num) ? (j['juzCount'] as num).toInt().clamp(0, 30) : 0,
      points: (j['points'] is num) ? (j['points'] as num).toInt().clamp(0, 999999) : 0,
      pointsHistory: phRaw.whereType<Map<String, dynamic>>().map(PointsLogEntry.fromJson).toList(),
      activeMonthKey: (j['activeMonthKey'] ?? parsedMonths.keys.last).toString(),
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
  String gender;
  String password;
  String announcement;
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
      id: (j['id'] ?? genId('cir')).toString(),
      name: (j['name'] ?? '').toString(),
      mosque: (j['mosque'] ?? '').toString(),
      teacher: (j['teacher'] ?? '').toString(),
      schedule: (j['schedule'] ?? '').toString(),
      gender: (j['gender'] == 'female') ? 'female' : 'male',
      password: (j['password'] ?? '').toString(),
      announcement: (j['announcement'] ?? '').toString(),
      students: sRaw.whereType<Map<String, dynamic>>().map(StudentModel.fromJson).toList(),
    );
  }
}

class MarketItemModel {
  String id;
  String name;
  String type;
  int cost;
  bool unlimited;
  int stock;

  MarketItemModel({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.unlimited,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'cost': cost,
        'unlimited': unlimited,
        'stock': stock,
      };

  factory MarketItemModel.fromJson(Map<String, dynamic> j) => MarketItemModel(
        id: (j['id'] ?? genId('mkt')).toString(),
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'جائزة').toString(),
        cost: (j['cost'] is num) ? (j['cost'] as num).toInt().clamp(1, 999999) : 20,
        unlimited: j['unlimited'] == true,
        stock: (j['stock'] is num) ? (j['stock'] as num).toInt().clamp(0, 999999) : 0,
      );
}

class RewardRequestModel {
  String id;
  String studentId;
  String studentName;
  String circleId;
  String circleName;
  String itemId;
  String itemName;
  int cost;
  String status; // 'pending' | 'delivered' | 'cancelled'
  String date;

  RewardRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.circleId,
    required this.circleName,
    required this.itemId,
    required this.itemName,
    required this.cost,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'circleId': circleId,
        'circleName': circleName,
        'itemId': itemId,
        'itemName': itemName,
        'cost': cost,
        'status': status,
        'date': date,
      };

  factory RewardRequestModel.fromJson(Map<String, dynamic> j) => RewardRequestModel(
        id: (j['id'] ?? genId('req')).toString(),
        studentId: (j['studentId'] ?? '').toString(),
        studentName: (j['studentName'] ?? '').toString(),
        circleId: (j['circleId'] ?? '').toString(),
        circleName: (j['circleName'] ?? '').toString(),
        itemId: (j['itemId'] ?? '').toString(),
        itemName: (j['itemName'] ?? '').toString(),
        cost: (j['cost'] is num) ? (j['cost'] as num).toInt() : 0,
        status: (j['status'] ?? 'pending').toString(),
        date: (j['date'] ?? '').toString(),
      );
}

class ContactMethodModel {
  String id;
  String type;
  String label;
  String value;

  ContactMethodModel({
    required this.id,
    required this.type,
    required this.label,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'value': value,
      };

  factory ContactMethodModel.fromJson(Map<String, dynamic> j) => ContactMethodModel(
        id: (j['id'] ?? genId('cnt')).toString(),
        type: (j['type'] ?? 'whatsapp').toString(),
        label: (j['label'] ?? '').toString(),
        value: (j['value'] ?? '').toString(),
      );
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
  final List<({String title, String icon, Color color})> badges;

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
    int present = 0, excused = 0, absent = 0, tasmiCount = 0, gradePts = 0, streak = 0, maxStreak = 0;
    const gMap = {'ممتاز': 100, 'جيد جداً': 85, 'جيد': 70, 'يحتاج مراجعة': 50};
    final limit = rec.daysCount.clamp(15, 30);

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

    final counted = present + absent;
    final attRate = counted > 0 ? ((present / counted) * 100).round() : (excused > 0 ? 100 : 0);
    final avgGrade = tasmiCount > 0 ? (gradePts / tasmiCount).round() : 0;
    final paceTarget = (present > 0 ? present : 1).clamp(1, limit < 12 ? limit : 12);
    final pace = present > 0
        ? ((tasmiCount / paceTarget) * 100).round().clamp(0, 100)
        : (tasmiCount > 0 ? 80 : 0);
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
      insights.add('لم يتم تسجيل حضور أو تسميع لهذا الشهر بعد. سيبدأ التحليل الذكي تلقائياً فور تسجيل أول يوم.');
    } else {
      if (attRate >= 90) {
        insights.add('انضباط ممتاز في الحضور بنسبة $attRate% مع أطول التزام متتالي بلغ $maxStreak أيام.');
      } else if (attRate >= 75) {
        insights.add('مستوى الحضور جيد ($attRate%) مع تسجيل $absent أيام غياب بدون عذر${excused > 0 ? ' و$excused بعذر' : ''}.');
      } else {
        insights.add('تنبيه غياب: تم تسجيل $absent أيام غياب بدون عذر (الحضور $attRate%)؛ يُنصح بالتواصل مع ولي الأمر.');
      }
      if (tasmiCount >= 8 && avgGrade >= 85) {
        insights.add('إنجاز قوي في التسميع ($tasmiCount جلسات بمتوسط جودة $avgGrade%) يعكس حفظاً متيناً.');
      } else if (tasmiCount >= 3) {
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
          if (diff >= 5) insights.add('مقارنة بشهر ${prev.label}: تطوّر إيجابي بمقدار +$diff نقطة.');
          if (diff <= -5) insights.add('مقارنة بشهر ${prev.label}: تراجع بمقدار ${diff.abs()} نقطة؛ يُنصح بالدعم.');
        }
      }
    }

    final badges = <({String title, String icon, Color color})>[];
    if (attRate >= 90 && present >= 5) badges.add((title: 'بطل الالتزام', icon: '🛡️', color: kGreen));
    if (tasmiCount >= 4) badges.add((title: 'مثابر التسميع', icon: '📖', color: kBlueMain));
    if (overall >= 85) badges.add((title: 'نجم التميّز', icon: '⭐', color: kGold));

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
// App Controller (Per-Circle Supabase Sync + Offline Queue + Pinned Children)
// ---------------------------------------------------------------------------
class AppStore extends ChangeNotifier {
  List<CircleModel> circles = [];
  List<MarketItemModel> marketItems = [];
  List<RewardRequestModel> rewardRequests = [];
  List<ContactMethodModel> contacts = [];
  String generalAnnouncement = '';

  List<Map<String, String>> pinnedStudents = []; // [{circleId, studentId}]
  List<Map<String, String>> recentSearches = [];
  bool darkMode = false;
  int dhikrIndex = 0;

  Set<String> pendingCircleIds = {};
  bool pendingMeta = false;
  String syncStatus = 'connecting'; // connecting | synced | saving | pending | offline
  Timer? _syncTimer;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool(kDarkKey) ?? false;
    dhikrIndex = ((prefs.getInt(kDhikrIdxKey) ?? -1) + 1) % kAdhkar.length;
    await prefs.setInt(kDhikrIdxKey, dhikrIndex);

    final rawData = prefs.getString(kStorageKey);
    if (rawData != null && rawData.isNotEmpty) {
      try {
        _loadFromJsonMap(jsonDecode(rawData) as Map<String, dynamic>);
      } catch (_) {}
    }

    final rawPinned = prefs.getString(kPinnedKey);
    if (rawPinned != null) {
      try {
        final list = jsonDecode(rawPinned) as List<dynamic>;
        pinnedStudents = list
            .whereType<Map<String, dynamic>>()
            .map((m) => {'circleId': '${m['circleId'] ?? ''}', 'studentId': '${m['studentId'] ?? ''}'})
            .toList();
      } catch (_) {}
    }

    final rawRecent = prefs.getString(kRecentKey);
    if (rawRecent != null) {
      try {
        final list = jsonDecode(rawRecent) as List<dynamic>;
        recentSearches = list
            .whereType<Map<String, dynamic>>()
            .map((m) => m.map((k, v) => MapEntry(k, v.toString())))
            .toList();
      } catch (_) {}
    }

    final rawPending = prefs.getString(kPendingKey);
    if (rawPending != null) {
      try {
        final m = jsonDecode(rawPending) as Map<String, dynamic>;
        pendingCircleIds = ((m['circles'] as List<dynamic>?) ?? []).map((e) => e.toString()).toSet();
        pendingMeta = m['meta'] == true;
      } catch (_) {}
    }

    notifyListeners();
    await syncFromCloud();
  }

  Map<String, dynamic> toFullJson() => {
        'circles': circles.map((c) => c.toJson()).toList(),
        'marketItems': marketItems.map((m) => m.toJson()).toList(),
        'rewardRequests': rewardRequests.map((r) => r.toJson()).toList(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'generalAnnouncement': generalAnnouncement,
      };

  void _loadFromJsonMap(Map<String, dynamic> raw) {
    circles = ((raw['circles'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CircleModel.fromJson)
        .toList();
    marketItems = ((raw['marketItems'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MarketItemModel.fromJson)
        .toList();
    rewardRequests = ((raw['rewardRequests'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RewardRequestModel.fromJson)
        .toList();
    contacts = ((raw['contacts'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ContactMethodModel.fromJson)
        .toList();
    generalAnnouncement = (raw['generalAnnouncement'] ?? '').toString();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kStorageKey, jsonEncode(toFullJson()));
    await prefs.setString(
      kPendingKey,
      jsonEncode({'circles': pendingCircleIds.toList(), 'meta': pendingMeta}),
    );
  }

  Future<void> toggleDark() async {
    darkMode = !darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDarkKey, darkMode);
    notifyListeners();
  }

  void nextDhikr() {
    dhikrIndex = (dhikrIndex + 1) % kAdhkar.length;
    SharedPreferences.getInstance().then((p) => p.setInt(kDhikrIdxKey, dhikrIndex));
    notifyListeners();
  }

  CircleModel? getCircle(String id) {
    for (final c in circles) {
      if (c.id == id) return c;
    }
    return null;
  }

  StudentModel? getStudent(CircleModel? c, String sid) {
    if (c == null) return null;
    for (final s in c.students) {
      if (s.id == sid) return s;
    }
    return null;
  }

  bool isPinned(String circleId, String studentId) =>
      pinnedStudents.any((p) => p['circleId'] == circleId && p['studentId'] == studentId);

  Future<void> togglePin(String circleId, String studentId) async {
    if (isPinned(circleId, studentId)) {
      pinnedStudents.removeWhere((p) => p['circleId'] == circleId && p['studentId'] == studentId);
    } else {
      pinnedStudents.add({'circleId': circleId, 'studentId': studentId});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPinnedKey, jsonEncode(pinnedStudents));
    notifyListeners();
  }

  Future<void> addRecent(String circleId, String studentId, String studentName, String circleName, String gender) async {
    recentSearches.removeWhere((r) => r['circleId'] == circleId && r['studentId'] == studentId);
    recentSearches.insert(0, {
      'circleId': circleId,
      'studentId': studentId,
      'studentName': studentName,
      'circleName': circleName,
      'gender': gender,
    });
    if (recentSearches.length > 6) recentSearches = recentSearches.sublist(0, 6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRecentKey, jsonEncode(recentSearches));
    notifyListeners();
  }

  Future<void> _upsertRow(String rowId, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/$kSupabaseTable?on_conflict=id');
    final res = await http
        .post(
          uri,
          headers: {
            'apikey': kSupabaseKey,
            'Authorization': 'Bearer $kSupabaseKey',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode([
            {'id': rowId, 'data': payload, 'updated_at': DateTime.now().toIso8601String()}
          ]),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  Future<void> flushPending() async {
    if (pendingCircleIds.isEmpty && !pendingMeta) return;
    syncStatus = 'saving';
    notifyListeners();
    try {
      final copyIds = pendingCircleIds.toList();
      for (final cid in copyIds) {
        final c = getCircle(cid);
        if (c != null) {
          await _upsertRow('circle_$cid', c.toJson());
        } else {
          await _upsertRow('circle_$cid', {'deleted': true, 'id': cid});
        }
        pendingCircleIds.remove(cid);
      }
      if (pendingMeta) {
        await _upsertRow('meta_v12', {
          'circleOrder': circles.map((c) => c.id).toList(),
          'marketItems': marketItems.map((m) => m.toJson()).toList(),
          'rewardRequests': rewardRequests.map((r) => r.toJson()).toList(),
          'contacts': contacts.map((c) => c.toJson()).toList(),
          'generalAnnouncement': generalAnnouncement,
        });
        await _upsertRow('main', {'circles': circles.map((c) => c.toJson()).toList()});
        pendingMeta = false;
      }
      await _saveLocal();
      syncStatus = 'synced';
      notifyListeners();
    } catch (_) {
      await _saveLocal();
      syncStatus = 'pending';
      notifyListeners();
    }
  }

  void saveCircle(String circleId) {
    pendingCircleIds.add(circleId);
    _saveLocal();
    notifyListeners();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 350), flushPending);
  }

  void saveMetaAndCircles(List<String> circleIds) {
    pendingCircleIds.addAll(circleIds);
    pendingMeta = true;
    _saveLocal();
    notifyListeners();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 350), flushPending);
  }

  Future<void> syncFromCloud() async {
    if (pendingCircleIds.isNotEmpty || pendingMeta) {
      await flushPending();
    }
    syncStatus = 'connecting';
    notifyListeners();
    try {
      final uri = Uri.parse('$kSupabaseUrl/rest/v1/$kSupabaseTable?select=id,data,updated_at');
      final res = await http.get(
        uri,
        headers: {
          'apikey': kSupabaseKey,
          'Authorization': 'Bearer $kSupabaseKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rows = jsonDecode(res.body) as List<dynamic>;
        final byId = <String, Map<String, dynamic>>{};
        for (final r in rows) {
          if (r is Map<String, dynamic> && r['data'] is Map<String, dynamic>) {
            byId[r['id'].toString()] = r['data'] as Map<String, dynamic>;
          }
        }
        final circleMap = <String, CircleModel>{};
        final mainRow = byId['main'];
        if (mainRow != null && mainRow['circles'] is List) {
          for (final c in (mainRow['circles'] as List)) {
            if (c is Map<String, dynamic>) {
              final nc = CircleModel.fromJson(c);
              circleMap[nc.id] = nc;
            }
          }
        }
        byId.forEach((id, data) {
          if (id.startsWith('circle_')) {
            if (data['deleted'] == true) {
              circleMap.remove((data['id'] ?? id.substring(7)).toString());
            } else {
              final nc = CircleModel.fromJson(data);
              circleMap[nc.id] = nc;
            }
          }
        });

        final meta = byId['meta_v12'];
        final merged = <CircleModel>[];
        if (meta != null && meta['circleOrder'] is List) {
          for (final cid in (meta['circleOrder'] as List)) {
            final key = cid.toString();
            final found = circleMap.remove(key);
            if (found != null) merged.add(found);
          }
        }
        merged.addAll(circleMap.values);

        if (merged.isNotEmpty || meta != null) {
          circles = merged;
          if (meta != null) {
            marketItems = ((meta['marketItems'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .map(MarketItemModel.fromJson)
                .toList();
            rewardRequests = ((meta['rewardRequests'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .map(RewardRequestModel.fromJson)
                .toList();
            contacts = ((meta['contacts'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .map(ContactMethodModel.fromJson)
                .toList();
            generalAnnouncement = (meta['generalAnnouncement'] ?? '').toString();
          }
          await _saveLocal();
        }
        syncStatus = 'synced';
      } else {
        syncStatus = (pendingCircleIds.isNotEmpty || pendingMeta) ? 'pending' : 'offline';
      }
    } catch (_) {
      syncStatus = (pendingCircleIds.isNotEmpty || pendingMeta) ? 'pending' : 'offline';
    }
    notifyListeners();
  }

  Future<bool> restoreFromJsonString(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _loadFromJsonMap(decoded);
      saveMetaAndCircles(circles.map((c) => c.id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  List<({String circleId, String studentId, String name, String circleName, String gender, int score, int tasmiCount})>
      topStars() {
    final list = <({String circleId, String studentId, String name, String circleName, String gender, int score, int tasmiCount})>[];
    for (final c in circles) {
      for (final s in c.students) {
        final rec = s.months[s.activeMonthKey];
        if (rec == null) continue;
        final an = AiAnalysis.compute(rec, null);
        if (an.overallScore > 0) {
          list.add((
            circleId: c.id,
            studentId: s.id,
            name: s.name,
            circleName: c.name,
            gender: c.gender,
            score: an.overallScore,
            tasmiCount: an.tasmiCount,
          ));
        }
      }
    }
    list.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : b.tasmiCount.compareTo(a.tasmiCount));
    return list.take(3).toList();
  }

  String latestActivitySummary(StudentModel s) {
    final rec = s.months[s.activeMonthKey];
    if (rec != null) {
      for (int d = 30; d >= 1; d--) {
        final t = rec.tasmi['$d'];
        if (t != null && t.text.isNotEmpty) return 'تسميع: ${t.text} (${t.grade})';
      }
      for (int d = 30; d >= 1; d--) {
        final a = rec.attendance['$d'];
        if (a == 'present') return 'حاضر في اليوم $d';
        if (a == 'excused') return 'غياب بعذر في اليوم $d';
        if (a == 'absent') return 'غياب في اليوم $d';
      }
    }
    if (s.pointsHistory.isNotEmpty) {
      final h = s.pointsHistory.first;
      return '${h.delta >= 0 ? '+' : ''}${h.delta} نقطة — ${h.reason}';
    }
    return 'مسجّل في الحلقة';
  }
}

final AppStore appStore = AppStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KhayrUmmahApp());
}

class KhayrUmmahApp extends StatefulWidget {
  const KhayrUmmahApp({super.key});
  @override
  State<KhayrUmmahApp> createState() => _KhayrUmmahAppState();
}

class _KhayrUmmahAppState extends State<KhayrUmmahApp> {
  @override
  void initState() {
    super.initState();
    appStore.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final dark = appStore.darkMode;
        return MaterialApp(
          title: 'خير أمة',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: dark ? kCanvasDark : kCanvasLight,
            cardColor: dark ? kCardDark : Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kBlueMain,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            textTheme: GoogleFonts.tajawalTextTheme(
              dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
            ),
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
// 1. Splash Screen
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [kBlueDeep, kBlueDark, kBlueMain],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    )
                  ],
                ),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 22),
              Text(
                'جمعية خير أمة',
                style: GoogleFonts.amiri(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'نظام متابعة الحلقات القرآنية — الإصدار 1.2',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Home Screen (Rotating Adhkar + ☰ Menu + Role Pills + Stars of the Month)
// ---------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('القائمة الرئيسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('📞 طرق التواصل مع المعهد', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlueMain)),
              const SizedBox(height: 8),
              if (appStore.contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('لم يضف مدير المعهد طرق تواصل بعد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                )
              else
                ...appStore.contacts.map((ct) {
                  final meta = kContactTypes.firstWhere((e) => e['id'] == ct.type, orElse: () => kContactTypes.last);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: ct.value));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ وسيلة التواصل')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(meta['icon'] ?? '📍', style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ct.label.isNotEmpty ? ct.label : (meta['label'] ?? ''), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                  Text(ct.value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Text('نسخ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kBlueMain)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const Divider(height: 24),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDirectorGate(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kBlueDeep, kBlueDark]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Text('🛡️', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الإدارة العامة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('خاص بمدير الجمعية والمعهد', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirectorGate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int fails = 0;
    int until = 0;
    final raw = prefs.getString(kLockoutKey);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        fails = (m['fails'] is int) ? m['fails'] as int : 0;
        until = (m['until'] is int) ? m['until'] as int : 0;
        if (until > 0 && DateTime.now().millisecondsSinceEpoch >= until) {
          fails = 0;
          until = 0;
          await prefs.setString(kLockoutKey, jsonEncode({'fails': 0, 'until': 0}));
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    final ctrl = TextEditingController();
    String errMsg = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final locked = until > now;
          final minsLeft = locked ? ((until - now) / 60000).ceil() : 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('🛡️ الإدارة العامة — خاص بالمدير', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: locked
                ? Text(
                    '⛔ تم قفل الدخول مؤقتاً بعد 3 محاولات خاطئة.\nيرجى المحاولة بعد حوالي $minsLeft دقيقة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 13),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('دخول محمي ومشفّر (SHA-256)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة سر المدير...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (errMsg.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(errMsg, style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
            actions: locked
                ? [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))]
                : [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (verifyDirectorPassword(ctrl.text)) {
                          await prefs.setString(kLockoutKey, jsonEncode({'fails': 0, 'until': 0}));
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                          );
                        } else {
                          fails++;
                          if (fails >= 3) {
                            until = DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000;
                          }
                          await prefs.setString(kLockoutKey, jsonEncode({'fails': fails, 'until': until}));
                          setS(() {
                            errMsg = 'كلمة السر غير صحيحة (متبقي ${3 - fails} محاولات)';
                          });
                        }
                      },
                      child: const Text('دخول المدير'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  String _syncLabel(String s) {
    switch (s) {
      case 'synced':
        return 'متزامن';
      case 'saving':
        return 'جاري الحفظ';
      case 'pending':
        return 'بانتظار النت';
      case 'connecting':
        return 'مزامنة...';
      default:
        return 'بدون نت';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final dhikr = kAdhkar[appStore.dhikrIndex % kAdhkar.length];
        final stars = appStore.topStars();
        const medals = ['🥇', '🥈', '🥉'];
        final hasValidPin = appStore.pinnedStudents.any((p) {
          final c = appStore.getCircle(p['circleId'] ?? '');
          return appStore.getStudent(c, p['studentId'] ?? '') != null;
        });

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: appStore.syncFromCloud,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Curved Deep Blue Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 14, 18, 36),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [kBlueDeep, kBlueDark, kBlueMain],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(38)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => _openMenuSheet(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.menu, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: appStore.syncStatus == 'synced'
                                          ? Colors.greenAccent
                                          : (appStore.syncStatus == 'pending' ? Colors.amber : Colors.white70),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_syncLabel(appStore.syncStatus), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: appStore.toggleDark,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(appStore.darkMode ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: appStore.nextDhikr,
                          child: Column(
                            children: [
                              Text(
                                dhikr,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'جمعية خير أمة — متابعة الحلقات القرآنية',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                    child: Column(
                      children: [
                        // Teacher Pill Button
                        _RolePillButton(
                          title: 'معلم',
                          subtitle: 'دخول مباشر لحلقتك فقط',
                          icon: '👨‍🏫',
                          colors: const [Color(0xFFC7A87D), kGold, kGoldDark],
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAuthScreen())),
                        ),
                        const SizedBox(height: 14),
                        // Student Pill Button
                        _RolePillButton(
                          title: 'طالب',
                          subtitle: hasValidPin
                              ? 'أبنائي المثبّتون (${appStore.pinnedStudents.length}) وسوق النقاط'
                              : 'متابعة الطالب وسوق النقاط',
                          icon: '📖',
                          colors: const [Color(0xFF5696BF), kBlueMain, kBlueDark],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => hasValidPin ? const PinnedStudentsScreen() : const StudentSearchScreen(),
                            ),
                          ),
                        ),

                        // Official Association Announcement
                        if (appStore.generalAnnouncement.trim().isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: const Border(right: BorderSide(color: kGold, width: 4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📢', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('إعلان عام من إدارة الجمعية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kGoldDark)),
                                      const SizedBox(height: 3),
                                      Text(appStore.generalAnnouncement, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Layered Arched Stars of the Month Card
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [kBlueDark, kBlueMain]),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                                    child: stars.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: Text('🌟 بانتظار أبطال هذا الشهر', style: TextStyle(fontWeight: FontWeight.bold)),
                                          )
                                        : Column(
                                            children: List.generate(stars.length, (i) {
                                              final st = stars[i];
                                              final pal = CirclePalette.forGender(st.gender);
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: i < stars.length - 1 ? 10 : 0),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(18),
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => StudentProfileScreen(
                                                        circleId: st.circleId,
                                                        studentId: st.studentId,
                                                        readOnly: true,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).scaffoldBackgroundColor,
                                                      borderRadius: BorderRadius.circular(18),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Text(medals[i], style: const TextStyle(fontSize: 22)),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(st.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                                              Text('${st.circleName} • ${st.tasmiCount} تسميع', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(color: pal.main, borderRadius: BorderRadius.circular(14)),
                                                          child: Text('${st.score}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFC9A97E), kGold, kGoldDark]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: kGoldDark.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
                              ),
                              child: const Text('⭐  نجوم الشهر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RolePillButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _RolePillButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Teacher Auth Screen (Circle Password ONLY -> Direct to His Circle)
// ---------------------------------------------------------------------------
class TeacherAuthScreen extends StatefulWidget {
  const TeacherAuthScreen({super.key});
  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> {
  final _passCtrl = TextEditingController();
  String _err = '';

  void _submit() {
    final norm = normalizeArabic(_passCtrl.text);
    CircleModel? matched;
    if (norm.isNotEmpty) {
      for (final c in appStore.circles) {
        if (c.password.isNotEmpty && normalizeArabic(c.password) == norm) {
          matched = c;
          break;
        }
      }
    }
    if (matched != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: matched!.id, isAdmin: false)),
      );
    } else {
      setState(() => _err = 'كلمة مرور الحلقة غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بوابة المعلم'), backgroundColor: kBlueDark, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔑', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 10),
                const Text('أدخل كلمة مرور حلقتك الخاصة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'كلمة مرور الحلقة...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_err, style: const TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGoldDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _submit,
                    child: const Text('دخول لحلقتي فقط', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Admin Dashboard (3 Tabs: الحلقات | النقاط + بحث الطلاب | التواصل)
// ---------------------------------------------------------------------------
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0; // 0: Circles, 1: Points, 2: Contacts
  final _ptsSearchCtrl = TextEditingController();
  final _ptsAmountCtrl = TextEditingController(text: '20');
  final _ptsReasonCtrl = TextEditingController();
  String? _selectedStudentPair; // 'circleId::studentId'

  void _openCircleDialog({CircleModel? existing}) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final mosqueC = TextEditingController(text: existing?.mosque ?? '');
    final teacherC = TextEditingController(text: existing?.teacher ?? '');
    final schedC = TextEditingController(text: existing?.schedule ?? '');
    final passC = TextEditingController(text: existing?.password ?? '');
    String gender = existing?.gender ?? 'male';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(existing == null ? 'إنشاء حلقة جديدة' : 'تعديل الحلقة', style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم الحلقة *')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('👦 ذكور'),
                        selected: gender == 'male',
                        onSelected: (_) => setS(() => gender = 'male'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('👧 إناث'),
                        selected: gender == 'female',
                        onSelected: (_) => setS(() => gender = 'female'),
                      ),
                    ),
                  ],
                ),
                TextField(controller: mosqueC, decoration: const InputDecoration(labelText: 'المسجد / المركز')),
                TextField(controller: teacherC, decoration: const InputDecoration(labelText: 'اسم المعلم / المعلمة')),
                TextField(controller: schedC, decoration: const InputDecoration(labelText: 'الأيام والأوقات')),
                TextField(controller: passC, decoration: const InputDecoration(labelText: 'كلمة مرور الحلقة للمعلم *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty || passC.text.trim().isEmpty) return;
                if (existing != null) {
                  existing.name = nameC.text.trim();
                  existing.gender = gender;
                  existing.mosque = mosqueC.text.trim();
                  existing.teacher = teacherC.text.trim();
                  existing.schedule = schedC.text.trim();
                  existing.password = passC.text.trim();
                  appStore.saveMetaAndCircles([existing.id]);
                } else {
                  final nc = CircleModel(
                    id: genId('cir'),
                    name: nameC.text.trim(),
                    mosque: mosqueC.text.trim(),
                    teacher: teacherC.text.trim(),
                    schedule: schedC.text.trim(),
                    gender: gender,
                    password: passC.text.trim(),
                    students: [],
                  );
                  appStore.circles.add(nc);
                  appStore.saveMetaAndCircles([nc.id]);
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _openGeneralAnnDialog() {
    final c = TextEditingController(text: appStore.generalAnnouncement);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📢 إعلان عام للجمعية'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب الإعلان العام...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              appStore.generalAnnouncement = c.text.trim();
              appStore.saveMetaAndCircles([]);
              Navigator.pop(ctx);
            },
            child: const Text('نشر'),
          ),
        ],
      ),
    );
  }

  void _openBackupRestoreDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💾 النسخة الاحتياطية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('نسخ النسخة الاحتياطية الكاملة'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonEncode(appStore.toFullJson())));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النسخة الاحتياطية بنجاح')));
              },
            ),
            const Divider(height: 24),
            TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'أو الصق نص النسخة الاحتياطية هنا للاستعادة...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ElevatedButton(
            onPressed: () async {
              final ok = await appStore.restoreFromJsonString(c.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'تمت الاستعادة بنجاح' : 'نص النسخة غير صالح')),
              );
            },
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _openMarketItemDialog({MarketItemModel? existing}) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final typeC = TextEditingController(text: existing?.type ?? 'جائزة');
    final costC = TextEditingController(text: '${existing?.cost ?? 30}');
    final stockC = TextEditingController(text: '${existing?.stock ?? 10}');
    bool unlimited = existing?.unlimited ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'إضافة جائزة للسوق' : 'تعديل الجائزة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم الجائزة *')),
                TextField(controller: typeC, decoration: const InputDecoration(labelText: 'نوع الجائزة')),
                TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد النقاط *')),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('كمية غير محدودة (∞)'),
                  value: unlimited,
                  onChanged: (v) => setS(() => unlimited = v),
                ),
                if (!unlimited)
                  TextField(controller: stockC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المتوفرة')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;
                final cost = (int.tryParse(costC.text) ?? 20).clamp(1, 999999);
                final stock = (int.tryParse(stockC.text) ?? 0).clamp(0, 999999);
                if (existing != null) {
                  existing.name = nameC.text.trim();
                  existing.type = typeC.text.trim();
                  existing.cost = cost;
                  existing.unlimited = unlimited;
                  existing.stock = stock;
                } else {
                  appStore.marketItems.add(MarketItemModel(
                    id: genId('mkt'),
                    name: nameC.text.trim(),
                    type: typeC.text.trim(),
                    cost: cost,
                    unlimited: unlimited,
                    stock: stock,
                  ));
                }
                appStore.saveMetaAndCircles([]);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _openContactDialog({ContactMethodModel? existing}) {
    String type = existing?.type ?? 'whatsapp';
    final labelC = TextEditingController(text: existing?.label ?? '');
    final valC = TextEditingController(text: existing?.value ?? '');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'إضافة طريقة تواصل' : 'تعديل طريقة تواصل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: kContactTypes
                    .map((t) => DropdownMenuItem(value: t['id'], child: Text('${t['icon']} ${t['label']}')))
                    .toList(),
                onChanged: (v) => setS(() => type = v ?? 'whatsapp'),
              ),
              TextField(controller: labelC, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
              TextField(controller: valC, decoration: const InputDecoration(labelText: 'الرقم أو الرابط أو النص *')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (valC.text.trim().isEmpty) return;
                if (existing != null) {
                  existing.type = type;
                  existing.label = labelC.text.trim();
                  existing.value = valC.text.trim();
                } else {
                  appStore.contacts.add(ContactMethodModel(
                    id: genId('cnt'),
                    type: type,
                    label: labelC.text.trim(),
                    value: valC.text.trim(),
                  ));
                }
                appStore.saveMetaAndCircles([]);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final pendingReqs = appStore.rewardRequests.where((r) => r.status == 'pending').toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('🛡️ لوحة مدير الجمعية'),
            backgroundColor: kBlueDeep,
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: appStore.syncFromCloud),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(value: 0, label: Text('الحلقات')),
                    ButtonSegment(value: 1, label: Text('النقاط${pendingReqs.isNotEmpty ? ' (${pendingReqs.length})' : ''}')),
                    const ButtonSegment(value: 2, label: Text('التواصل')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
              Expanded(
                child: _tab == 0
                    ? _buildCirclesTab()
                    : (_tab == 1 ? _buildPointsTab(pendingReqs) : _buildContactsTab()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCirclesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.white),
                icon: const Icon(Icons.add),
                label: const Text('حلقة جديدة'),
                onPressed: () => _openCircleDialog(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kBlueMain, foregroundColor: Colors.white),
                icon: const Icon(Icons.campaign),
                label: const Text('إعلان عام'),
                onPressed: _openGeneralAnnDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.backup),
          label: const Text('💾 النسخة الاحتياطية (تصدير / استعادة)'),
          onPressed: _openBackupRestoreDialog,
        ),
        const SizedBox(height: 12),
        ...appStore.circles.map((c) {
          final pal = CirclePalette.forGender(c.gender);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Chip(label: Text('${c.students.length} ${pal.studentsWord}', style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                  Text('🕌 ${c.mosque} • 👤 ${c.teacher}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('🔑 كلمة مرور الحلقة: ${c.password}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGoldDark)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: pal.main, foregroundColor: Colors.white),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CircleDetailScreen(circleId: c.id, isAdmin: true)),
                          ),
                          child: const Text('فتح الحلقة'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _openCircleDialog(existing: c)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: kRed),
                        onPressed: () {
                          appStore.circles.removeWhere((x) => x.id == c.id);
                          appStore.saveMetaAndCircles([c.id]);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPointsTab(List<RewardRequestModel> pendingReqs) {
    final q = normalizeArabic(_ptsSearchCtrl.text);
    final allStudents = <({CircleModel circle, StudentModel student})>[];
    for (final c in appStore.circles) {
      for (final s in c.students) {
        if (q.isEmpty || normalizeArabic(s.name).contains(q) || normalizeArabic(c.name).contains(q)) {
          allStudents.add((circle: c, student: s));
        }
      }
    }
    final validValues = allStudents.map((x) => '${x.circle.id}::${x.student.id}').toList();
    if (_selectedStudentPair == null || !validValues.contains(_selectedStudentPair)) {
      _selectedStudentPair = validValues.isNotEmpty ? validValues.first : null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        if (pendingReqs.isNotEmpty) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎁 طلبات الجوائز الواردة (${pendingReqs.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...pendingReqs.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r.studentName} (${r.circleName})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('طلب: ${r.itemName} (${r.cost} نقطة)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
                                    onPressed: () {
                                      r.status = 'delivered';
                                      appStore.saveMetaAndCircles([]);
                                    },
                                    child: const Text('✅ تم التسليم'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      r.status = 'cancelled';
                                      final c = appStore.getCircle(r.circleId);
                                      final s = appStore.getStudent(c, r.studentId);
                                      if (s != null) {
                                        s.points += r.cost;
                                        s.pointsHistory.insert(0, PointsLogEntry(id: genId('ph'), delta: r.cost, reason: 'إرجاع نقاط (${r.itemName})', date: todayIso()));
                                      }
                                      for (final it in appStore.marketItems) {
                                        if (it.id == r.itemId && !it.unlimited) it.stock++;
                                      }
                                      appStore.saveMetaAndCircles(c != null ? [c.id] : []);
                                    },
                                    child: const Text('✕ إلغاء وإرجاع', style: TextStyle(color: kRed)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Grant Points with Live Student Search
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ تحويل نقاط مكافأة لطالب', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _ptsSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث باسم الطالب لتصفية القائمة...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (allStudents.isEmpty)
                  const Text('لا توجد نتائج مطابقة', style: TextStyle(color: Colors.grey))
                else
                  DropdownButtonFormField<String>(
                    value: _selectedStudentPair,
                    isExpanded: true,
                    items: allStudents
                        .map((x) => DropdownMenuItem(
                              value: '${x.circle.id}::${x.student.id}',
                              child: Text('${x.student.name} — ${x.circle.name} (${x.student.points} نقطة)', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStudentPair = v),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _ptsAmountCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'النقاط'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ptsReasonCtrl,
                        decoration: const InputDecoration(labelText: 'السبب (بكشف الحساب)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.white),
                        onPressed: () => _applyPoints(1),
                        child: const Text('➕ إضافة نقاط'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _applyPoints(-1),
                        child: const Text('➖ خصم', style: TextStyle(color: kRed)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Market Rewards Management
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🛍️ جوائز السوق (${appStore.marketItems.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة جائزة'),
              onPressed: () => _openMarketItemDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...appStore.marketItems.map((it) {
          final out = !it.unlimited && it.stock <= 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${it.type} • ${it.cost} نقطة • ${it.unlimited ? '∞ غير محدودة' : (out ? 'نفذت الكمية' : 'متبقي ${it.stock}')}',
                style: TextStyle(color: out ? kRed : Colors.grey, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openMarketItemDialog(existing: it)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: kRed, size: 20),
                    onPressed: () {
                      appStore.marketItems.removeWhere((x) => x.id == it.id);
                      appStore.saveMetaAndCircles([]);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _applyPoints(int sign) {
    if (_selectedStudentPair == null) return;
    final amt = int.tryParse(_ptsAmountCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;
    final parts = _selectedStudentPair!.split('::');
    final c = appStore.getCircle(parts[0]);
    final s = appStore.getStudent(c, parts[1]);
    if (c == null || s == null) return;
    final delta = amt * sign;
    s.points = (s.points + delta).clamp(0, 999999);
    s.pointsHistory.insert(
      0,
      PointsLogEntry(
        id: genId('ph'),
        delta: delta,
        reason: _ptsReasonCtrl.text.trim().isNotEmpty
            ? _ptsReasonCtrl.text.trim()
            : (sign > 0 ? 'مكافأة من مدير الجمعية' : 'خصم نقاط من الإدارة'),
        date: todayIso(),
      ),
    );
    _ptsReasonCtrl.clear();
    appStore.saveCircle(c.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sign > 0 ? 'تم تحويل +$amt نقطة لـ ${s.name}' : 'تم خصم $amt نقطة')),
    );
  }

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.white),
          icon: const Icon(Icons.add),
          label: const Text('إضافة طريقة تواصل'),
          onPressed: () => _openContactDialog(),
        ),
        const SizedBox(height: 12),
        ...appStore.contacts.map((ct) {
          final meta = kContactTypes.firstWhere((e) => e['id'] == ct.type, orElse: () => kContactTypes.last);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(meta['icon'] ?? '📍', style: const TextStyle(fontSize: 22)),
              title: Text(ct.label.isNotEmpty ? ct.label : (meta['label'] ?? ''), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ct.value),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openContactDialog(existing: ct)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: kRed, size: 20),
                    onPressed: () {
                      appStore.contacts.removeWhere((x) => x.id == ct.id);
                      appStore.saveMetaAndCircles([]);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Circle Detail Screen (Teacher Sees ONLY His Circle)
// ---------------------------------------------------------------------------
class CircleDetailScreen extends StatelessWidget {
  final String circleId;
  final bool isAdmin;

  const CircleDetailScreen({super.key, required this.circleId, required this.isAdmin});

  void _openStudentDialog(BuildContext context, CircleModel c, {StudentModel? existing}) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final ageC = TextEditingController(text: existing?.age ?? '');
    final juzC = TextEditingController(text: '${existing?.juzCount ?? 0}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة جديد' : 'تعديل البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم الثلاثي *')),
            TextField(controller: ageC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمر')),
            TextField(controller: juzC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الأجزاء المحفوظة (0-30)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              final juz = (int.tryParse(juzC.text) ?? 0).clamp(0, 30);
              if (existing != null) {
                existing.name = nameC.text.trim();
                existing.age = ageC.text.trim();
                existing.juzCount = juz;
              } else {
                final now = DateTime.now();
                final em = MonthRecord.empty(now.year, now.month);
                c.students.add(StudentModel(
                  id: genId('st'),
                  name: nameC.text.trim(),
                  age: ageC.text.trim(),
                  juzCount: juz,
                  activeMonthKey: em.key,
                  months: {em.key: em},
                ));
              }
              appStore.saveCircle(c.id);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _openTransferDialog(BuildContext context, CircleModel fromC, StudentModel st) {
    final targets = appStore.circles.where((x) => x.id != fromC.id).toList();
    if (targets.isEmpty) return;
    String targetId = targets.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('نقل إلى حلقة أخرى'),
          content: DropdownButtonFormField<String>(
            value: targetId,
            items: targets.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setS(() => targetId = v ?? targetId),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final toC = appStore.getCircle(targetId);
                if (toC != null) {
                  fromC.students.removeWhere((x) => x.id == st.id);
                  toC.students.add(st);
                  appStore.saveMetaAndCircles([fromC.id, toC.id]);
                }
                Navigator.pop(ctx);
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
      animation: appStore,
      builder: (context, _) {
        final c = appStore.getCircle(circleId);
        if (c == null) return const Scaffold(body: Center(child: Text('الحلقة غير موجودة')));
        final pal = CirclePalette.forGender(c.gender);

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            backgroundColor: pal.deep,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.campaign),
                onPressed: () {
                  final ctrl = TextEditingController(text: c.announcement);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('إعلان الحلقة'),
                      content: TextField(controller: ctrl, maxLines: 3),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                        ElevatedButton(
                          onPressed: () {
                            c.announcement = ctrl.text.trim();
                            appStore.saveCircle(c.id);
                            Navigator.pop(ctx);
                          },
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: appStore.syncFromCloud),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: pal.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: Text('إضافة ${pal.studentWord}'),
            onPressed: () => _openStudentDialog(context, c),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            children: [
              if (c.announcement.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Text('📢', style: TextStyle(fontSize: 20)),
                    title: const Text('إعلان الحلقة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    subtitle: Text(c.announcement),
                  ),
                ),
              ...c.students.map((st) {
                final rec = st.months[st.activeMonthKey];
                final an = rec != null ? AiAnalysis.compute(rec, null) : null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('الحفظ: ${st.juzCount}/30 جزء • التقييم: ${an?.overallScore ?? 0}%'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentProfileScreen(circleId: c.id, studentId: st.id, readOnly: false),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openStudentDialog(context, c, existing: st)),
                        if (isAdmin)
                          IconButton(icon: const Icon(Icons.swap_horiz, size: 20), onPressed: () => _openTransferDialog(context, c, st)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: kRed, size: 20),
                          onPressed: () {
                            c.students.removeWhere((x) => x.id == st.id);
                            appStore.saveCircle(c.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Pinned Students Screen (أبنائي المثبّتون + ملخص التحديثات)
// ---------------------------------------------------------------------------
class PinnedStudentsScreen extends StatelessWidget {
  const PinnedStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final resolved = <({CircleModel circle, StudentModel student})>[];
        for (final p in appStore.pinnedStudents) {
          final c = appStore.getCircle(p['circleId'] ?? '');
          final s = appStore.getStudent(c, p['studentId'] ?? '');
          if (c != null && s != null) resolved.add((circle: c, student: s));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('📌 أبنائي المثبّتون'),
            backgroundColor: kBlueDark,
            foregroundColor: Colors.white,
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentSearchScreen())),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('إضافة طالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (resolved.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔔 آخر التحديثات', style: TextStyle(fontWeight: FontWeight.w800, color: kGoldDark)),
                        const SizedBox(height: 8),
                        ...resolved.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('${item.student.name}: ${appStore.latestActivitySummary(item.student)}', style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                    ),
                  ),
                ),
              ...resolved.map((item) {
                final pal = CirclePalette.forGender(item.circle.gender);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentProfileScreen(circleId: item.circle.id, studentId: item.student.id, readOnly: true),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(border: Border(right: BorderSide(color: pal.main, width: 6))),
                      child: ListTile(
                        title: Text(item.student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${item.circle.name} • ⭐ ${item.student.points} نقطة'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: pal.main),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Student Search Screen
// ---------------------------------------------------------------------------
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});
  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final q = normalizeArabic(_searchCtrl.text);
        final matches = <({CircleModel circle, StudentModel student})>[];
        if (q.isNotEmpty) {
          for (final c in appStore.circles) {
            for (final s in c.students) {
              if (normalizeArabic(s.name).contains(q) || normalizeArabic(c.name).contains(q)) {
                matches.add((circle: c, student: s));
              }
            }
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('البحث عن طالب'), backgroundColor: kBlueDark, foregroundColor: Colors.white),
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'اكتب اسم الطالب أو الطالبة...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: q.isEmpty
                      ? ListView(
                          children: [
                            if (appStore.recentSearches.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text('🕒 عمليات البحث الأخيرة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                            ...appStore.recentSearches.map((r) => Card(
                                  child: ListTile(
                                    title: Text(r['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text(r['circleName'] ?? ''),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentProfileScreen(
                                          circleId: r['circleId'] ?? '',
                                          studentId: r['studentId'] ?? '',
                                          readOnly: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        )
                      : ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (_, i) {
                            final item = matches[i];
                            final pinned = appStore.isPinned(item.circle.id, item.student.id);
                            return Card(
                              child: ListTile(
                                title: Text(item.student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(item.circle.name),
                                trailing: IconButton(
                                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, color: pinned ? kGoldDark : Colors.grey),
                                  onPressed: () => appStore.togglePin(item.circle.id, item.student.id),
                                ),
                                onTap: () {
                                  appStore.addRecent(item.circle.id, item.student.id, item.student.name, item.circle.name, item.circle.gender);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentProfileScreen(
                                        circleId: item.circle.id,
                                        studentId: item.student.id,
                                        readOnly: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
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
// 8. Student Profile Screen (2 Tabs in Student Mode | 15 Days + Add Day)
// ---------------------------------------------------------------------------
class StudentProfileScreen extends StatefulWidget {
  final String circleId;
  final String studentId;
  final bool readOnly;

  const StudentProfileScreen({
    super.key,
    required this.circleId,
    required this.studentId,
    required this.readOnly,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String? _selectedMonthKey;
  int _studentTab = 0; // 0: Tracking, 1: Points Market (readOnly mode only)

  void _openTasmiDialog(CircleModel c, MonthRecord rec, int day, bool locked) {
    final existing = rec.tasmi['$day'];
    if (locked) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('التسميع — اليوم $day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing?.text.isNotEmpty == true ? existing!.text : 'لم يُسجل تسميع في هذا اليوم', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (existing?.text.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('التقييم: ${existing!.grade}'),
              ],
              if (existing?.note.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('💬 ملاحظة لولي الأمر: ${existing!.note}'),
              ],
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
      return;
    }

    final textC = TextEditingController(text: existing?.text ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    String grade = existing?.grade ?? 'ممتاز';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تسجيل التسميع — اليوم $day'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: textC, decoration: const InputDecoration(labelText: 'السورة / الآيات')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: kGrades.contains(grade) ? grade : 'ممتاز',
                  items: kGrades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setS(() => grade = v ?? 'ممتاز'),
                ),
                TextField(controller: noteC, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظة لولي الأمر')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                rec.tasmi['$day'] = null;
                appStore.saveCircle(c.id);
                Navigator.pop(ctx);
              },
              child: const Text('مسح', style: TextStyle(color: kRed)),
            ),
            ElevatedButton(
              onPressed: () {
                rec.tasmi['$day'] = textC.text.trim().isEmpty
                    ? null
                    : TasmiEntry(text: textC.text.trim(), grade: grade, note: noteC.text.trim());
                appStore.saveCircle(c.id);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final c = appStore.getCircle(widget.circleId);
        final s = appStore.getStudent(c, widget.studentId);
        if (c == null || s == null) return const Scaffold(body: Center(child: Text('السجل غير موجود')));
        final pal = CirclePalette.forGender(c.gender);

        final mKeys = s.months.keys.toList()..sort((a, b) => b.compareTo(a));
        final curKey = (_selectedMonthKey != null && s.months.containsKey(_selectedMonthKey))
            ? _selectedMonthKey!
            : s.activeMonthKey;
        final rec = s.months[curKey] ?? s.months[mKeys.first]!;
        final curIdx = mKeys.indexOf(rec.key);
        final prevRec = (curIdx >= 0 && curIdx + 1 < mKeys.length) ? s.months[mKeys[curIdx + 1]] : null;
        final an = AiAnalysis.compute(rec, prevRec);
        final canEdit = !widget.readOnly && !rec.archived;
        final daysCount = rec.daysCount.clamp(15, 30);
        final pinned = appStore.isPinned(c.id, s.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(s.name),
            backgroundColor: pal.deep,
            foregroundColor: Colors.white,
            actions: [
              if (widget.readOnly)
                TextButton.icon(
                  onPressed: () => appStore.togglePin(c.id, s.id),
                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.white),
                  label: Text(pinned ? 'مثبّت' : 'تثبيت', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (widget.readOnly) ...[
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text('متابعة ${pal.studentWord}')),
                    ButtonSegment(value: 1, label: Text('⭐ سوق النقاط (${s.points})')),
                  ],
                  selected: {_studentTab},
                  onSelectionChanged: (v) => setState(() => _studentTab = v.first),
                ),
                const SizedBox(height: 14),
              ],

              if (widget.readOnly && _studentTab == 1)
                ..._buildMarketTab(c, s, pal)
              else
                ..._buildTrackingTab(c, s, pal, mKeys, rec, an, canEdit, daysCount),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMarketTab(CircleModel c, StudentModel s, CirclePalette pal) {
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFC7A87D), kGold, kGoldDark]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text('رصيد النقاط الحالي', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('⭐ ${s.points} نقطة', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text('🛍️ جوائز سوق النقاط', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 8),
      ...appStore.marketItems.map((it) {
        final out = !it.unlimited && it.stock <= 0;
        final enough = s.points >= it.cost;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    Chip(label: Text('${it.cost} نقطة', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                Text(
                  '${it.type} • ${it.unlimited ? '∞ كمية غير محدودة' : (out ? 'نفذت الكمية' : 'متبقي ${it.stock}')}',
                  style: TextStyle(color: out ? kRed : Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (out)
                  const Text('نفذت الكمية', style: TextStyle(color: kRed, fontWeight: FontWeight.bold))
                else if (enough)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
                      onPressed: () {
                        s.points -= it.cost;
                        if (!it.unlimited) it.stock = (it.stock - 1).clamp(0, 999999);
                        s.pointsHistory.insert(0, PointsLogEntry(id: genId('ph'), delta: -it.cost, reason: 'طلب جائزة: ${it.name}', date: todayIso()));
                        appStore.rewardRequests.insert(
                          0,
                          RewardRequestModel(
                            id: genId('req'),
                            studentId: s.id,
                            studentName: s.name,
                            circleId: c.id,
                            circleName: c.name,
                            itemId: it.id,
                            itemName: it.name,
                            cost: it.cost,
                            status: 'pending',
                            date: todayIso(),
                          ),
                        );
                        appStore.saveMetaAndCircles([c.id]);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الجائزة للإدارة بنجاح 🎁')));
                      },
                      child: const Text('🎁 طلب الجائزة الآن'),
                    ),
                  )
                else
                  Text('متبقي ${it.cost - s.points} نقطة لطلب هذه الجائزة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      const Text('📜 كشف حساب النقاط', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 8),
      ...s.pointsHistory.map((h) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(h.reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(h.date, style: const TextStyle(fontSize: 11)),
              trailing: Text(
                '${h.delta >= 0 ? '+' : ''}${h.delta}',
                style: TextStyle(fontWeight: FontWeight.w800, color: h.delta >= 0 ? kGreen : kAmber),
              ),
            ),
          )),
    ];
  }

  List<Widget> _buildTrackingTab(
    CircleModel c,
    StudentModel s,
    CirclePalette pal,
    List<String> mKeys,
    MonthRecord rec,
    AiAnalysis an,
    bool canEdit,
    int daysCount,
  ) {
    return [
      // Month selector
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: rec.key,
              items: mKeys
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text('${s.months[k]!.label}${s.months[k]!.archived ? ' (مؤرشف)' : ''}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonthKey = v),
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final nextM = rec.month == 12 ? 1 : rec.month + 1;
                final nextY = rec.month == 12 ? rec.year + 1 : rec.year;
                final nk = monthKey(nextY, nextM);
                s.months.forEach((_, mr) => mr.archived = true);
                s.months[nk] ??= MonthRecord.empty(nextY, nextM);
                s.months[nk]!.archived = false;
                s.activeMonthKey = nk;
                _selectedMonthKey = nk;
                appStore.saveCircle(c.id);
              },
              child: const Text('📦 أرشفة'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),

      // Juz Progress Bar
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('📗 الحفظ: ${s.juzCount} / 30 جزءاً', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (!widget.readOnly)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            s.juzCount = (s.juzCount - 1).clamp(0, 30);
                            appStore.saveCircle(c.id);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: pal.main),
                          onPressed: () {
                            s.juzCount = (s.juzCount + 1).clamp(0, 30);
                            appStore.saveCircle(c.id);
                          },
                        ),
                      ],
                    ),
                ],
              ),
              LinearProgressIndicator(value: s.juzCount / 30, minHeight: 10, borderRadius: BorderRadius.circular(8), color: pal.main),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Badges
      if (an.badges.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: an.badges
              .map((b) => Chip(
                    backgroundColor: b.color,
                    label: Text('${b.icon} ${b.title}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ))
              .toList(),
        ),
      const SizedBox(height: 10),

      // Attendance Grid (15 Days Default + Add Day up to 30)
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('📅 الحضور والغياب ($daysCount يوماً)', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${an.attendanceRate}%', style: TextStyle(fontWeight: FontWeight.w800, color: pal.main)),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: daysCount,
                itemBuilder: (_, idx) {
                  final d = idx + 1;
                  final v = rec.attendance['$d'] ?? 'none';
                  final bg = v == 'present'
                      ? kGreen
                      : (v == 'excused' ? kAmber : (v == 'absent' ? kRed : Theme.of(context).scaffoldBackgroundColor));
                  final fg = v == 'none' ? Colors.grey : Colors.white;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: !canEdit
                        ? null
                        : () {
                            const order = ['none', 'present', 'excused', 'absent'];
                            rec.attendance['$d'] = order[(order.indexOf(v) + 1) % order.length];
                            appStore.saveCircle(c.id);
                          },
                    child: Container(
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('$d', style: TextStyle(color: fg, fontWeight: FontWeight.w800))),
                    ),
                  );
                },
              ),
              if (canEdit && daysCount < 30) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      rec.daysCount = (daysCount + 1).clamp(15, 30);
                      appStore.saveCircle(c.id);
                    },
                    child: Text('➕ إضافة يوم (${daysCount + 1})'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Recitation Grid
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📖 التسميع اليومي ($daysCount خانة)', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.9),
                itemCount: daysCount,
                itemBuilder: (_, idx) {
                  final d = idx + 1;
                  final t = rec.tasmi['$d'];
                  final has = t != null && t.text.isNotEmpty;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openTasmiDialog(c, rec, d, !canEdit),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: has ? pal.soft : Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: has ? pal.main : Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$d', style: TextStyle(fontWeight: FontWeight.w800, color: has ? pal.deep : Colors.grey)),
                          Text(has ? t.grade : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: has ? pal.deep : Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),

      // AI Analysis + Copy Report
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('✨ التحليل الذكي للأداء', style: TextStyle(fontWeight: FontWeight.w800)),
                  Chip(backgroundColor: an.badgeBg, label: Text(an.level, style: TextStyle(color: an.badgeText, fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ),
              ...an.insights.map((ins) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $ins', style: const TextStyle(fontSize: 12.5)),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: pal.main, foregroundColor: Colors.white),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ التقرير الشهري'),
                  onPressed: () {
                    final report = '📘 جمعية خير أمة\n${pal.studentWord}: ${s.name}\nالحلقة: ${c.name}\nالشهر: ${rec.label}\nالأجزاء: ${s.juzCount}/30\nالحضور: ${an.present} | بعذر: ${an.excused} | غياب: ${an.absent} (${an.attendanceRate}%)\nالتسميع: ${an.tasmiCount} | التقييم: ${an.overallScore}% (${an.level})';
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ التقرير الشهري')));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
