import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Brand Palettes & Constants (Khayr Ummah Association — Official Identity)
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

const int kDefaultDaysCount = 12;
const int kMaxDaysCount = 30;

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

// Complete 114 Surahs of the Holy Quran (Total Ayahs = 6236)
class SurahInfo {
  final int number;
  final String name;
  final int ayahs;
  const SurahInfo(this.number, this.name, this.ayahs);
}

const List<SurahInfo> kSurahs = [
  SurahInfo(1, 'الفاتحة', 7),
  SurahInfo(2, 'البقرة', 286),
  SurahInfo(3, 'آل عمران', 200),
  SurahInfo(4, 'النساء', 176),
  SurahInfo(5, 'المائدة', 120),
  SurahInfo(6, 'الأنعام', 165),
  SurahInfo(7, 'الأعراف', 206),
  SurahInfo(8, 'الأنفال', 75),
  SurahInfo(9, 'التوبة', 129),
  SurahInfo(10, 'يونس', 109),
  SurahInfo(11, 'هود', 123),
  SurahInfo(12, 'يوسف', 111),
  SurahInfo(13, 'الرعد', 43),
  SurahInfo(14, 'إبراهيم', 52),
  SurahInfo(15, 'الحجر', 99),
  SurahInfo(16, 'النحل', 128),
  SurahInfo(17, 'الإسراء', 111),
  SurahInfo(18, 'الكهف', 110),
  SurahInfo(19, 'مريم', 98),
  SurahInfo(20, 'طه', 135),
  SurahInfo(21, 'الأنبياء', 112),
  SurahInfo(22, 'الحج', 78),
  SurahInfo(23, 'المؤمنون', 118),
  SurahInfo(24, 'النور', 64),
  SurahInfo(25, 'الفرقان', 77),
  SurahInfo(26, 'الشعراء', 227),
  SurahInfo(27, 'النمل', 93),
  SurahInfo(28, 'القصص', 88),
  SurahInfo(29, 'العنكبوت', 69),
  SurahInfo(30, 'الروم', 60),
  SurahInfo(31, 'لقمان', 34),
  SurahInfo(32, 'السجدة', 30),
  SurahInfo(33, 'الأحزاب', 73),
  SurahInfo(34, 'سبأ', 54),
  SurahInfo(35, 'فاطر', 45),
  SurahInfo(36, 'يس', 83),
  SurahInfo(37, 'الصافات', 182),
  SurahInfo(38, 'ص', 88),
  SurahInfo(39, 'الزمر', 75),
  SurahInfo(40, 'غافر', 85),
  SurahInfo(41, 'فصلت', 54),
  SurahInfo(42, 'الشورى', 53),
  SurahInfo(43, 'الزخرف', 89),
  SurahInfo(44, 'الدخان', 59),
  SurahInfo(45, 'الجاثية', 37),
  SurahInfo(46, 'الأحقاف', 35),
  SurahInfo(47, 'محمد', 38),
  SurahInfo(48, 'الفتح', 29),
  SurahInfo(49, 'الحجرات', 18),
  SurahInfo(50, 'ق', 45),
  SurahInfo(51, 'الذاريات', 60),
  SurahInfo(52, 'الطور', 49),
  SurahInfo(53, 'النجم', 62),
  SurahInfo(54, 'القمر', 55),
  SurahInfo(55, 'الرحمن', 78),
  SurahInfo(56, 'الواقعة', 96),
  SurahInfo(57, 'الحديد', 29),
  SurahInfo(58, 'المجادلة', 22),
  SurahInfo(59, 'الحشر', 24),
  SurahInfo(60, 'الممتحنة', 13),
  SurahInfo(61, 'الصف', 14),
  SurahInfo(62, 'الجمعة', 11),
  SurahInfo(63, 'المنافقون', 11),
  SurahInfo(64, 'التغابن', 18),
  SurahInfo(65, 'الطلاق', 12),
  SurahInfo(66, 'التحريم', 12),
  SurahInfo(67, 'الملك', 30),
  SurahInfo(68, 'القلم', 52),
  SurahInfo(69, 'الحاقة', 52),
  SurahInfo(70, 'المعارج', 44),
  SurahInfo(71, 'نوح', 28),
  SurahInfo(72, 'الجن', 28),
  SurahInfo(73, 'المزمل', 20),
  SurahInfo(74, 'المدثر', 56),
  SurahInfo(75, 'القيامة', 40),
  SurahInfo(76, 'الإنسان', 31),
  SurahInfo(77, 'المرسلات', 50),
  SurahInfo(78, 'النبأ', 40),
  SurahInfo(79, 'النازعات', 46),
  SurahInfo(80, 'عبس', 42),
  SurahInfo(81, 'التكوير', 29),
  SurahInfo(82, 'الانفطار', 19),
  SurahInfo(83, 'المطففين', 36),
  SurahInfo(84, 'الانشقاق', 25),
  SurahInfo(85, 'البروج', 22),
  SurahInfo(86, 'الطارق', 17),
  SurahInfo(87, 'الأعلى', 19),
  SurahInfo(88, 'الغاشية', 26),
  SurahInfo(89, 'الفجر', 30),
  SurahInfo(90, 'البلد', 20),
  SurahInfo(91, 'الشمس', 15),
  SurahInfo(92, 'الليل', 21),
  SurahInfo(93, 'الضحى', 11),
  SurahInfo(94, 'الشرح', 8),
  SurahInfo(95, 'التين', 8),
  SurahInfo(96, 'العلق', 19),
  SurahInfo(97, 'القدر', 5),
  SurahInfo(98, 'البينة', 8),
  SurahInfo(99, 'الزلزلة', 8),
  SurahInfo(100, 'العاديات', 11),
  SurahInfo(101, 'القارعة', 11),
  SurahInfo(102, 'التكاثر', 8),
  SurahInfo(103, 'العصر', 3),
  SurahInfo(104, 'الهمزة', 9),
  SurahInfo(105, 'الفيل', 5),
  SurahInfo(106, 'قريش', 4),
  SurahInfo(107, 'الماعون', 7),
  SurahInfo(108, 'الكوثر', 3),
  SurahInfo(109, 'الكافرون', 6),
  SurahInfo(110, 'النصر', 3),
  SurahInfo(111, 'المسد', 5),
  SurahInfo(112, 'الإخلاص', 4),
  SurahInfo(113, 'الفلق', 5),
  SurahInfo(114, 'الناس', 6),
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

  int rotr(int x, int n) =>
      ((x >> n) | ((x << (32 - n)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
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
    int a = h[0], b = h[1], c = h[2], d = h[3];
    int e = h[4], f = h[5], g = h[6], hh = h[7];
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

int _idSeq = 0;
String genId(String prefix) {
  _idSeq++;
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$_idSeq';
}

// ---------------------------------------------------------------------------
// Offline Astronomical Prayer Times (Damascus, Syria: 33.5138 N, 36.2765 E, UTC+3)
// ---------------------------------------------------------------------------
class PrayerTimesInfo {
  final List<({String name, int minutes})> prayers;
  final int nextIndex;
  final int minutesRemaining;
  final double progress;
  final String currentClock;

  PrayerTimesInfo({
    required this.prayers,
    required this.nextIndex,
    required this.minutesRemaining,
    required this.progress,
    required this.currentClock,
  });

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;

  static int _clampMin(double hours) {
    var h = hours % 24.0;
    if (h < 0) h += 24.0;
    return (h * 60.0).round() % 1440;
  }

  static String fmtMin(int totalMin) {
    final h24 = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String fmtCountdown(int mins) {
    if (mins < 60) return '$mins د';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h س' : '$h س $m د';
  }

  factory PrayerTimesInfo.forDamascus(DateTime now) {
    const lat = 33.5138;
    const lng = 36.2765;
    const tz = 3.0; // Syria Standard Time (UTC+3)

    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    final gamma = 2.0 * math.pi / 365.0 * (dayOfYear - 1);

    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final dhuhrH = 12.0 + tz - (lng / 15.0) - (eqTime / 60.0);

    double hourAngle(double angleDeg) {
      final cosH = (-math.sin(_deg2rad(angleDeg)) -
              math.sin(_deg2rad(lat)) * math.sin(decl)) /
          (math.cos(_deg2rad(lat)) * math.cos(decl));
      return _rad2deg(math.acos(cosH.clamp(-1.0, 1.0))) / 15.0;
    }

    final fajrH = dhuhrH - hourAngle(18.5);
    final maghribH = dhuhrH + hourAngle(0.833);
    final ishaH = dhuhrH + hourAngle(17.5);

    // Asr (Shafi'i / Standard shadow factor = 1)
    final asrAngle = -_rad2deg(
        math.atan(1.0 / (1.0 + math.tan((_deg2rad(lat) - decl).abs()))));
    final asrH = dhuhrH + hourAngle(asrAngle);

    final list = <({String name, int minutes})>[
      (name: 'الفجر', minutes: _clampMin(fajrH)),
      (name: 'الظهر', minutes: _clampMin(dhuhrH + 0.03)),
      (name: 'العصر', minutes: _clampMin(asrH)),
      (name: 'المغرب', minutes: _clampMin(maghribH + 0.03)),
      (name: 'العشاء', minutes: _clampMin(ishaH)),
    ];

    final curMin = now.hour * 60 + now.minute;
    int nextIdx = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i].minutes > curMin) {
        nextIdx = i;
        break;
      }
      if (i == list.length - 1) nextIdx = 0;
    }

    final prevIdx = (nextIdx - 1 + list.length) % list.length;
    final nextM = list[nextIdx].minutes;
    final prevM = list[prevIdx].minutes;
    int rem = nextM - curMin;
    if (rem <= 0) rem += 1440;
    int span = nextM - prevM;
    if (span <= 0) span += 1440;
    final elapsed = (span - rem).clamp(0, span);
    final prog = span > 0 ? (elapsed / span).clamp(0.05, 1.0) : 0.5;

    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return PrayerTimesInfo(
      prayers: list,
      nextIndex: nextIdx,
      minutesRemaining: rem,
      progress: prog,
      currentClock: clock,
    );
  }
}

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
// Data Models (100% Compatible with Supabase app_state)
// ---------------------------------------------------------------------------
class TasmiEntry {
  String text;
  String type; // 'new' (حفظ جديد) | 'review' (مراجعة)
  String grade;
  String note;

  TasmiEntry({
    required this.text,
    this.type = 'new',
    required this.grade,
    this.note = '',
  });

  bool get isReview => type == 'review';
  String get typeLabel => isReview ? 'مراجعة' : 'حفظ جديد';

  TasmiEntry copy() => TasmiEntry(
        text: text,
        type: type,
        grade: grade,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'type': type,
        'grade': grade,
        'note': note,
      };

  factory TasmiEntry.fromJson(Map<String, dynamic> j) => TasmiEntry(
        text: (j['text'] ?? '').toString(),
        type: (j['type'] ?? 'new').toString() == 'review' ? 'review' : 'new',
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
  int daysCount; // default 12, expandable up to 30
  Map<String, TasmiEntry?> tasmi;
  Map<String, String> attendance;

  MonthRecord({
    required this.key,
    required this.year,
    required this.month,
    required this.label,
    required this.archived,
    this.daysCount = kDefaultDaysCount,
    required this.tasmi,
    required this.attendance,
  });

  factory MonthRecord.empty(
    int year,
    int month, {
    bool archived = false,
    int daysCount = kDefaultDaysCount,
  }) {
    final t = <String, TasmiEntry?>{};
    final a = <String, String>{};
    for (int d = 1; d <= kMaxDaysCount; d++) {
      t['$d'] = null;
      a['$d'] = 'none';
    }
    return MonthRecord(
      key: monthKey(year, month),
      year: year,
      month: month,
      label: monthLabel(month, year),
      archived: archived,
      daysCount: daysCount.clamp(kDefaultDaysCount, kMaxDaysCount),
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
    int maxUsed = (j['daysCount'] is int)
        ? (j['daysCount'] as int).clamp(kDefaultDaysCount, kMaxDaysCount)
        : kDefaultDaysCount;
    for (int d = 1; d <= kMaxDaysCount; d++) {
      final dk = '$d';
      final tv = tRaw[dk];
      if (tv is Map<String, dynamic> &&
          (tv['text'] ?? '').toString().trim().isNotEmpty) {
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
      daysCount: maxUsed.clamp(kDefaultDaysCount, kMaxDaysCount),
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
      juzCount: (j['juzCount'] is num)
          ? (j['juzCount'] as num).toInt().clamp(0, 30)
          : 0,
      points: (j['points'] is num)
          ? (j['points'] as num).toInt().clamp(0, 999999)
          : 0,
      pointsHistory: phRaw
          .whereType<Map<String, dynamic>>()
          .map(PointsLogEntry.fromJson)
          .toList(),
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
      students: sRaw
          .whereType<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList(),
    );
  }
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

  factory ContactMethodModel.fromJson(Map<String, dynamic> j) =>
      ContactMethodModel(
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
    int present = 0,
        excused = 0,
        absent = 0,
        tasmiCount = 0,
        gradePts = 0,
        streak = 0,
        maxStreak = 0;
    const gMap = {'ممتاز': 100, 'جيد جداً': 85, 'جيد': 70, 'يحتاج مراجعة': 50};
    final limit = rec.daysCount.clamp(kDefaultDaysCount, kMaxDaysCount);

    for (int d = 1; d <= kMaxDaysCount; d++) {
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
    final attRate = counted > 0
        ? ((present / counted) * 100).round()
        : (excused > 0 ? 100 : 0);
    final avgGrade = tasmiCount > 0 ? (gradePts / tasmiCount).round() : 0;
    final paceTarget =
        (present > 0 ? present : 1).clamp(1, limit < 12 ? limit : 12);
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
      if (tasmiCount >= 8 && avgGrade >= 85) {
        insights.add(
            'إنجاز قوي في التسميع ($tasmiCount جلسات بمتوسط جودة $avgGrade%) يعكس حفظاً متيناً.');
      } else if (tasmiCount >= 3) {
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
            insights.add(
                'مقارنة بشهر ${prev.label}: تطوّر إيجابي بمقدار +$diff نقطة.');
          }
          if (diff <= -5) {
            insights.add(
                'مقارنة بشهر ${prev.label}: تراجع بمقدار ${diff.abs()} نقطة؛ يُنصح بالدعم.');
          }
        }
      }
    }

    final badges = <({String title, String icon, Color color})>[];
    if (attRate >= 90 && present >= 5) {
      badges.add((title: 'بطل الالتزام', icon: '🛡️', color: kGreen));
    }
    if (tasmiCount >= 4) {
      badges.add((title: 'مثابر التسميع', icon: '📖', color: kBlueMain));
    }
    if (overall >= 85) {
      badges.add((title: 'نجم التميّز', icon: '⭐', color: kGold));
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
// App Controller (Per-Circle Supabase Sync + Offline Queue + Pinned Children)
// ---------------------------------------------------------------------------
class AppStore extends ChangeNotifier {
  List<CircleModel> circles = [];
  List<ContactMethodModel> contacts = [];
  String generalAnnouncement = '';

  List<Map<String, String>> pinnedStudents = []; // [{circleId, studentId}]
  List<Map<String, String>> recentSearches = [];
  bool darkMode = false;
  int dhikrIndex = 0;

  Set<String> pendingCircleIds = {};
  bool pendingMeta = false;
  String syncStatus =
      'connecting'; // connecting | synced | saving | pending | offline
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
            .map((m) => {
                  'circleId': '${m['circleId'] ?? ''}',
                  'studentId': '${m['studentId'] ?? ''}',
                })
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
        pendingCircleIds = ((m['circles'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toSet();
        pendingMeta = m['meta'] == true;
      } catch (_) {}
    }

    notifyListeners();
    await syncFromCloud();
  }

  Map<String, dynamic> toFullJson() => {
        'circles': circles.map((c) => c.toJson()).toList(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'generalAnnouncement': generalAnnouncement,
      };

  void _loadFromJsonMap(Map<String, dynamic> raw) {
    circles = ((raw['circles'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CircleModel.fromJson)
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
    SharedPreferences.getInstance()
        .then((p) => p.setInt(kDhikrIdxKey, dhikrIndex));
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

  bool isPinned(String circleId, String studentId) => pinnedStudents
      .any((p) => p['circleId'] == circleId && p['studentId'] == studentId);

  Future<void> togglePin(String circleId, String studentId) async {
    if (isPinned(circleId, studentId)) {
      pinnedStudents.removeWhere(
          (p) => p['circleId'] == circleId && p['studentId'] == studentId);
    } else {
      pinnedStudents.add({'circleId': circleId, 'studentId': studentId});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPinnedKey, jsonEncode(pinnedStudents));
    notifyListeners();
  }

  Future<void> addRecent(String circleId, String studentId, String studentName,
      String circleName, String gender) async {
    recentSearches.removeWhere(
        (r) => r['circleId'] == circleId && r['studentId'] == studentId);
    recentSearches.insert(0, {
      'circleId': circleId,
      'studentId': studentId,
      'studentName': studentName,
      'circleName': circleName,
      'gender': gender,
    });
    if (recentSearches.length > 6) {
      recentSearches = recentSearches.sublist(0, 6);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRecentKey, jsonEncode(recentSearches));
    notifyListeners();
  }

  Future<void> _upsertRow(String rowId, Map<String, dynamic> payload) async {
    final uri =
        Uri.parse('$kSupabaseUrl/rest/v1/$kSupabaseTable?on_conflict=id');
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
            {
              'id': rowId,
              'data': payload,
              'updated_at': DateTime.now().toIso8601String(),
            }
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
          'contacts': contacts.map((c) => c.toJson()).toList(),
          'generalAnnouncement': generalAnnouncement,
        });
        await _upsertRow(
            'main', {'circles': circles.map((c) => c.toJson()).toList()});
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
      final uri = Uri.parse(
          '$kSupabaseUrl/rest/v1/$kSupabaseTable?select=id,data,updated_at');
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
            contacts = ((meta['contacts'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .map(ContactMethodModel.fromJson)
                .toList();
            generalAnnouncement =
                (meta['generalAnnouncement'] ?? '').toString();
          }
          await _saveLocal();
        }
        syncStatus = 'synced';
      } else {
        syncStatus =
            (pendingCircleIds.isNotEmpty || pendingMeta) ? 'pending' : 'offline';
      }
    } catch (_) {
      syncStatus =
          (pendingCircleIds.isNotEmpty || pendingMeta) ? 'pending' : 'offline';
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

  // AI computes Top 3 Stars ONLY from the latest archived month across circles
  ({
    String? monthLabel,
    List<
        ({
          String circleId,
          String studentId,
          String name,
          String circleName,
          String gender,
          int score,
          int tasmiCount,
          int attendanceRate,
        })> stars
  }) topStarsFromLatestArchivedMonth() {
    String? latestKey;
    String? latestLabel;
    for (final c in circles) {
      for (final s in c.students) {
        for (final rec in s.months.values) {
          if (rec.archived) {
            if (latestKey == null || rec.key.compareTo(latestKey) > 0) {
              latestKey = rec.key;
              latestLabel = rec.label;
            }
          }
        }
      }
    }
    if (latestKey == null) {
      return (monthLabel: null, stars: []);
    }

    final list = <({
      String circleId,
      String studentId,
      String name,
      String circleName,
      String gender,
      int score,
      int tasmiCount,
      int attendanceRate,
    })>[];

    for (final c in circles) {
      for (final s in c.students) {
        final rec = s.months[latestKey];
        if (rec == null || !rec.archived) continue;
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
            attendanceRate: an.attendanceRate,
          ));
        }
      }
    }
    list.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      if (b.tasmiCount != a.tasmiCount) {
        return b.tasmiCount.compareTo(a.tasmiCount);
      }
      return b.attendanceRate.compareTo(a.attendanceRate);
    });
    return (monthLabel: latestLabel, stars: list.take(3).toList());
  }

  String latestActivitySummary(StudentModel s) {
    final rec = s.months[s.activeMonthKey];
    if (rec != null) {
      for (int d = kMaxDaysCount; d >= 1; d--) {
        final t = rec.tasmi['$d'];
        if (t != null && t.text.isNotEmpty) {
          return '${t.typeLabel}: ${t.text} (${t.grade})';
        }
      }
      for (int d = kMaxDaysCount; d >= 1; d--) {
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
// 1. Splash Screen (Original Blue Gradient + assets/logo.png in White Square)
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
                'نظام متابعة الحلقات القرآنية',
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
// 2. Home Screen (Original Curved Header + Offline Damascus Prayer Times +
//    Golden Teacher & Blue Student Pills + White Stars of the Month Card)
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _prayerTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _prayerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _prayerTimer?.cancel();
    super.dispose();
  }

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
                  const Text('القائمة الرئيسية',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('📞 طرق التواصل مع المعهد',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kBlueMain)),
              const SizedBox(height: 8),
              if (appStore.contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('لم يضف مدير المعهد طرق تواصل بعد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12)),
                )
              else
                ...appStore.contacts.map((ct) {
                  final meta = kContactTypes.firstWhere(
                      (e) => e['id'] == ct.type,
                      orElse: () => kContactTypes.last);
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
                            Text(meta['icon'] ?? '📍',
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      ct.label.isNotEmpty
                                          ? ct.label
                                          : (meta['label'] ?? ''),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13)),
                                  Text(ct.value,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Text('نسخ',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kBlueMain)),
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
                    gradient:
                        const LinearGradient(colors: [kBlueDeep, kBlueDark]),
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
                            Text('الإدارة العامة',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Text('خاص بمدير الجمعية والمعهد',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 16),
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
          await prefs.setString(
              kLockoutKey, jsonEncode({'fails': 0, 'until': 0}));
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('🛡️ الإدارة العامة — خاص بالمدير',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: locked
                ? Text(
                    '⛔ تم قفل الدخول مؤقتاً بعد 3 محاولات خاطئة.\nيرجى المحاولة بعد حوالي $minsLeft دقيقة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: kRed, fontWeight: FontWeight.bold, fontSize: 13),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('دخول محمي ومشفّر (SHA-256)',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة سر المدير...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (errMsg.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(errMsg,
                            style: const TextStyle(
                                color: kRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
            actions: locked
                ? [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'))
                  ]
                : [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kGoldDark,
                          foregroundColor: Colors.white),
                      onPressed: () async {
                        if (verifyDirectorPassword(ctrl.text)) {
                          await prefs.setString(kLockoutKey,
                              jsonEncode({'fails': 0, 'until': 0}));
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AdminDashboardScreen()),
                          );
                        } else {
                          fails++;
                          if (fails >= 3) {
                            until = DateTime.now().millisecondsSinceEpoch +
                                5 * 60 * 1000;
                          }
                          await prefs.setString(kLockoutKey,
                              jsonEncode({'fails': fails, 'until': until}));
                          setS(() {
                            errMsg =
                                'كلمة السر غير صحيحة (متبقي ${3 - fails} محاولات)';
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

  Widget _buildPrayerCard(PrayerTimesInfo info) {
    final nextPrayer = info.prayers[info.nextIndex];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🕌', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  const Text(
                    'أوقات الصلاة — دمشق',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'القادمة: ${nextPrayer.name} بعد ${PrayerTimesInfo.fmtCountdown(info.minutesRemaining)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: info.progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE7CFAF)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(info.prayers.length, (i) {
              final p = info.prayers[i];
              final isNext = i == info.nextIndex;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i < info.prayers.length - 1 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isNext
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: isNext ? kBlueDeep : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PrayerTimesInfo.fmtMin(p.minutes),
                        style: TextStyle(
                          color: isNext ? kGoldDark : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final dhikr = kAdhkar[appStore.dhikrIndex % kAdhkar.length];
        final starsData = appStore.topStarsFromLatestArchivedMonth();
        final stars = starsData.stars;
        final starsMonthLabel = starsData.monthLabel;
        const medals = ['🥇', '🥈', '🥉'];
        final prayerInfo = PrayerTimesInfo.forDamascus(_now);
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
                  // Curved Deep Damascene Blue Header (#1B4460 / #255575 / #4383AC)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                        18, MediaQuery.of(context).padding.top + 14, 18, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [kBlueDeep, kBlueDark, kBlueMain],
                      ),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(38)),
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
                                child:
                                    const Icon(Icons.menu, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
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
                                          : (appStore.syncStatus == 'pending'
                                              ? Colors.amber
                                              : Colors.white70),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_syncLabel(appStore.syncStatus),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
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
                                child: Icon(
                                    appStore.darkMode
                                        ? Icons.wb_sunny
                                        : Icons.nightlight_round,
                                    color: Colors.white,
                                    size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: appStore.nextDhikr,
                          child: Column(
                            children: [
                              Text(
                                dhikr,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'جمعية خير أمة — متابعة الحلقات القرآنية',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Offline Damascus Prayer Times Card inside Curved Header
                        _buildPrayerCard(prayerInfo),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                    child: Column(
                      children: [
                        // Golden Teacher Pill Button (#B6966C / #96764E)
                        _RolePillButton(
                          title: 'معلم',
                          subtitle: 'دخول مباشر لحلقتك بكلمة المرور الخاصة',
                          icon: '👨‍🏫',
                          colors: const [Color(0xFFC7A87D), kGold, kGoldDark],
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TeacherAuthScreen())),
                        ),
                        const SizedBox(height: 14),
                        // Blue Student Pill Button (#4383AC / #255575)
                        _RolePillButton(
                          title: 'طالب',
                          subtitle: hasValidPin
                              ? 'أبنائي المثبّتون (${appStore.pinnedStudents.length}) ورصيد النقاط'
                              : 'متابعة الطالب ورصيد النقاط',
                          icon: '📖',
                          colors: const [
                            Color(0xFF5696BF),
                            kBlueMain,
                            kBlueDark
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => hasValidPin
                                  ? const PinnedStudentsScreen()
                                  : const StudentSearchScreen(),
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
                              border: const Border(
                                  right: BorderSide(color: kGold, width: 4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📢',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('إعلان عام من إدارة الجمعية',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: kGoldDark)),
                                      const SizedBox(height: 3),
                                      Text(appStore.generalAnnouncement,
                                          style: const TextStyle(
                                              fontSize: 12.5, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // White Layered Arched Stars of the Month Card (Latest Archived Month ONLY)
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
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [kBlueDark, kBlueMain]),
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(28)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 14, 14, 18),
                                    child: stars.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: Column(
                                              children: [
                                                Text(
                                                    '🌟 بانتظار إعلان نجوم الشهر',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14)),
                                                SizedBox(height: 4),
                                                Text(
                                                  'يُحسب الأوائل الـ 3 تلقائياً بعد أرشفة الشهر من قِبل المعلمين',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Column(
                                            children: [
                                              if (starsMonthLabel != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 10),
                                                  child: Text(
                                                    'أوائل آخر شهر مؤرشف: $starsMonthLabel',
                                                    style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: kGoldDark),
                                                  ),
                                                ),
                                              ...List.generate(stars.length,
                                                  (i) {
                                                final st = stars[i];
                                                final pal =
                                                    CirclePalette.forGender(
                                                        st.gender);
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                      bottom:
                                                          i < stars.length - 1
                                                              ? 10
                                                              : 0),
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            18),
                                                    onTap: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            StudentProfileScreen(
                                                          circleId: st.circleId,
                                                          studentId:
                                                              st.studentId,
                                                          readOnly: true,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .scaffoldBackgroundColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(18),
                                                        border: pal.isFemale
                                                            ? Border.all(
                                                                color: kPinkMain
                                                                    .withValues(
                                                                        alpha:
                                                                            0.28))
                                                            : null,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Text(medals[i],
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          22)),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(st.name,
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w800,
                                                                        fontSize:
                                                                            14)),
                                                                Text(
                                                                    '${st.circleName} • ${st.tasmiCount} تسميع',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: pal.isFemale
                                                                            ? kPinkDeep
                                                                            : Colors.grey)),
                                                              ],
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: pal.main,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          14),
                                                            ),
                                                            child: Text(
                                                                '${st.score}%',
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        12)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFC9A97E),
                                  kGold,
                                  kGoldDark
                                ]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                      color: kGoldDark.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5))
                                ],
                              ),
                              child: const Text('⭐  نجوم الشهر',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
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
          boxShadow: [
            BoxShadow(
                color: colors.last.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16)),
              child:
                  Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 18),
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
  bool _obscure = true;
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
        MaterialPageRoute(
            builder: (_) =>
                CircleDetailScreen(circleId: matched!.id, isAdmin: false)),
      );
    } else {
      setState(() => _err = 'كلمة مرور الحلقة غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('بوابة المعلم'),
          backgroundColor: kBlueDark,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔑', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 10),
                const Text('أدخل كلمة مرور حلقتك الخاصة',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'كلمة مرور الحلقة...',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_err,
                      style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGoldDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _submit,
                    child: const Text('دخول لحلقتي فقط',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
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
// 4. Admin Dashboard (3 Tabs: الحلقات | النقاط فقط بدون سوق | التواصل)
//    Includes Safe Auto-Logout on Background / Inactivity
// ---------------------------------------------------------------------------
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  int _tab = 0; // 0: Circles, 1: Points, 2: Contacts
  final _ptsSearchCtrl = TextEditingController();
  final _ptsAmountCtrl = TextEditingController(text: '20');
  final _ptsReasonCtrl = TextEditingController();
  String? _selectedStudentPair; // 'circleId::studentId'
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _ptsSearchCtrl.dispose();
    _ptsAmountCtrl.dispose();
    _ptsReasonCtrl.dispose();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 15), _safeLogout);
  }

  void _safeLogout() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _safeLogout();
    }
  }

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(existing == null ? 'إنشاء حلقة جديدة' : 'تعديل الحلقة',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration:
                        const InputDecoration(labelText: 'اسم الحلقة *')),
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
                TextField(
                    controller: mosqueC,
                    decoration:
                        const InputDecoration(labelText: 'المسجد / المركز')),
                TextField(
                    controller: teacherC,
                    decoration:
                        const InputDecoration(labelText: 'اسم المعلم / المعلمة')),
                TextField(
                    controller: schedC,
                    decoration:
                        const InputDecoration(labelText: 'الأيام والأوقات')),
                TextField(
                    controller: passC,
                    decoration: const InputDecoration(
                        labelText: 'كلمة مرور الحلقة للمعلم *')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameC.text.trim().isEmpty || passC.text.trim().isEmpty) {
                  return;
                }
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
        content: TextField(
            controller: c,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'اكتب الإعلان العام...')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
        title: const Text('💾 النسخة الاحتياطية (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('نسخ النسخة الاحتياطية الكاملة'),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: jsonEncode(appStore.toFullJson())));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تم نسخ النسخة الاحتياطية JSON بنجاح')));
              },
            ),
            const Divider(height: 24),
            TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'أو الصق نص النسخة الاحتياطية JSON هنا للاستعادة...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ElevatedButton(
            onPressed: () async {
              final ok = await appStore.restoreFromJsonString(c.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(ok ? 'تمت الاستعادة بنجاح' : 'نص النسخة غير صالح')),
              );
            },
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _openTransferFromAdminDialog() {
    if (appStore.circles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يلزم وجود حلقتين على الأقل لنقل طالب')),
      );
      return;
    }
    final allEntries = <({CircleModel circle, StudentModel student})>[];
    for (final c in appStore.circles) {
      for (final s in c.students) {
        allEntries.add((circle: c, student: s));
      }
    }
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب للنقل حالياً')),
      );
      return;
    }

    String selectedPair = '${allEntries.first.circle.id}::${allEntries.first.student.id}';
    String? targetCircleId = appStore.circles
        .firstWhere((c) => c.id != allEntries.first.circle.id)
        .id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final parts = selectedPair.split('::');
          final fromCid = parts[0];
          final targets =
              appStore.circles.where((c) => c.id != fromCid).toList();
          if (targetCircleId == null ||
              !targets.any((t) => t.id == targetCircleId)) {
            targetCircleId = targets.isNotEmpty ? targets.first.id : null;
          }
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('🔄 نقل طالب إلى حلقة أخرى',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPair,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'اختر الطالب'),
                  items: allEntries
                      .map((e) => DropdownMenuItem(
                            value: '${e.circle.id}::${e.student.id}',
                            child: Text('${e.student.name} (${e.circle.name})',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => selectedPair = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: targetCircleId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'الحلقة المستقبِلة'),
                  items: targets
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => targetCircleId = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: targetCircleId == null
                    ? null
                    : () {
                        final p = selectedPair.split('::');
                        final fromC = appStore.getCircle(p[0]);
                        final st = appStore.getStudent(fromC, p[1]);
                        final toC = appStore.getCircle(targetCircleId!);
                        if (fromC != null && st != null && toC != null) {
                          fromC.students.removeWhere((x) => x.id == st.id);
                          toC.students.add(st);
                          appStore.saveMetaAndCircles([fromC.id, toC.id]);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'تم نقل ${st.name} إلى ${toC.name} بنجاح')),
                          );
                        }
                      },
                child: const Text('تأكيد النقل'),
              ),
            ],
          );
        },
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
          title: Text(
              existing == null ? 'إضافة طريقة تواصل' : 'تعديل طريقة تواصل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: kContactTypes
                    .map((t) => DropdownMenuItem(
                        value: t['id'],
                        child: Text('${t['icon']} ${t['label']}')))
                    .toList(),
                onChanged: (v) => setS(() => type = v ?? 'whatsapp'),
              ),
              TextField(
                  controller: labelC,
                  decoration:
                      const InputDecoration(labelText: 'العنوان (اختياري)')),
              TextField(
                  controller: valC,
                  decoration: const InputDecoration(
                      labelText: 'الرقم أو الرابط أو النص *')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
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
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      child: AnimatedBuilder(
        animation: appStore,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('🛡️ لوحة مدير الجمعية'),
              backgroundColor: kBlueDeep,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                    onPressed: appStore.syncFromCloud),
                IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'خروج آمن',
                    onPressed: _safeLogout),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('الحلقات')),
                      ButtonSegment(value: 1, label: Text('النقاط')),
                      ButtonSegment(value: 2, label: Text('التواصل')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                Expanded(
                  child: _tab == 0
                      ? _buildCirclesTab()
                      : (_tab == 1 ? _buildPointsTab() : _buildContactsTab()),
                ),
              ],
            ),
          );
        },
      ),
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
                style: ElevatedButton.styleFrom(
                    backgroundColor: kGoldDark, foregroundColor: Colors.white),
                icon: const Icon(Icons.add),
                label: const Text('حلقة جديدة'),
                onPressed: () => _openCircleDialog(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kBlueMain, foregroundColor: Colors.white),
                icon: const Icon(Icons.campaign),
                label: const Text('إعلان عام'),
                onPressed: _openGeneralAnnDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('نقل طالب'),
                onPressed: _openTransferFromAdminDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.backup, size: 18),
                label: const Text('نسخة JSON'),
                onPressed: _openBackupRestoreDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...appStore.circles.map((c) {
          final pal = CirclePalette.forGender(c.gender);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16))),
                      Chip(
                          backgroundColor: pal.soft,
                          label: Text('${c.students.length} ${pal.studentsWord}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pal.deep))),
                    ],
                  ),
                  Text('🕌 ${c.mosque} • 👤 ${c.teacher}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text('🔑 كلمة مرور الحلقة: ${c.password}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kGoldDark)),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.copy, size: 16, color: kBlueMain),
                        label: const Text('نسخ',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kBlueMain)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: c.password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('تم نسخ كلمة مرور حلقة ${c.name}')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: pal.main,
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CircleDetailScreen(
                                    circleId: c.id, isAdmin: true)),
                          ),
                          child: const Text('فتح الحلقة'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openCircleDialog(existing: c)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: kRed),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('تأكيد حذف الحلقة'),
                              content: Text(
                                  'هل تريد حذف حلقة "${c.name}" بجميع طلابها؟'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(dCtx),
                                    child: const Text('إلغاء')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: kRed,
                                      foregroundColor: Colors.white),
                                  onPressed: () {
                                    appStore.circles
                                        .removeWhere((x) => x.id == c.id);
                                    appStore.saveMetaAndCircles([c.id]);
                                    Navigator.pop(dCtx);
                                  },
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
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

  // Points Tab: Live student search to add/deduct points with reason ONLY (NO market, NO requests)
  Widget _buildPointsTab() {
    final q = normalizeArabic(_ptsSearchCtrl.text);
    final allStudents = <({CircleModel circle, StudentModel student})>[];
    for (final c in appStore.circles) {
      for (final s in c.students) {
        if (q.isEmpty ||
            normalizeArabic(s.name).contains(q) ||
            normalizeArabic(c.name).contains(q)) {
          allStudents.add((circle: c, student: s));
        }
      }
    }
    allStudents.sort((a, b) =>
        normalizeArabic(a.student.name).compareTo(normalizeArabic(b.student.name)));
    final validValues =
        allStudents.map((x) => '${x.circle.id}::${x.student.id}').toList();
    if (_selectedStudentPair == null ||
        !validValues.contains(_selectedStudentPair)) {
      _selectedStudentPair = validValues.isNotEmpty ? validValues.first : null;
    }

    StudentModel? selectedStudent;
    CircleModel? selectedCircle;
    if (_selectedStudentPair != null) {
      final parts = _selectedStudentPair!.split('::');
      selectedCircle = appStore.getCircle(parts[0]);
      selectedStudent = appStore.getStudent(selectedCircle, parts[1]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ تحويل أو خصم النقاط لطالب',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                TextField(
                  controller: _ptsSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث باسم الطالب أو الحلقة مباشرة...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (allStudents.isEmpty)
                  const Text('لا توجد نتائج مطابقة',
                      style: TextStyle(color: Colors.grey))
                else
                  DropdownButtonFormField<String>(
                    value: _selectedStudentPair,
                    isExpanded: true,
                    items: allStudents
                        .map((x) => DropdownMenuItem(
                              value: '${x.circle.id}::${x.student.id}',
                              child: Text(
                                  '${x.student.name} — ${x.circle.name} (${x.student.points} نقطة)',
                                  overflow: TextOverflow.ellipsis),
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
                        decoration: const InputDecoration(
                            labelText: 'السبب (يظهر بكشف الحساب)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kGoldDark,
                            foregroundColor: Colors.white),
                        onPressed: () => _applyPoints(1),
                        child: const Text('➕ تحويل نقاط'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _applyPoints(-1),
                        child:
                            const Text('➖ خصم نقاط', style: TextStyle(color: kRed)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (selectedStudent != null) ...[
          const SizedBox(height: 12),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '📜 كشف نقاط: ${selectedStudent.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Chip(
                        backgroundColor: kGoldSoft,
                        label: Text('⭐ ${selectedStudent.points} نقطة',
                            style: const TextStyle(
                                color: kGoldDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedStudent.pointsHistory.isEmpty)
                    const Text('لا توجد حركات نقاط مسجّلة لهذا الطالب بعد.',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...selectedStudent.pointsHistory.take(15).map((h) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(h.reason,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(h.date, style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            '${h.delta >= 0 ? '+' : ''}${h.delta}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: h.delta >= 0 ? kGreen : kRed),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
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
      SnackBar(
          content: Text(sign > 0
              ? 'تم تحويل +$amt نقطة لـ ${s.name}'
              : 'تم خصم $amt نقطة من ${s.name}')),
    );
  }

  Widget _buildContactsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: kGoldDark, foregroundColor: Colors.white),
          icon: const Icon(Icons.add),
          label: const Text('إضافة طريقة تواصل'),
          onPressed: () => _openContactDialog(),
        ),
        const SizedBox(height: 12),
        ...appStore.contacts.map((ct) {
          final meta = kContactTypes.firstWhere((e) => e['id'] == ct.type,
              orElse: () => kContactTypes.last);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading:
                  Text(meta['icon'] ?? '📍', style: const TextStyle(fontSize: 22)),
              title: Text(
                  ct.label.isNotEmpty ? ct.label : (meta['label'] ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ct.value),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _openContactDialog(existing: ct)),
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
// Reusable 114-Surah Recitation Picker & Editor (حفظ جديد / مراجعة + من/إلى آية + كاملة)
// ---------------------------------------------------------------------------
Future<({bool cleared, TasmiEntry? entry})?> showTasmiEditorSheet({
  required BuildContext context,
  required String title,
  TasmiEntry? initial,
  bool showGradeAndNote = true,
  bool allowClear = true,
}) async {
  String type = initial?.type ?? 'new'; // 'new' | 'review'
  String grade = (initial != null && kGrades.contains(initial.grade))
      ? initial.grade
      : 'ممتاز';
  final textC = TextEditingController(text: initial?.text ?? '');
  final noteC = TextEditingController(text: initial?.note ?? '');
  final surahSearchC = TextEditingController();
  final fromAyahC = TextEditingController();
  final toAyahC = TextEditingController();
  SurahInfo? selectedSurah;

  void syncSurahText({bool fullSurah = false}) {
    final s = selectedSurah;
    if (s == null) return;
    if (fullSurah) {
      fromAyahC.text = '1';
      toAyahC.text = '${s.ayahs}';
      textC.text = 'سورة ${s.name} (كاملة)';
      return;
    }
    final fromVal = (int.tryParse(fromAyahC.text.trim()) ?? 1).clamp(1, s.ayahs);
    final toVal =
        (int.tryParse(toAyahC.text.trim()) ?? s.ayahs).clamp(fromVal, s.ayahs);
    if (fromVal == 1 && toVal == s.ayahs) {
      textC.text = 'سورة ${s.name} (كاملة)';
    } else if (fromVal == toVal) {
      textC.text = 'سورة ${s.name} (آية $fromVal)';
    } else {
      textC.text = 'سورة ${s.name} (من $fromVal إلى $toVal)';
    }
  }

  return showModalBottomSheet<({bool cleared, TasmiEntry? entry})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final q = normalizeArabic(surahSearchC.text);
        final filteredSurahs = kSurahs.where((s) {
          if (q.isEmpty) return true;
          return normalizeArabic(s.name).contains(q) || '${s.number}' == q;
        }).toList();

        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),

                // Type toggle: حفظ جديد (Blue) vs مراجعة (Gold)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setS(() => type = 'new'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'new'
                                ? kBlueMain
                                : kBlueMain.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: kBlueMain,
                                width: type == 'new' ? 2 : 1),
                          ),
                          child: Center(
                            child: Text(
                              '📘 حفظ جديد',
                              style: TextStyle(
                                color: type == 'new' ? Colors.white : kBlueDeep,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setS(() => type = 'review'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'review'
                                ? kGoldDark
                                : kGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: kGoldDark,
                                width: type == 'review' ? 2 : 1),
                          ),
                          child: Center(
                            child: Text(
                              '📙 مراجعة',
                              style: TextStyle(
                                color:
                                    type == 'review' ? Colors.white : kGoldDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 114-Surah Searchable Picker
                TextField(
                  controller: surahSearchC,
                  onChanged: (_) => setS(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'ابحث في الـ 114 سورة بالاسم أو الرقم...',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 126,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListView.builder(
                      itemCount: filteredSurahs.length,
                      itemBuilder: (_, idx) {
                        final s = filteredSurahs[idx];
                        final isSel = selectedSurah?.number == s.number;
                        return ListTile(
                          dense: true,
                          selected: isSel,
                          selectedTileColor: kBlueMain.withValues(alpha: 0.14),
                          title: Text('${s.number}. سورة ${s.name}',
                              style: TextStyle(
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13)),
                          trailing: Text('${s.ayahs} آية',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          onTap: () {
                            setS(() {
                              selectedSurah = s;
                              fromAyahC.text = '1';
                              toAyahC.text = '${s.ayahs}';
                              syncSurahText(fullSurah: true);
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),

                // From Ayah / To Ayah + كاملة button
                if (selectedSurah != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromAyahC,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (_) => setS(() => syncSurahText()),
                          decoration: InputDecoration(
                            labelText: 'من آية',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: toAyahC,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (_) => setS(() => syncSurahText()),
                          decoration: InputDecoration(
                            labelText: 'إلى آية (حتى ${selectedSurah!.ayahs})',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              type == 'review' ? kGoldDark : kBlueMain,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () =>
                            setS(() => syncSurahText(fullSurah: true)),
                        child: const Text('كاملة',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),

                // Resulting Editable Recitation Text
                TextField(
                  controller: textC,
                  decoration: InputDecoration(
                    labelText: 'نص الورد / السورة والآيات',
                    hintText: 'مثال: سورة الملك (من 1 إلى 15)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),

                if (showGradeAndNote) ...[
                  const SizedBox(height: 10),
                  const Text('التقييم',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kGrades.map((g) {
                      final sel = grade == g;
                      return ChoiceChip(
                        label: Text(g,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel ? Colors.white : null)),
                        selected: sel,
                        selectedColor: kBlueMain,
                        onSelected: (_) => setS(() => grade = g),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteC,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'ملاحظة لولي الأمر (اختياري)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (allowClear) ...[
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, (cleared: true, entry: null)),
                        child:
                            const Text('مسح', style: TextStyle(color: kRed)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              type == 'review' ? kGoldDark : kBlueMain,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final txt = textC.text.trim();
                          if (txt.isEmpty) {
                            Navigator.pop(ctx, (cleared: true, entry: null));
                          } else {
                            Navigator.pop(
                              ctx,
                              (
                                cleared: false,
                                entry: TasmiEntry(
                                  text: txt,
                                  type: type,
                                  grade: grade,
                                  note: noteC.text.trim(),
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('حفظ التسميع',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// 5. Circle Detail Screen (Teacher Sees ONLY His Circle)
//    Includes: Quick Batch Screen, Bulk Student Paste, Alphabetical Sort & Search
// ---------------------------------------------------------------------------
class CircleDetailScreen extends StatefulWidget {
  final String circleId;
  final bool isAdmin;

  const CircleDetailScreen(
      {super.key, required this.circleId, required this.isAdmin});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  final _searchCtrl = TextEditingController();
  bool _sortAlpha = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openStudentDialog(BuildContext context, CircleModel c,
      {StudentModel? existing}) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final ageC = TextEditingController(text: existing?.age ?? '');
    final juzC = TextEditingController(text: '${existing?.juzCount ?? 0}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'إضافة جديد' : 'تعديل البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'الاسم الثلاثي *')),
            TextField(
                controller: ageC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'العمر')),
            TextField(
                controller: juzC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'الأجزاء المحفوظة (0-30)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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

  void _openBulkAddDialog(BuildContext context, CircleModel c, CirclePalette pal) {
    final bulkC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('📋 إضافة مجموعة ${pal.studentsWord} دفعة واحدة',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الصق الأسماء هنا — كل اسم في سطر مستقل:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: bulkC,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: 'محمد أحمد العلي\nعمر خالد الحسن\nيوسف سعيد...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
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
              final lines = bulkC.text
                  .split(RegExp(r'\r?\n'))
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
              if (lines.isEmpty) return;
              final now = DateTime.now();
              for (final name in lines) {
                final em = MonthRecord.empty(now.year, now.month);
                c.students.add(StudentModel(
                  id: genId('st'),
                  name: name,
                  age: '',
                  juzCount: 0,
                  activeMonthKey: em.key,
                  months: {em.key: em},
                ));
              }
              appStore.saveCircle(c.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('تمت إضافة ${lines.length} إلى ${c.name} بنجاح')),
              );
            },
            child: const Text('إضافة الكل'),
          ),
        ],
      ),
    );
  }

  void _openTransferDialog(
      BuildContext context, CircleModel fromC, StudentModel st) {
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
            items: targets
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setS(() => targetId = v ?? targetId),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
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
        final c = appStore.getCircle(widget.circleId);
        if (c == null) {
          return const Scaffold(body: Center(child: Text('الحلقة غير موجودة')));
        }
        final pal = CirclePalette.forGender(c.gender);
        final q = normalizeArabic(_searchCtrl.text);
        final list = c.students.where((st) {
          if (q.isEmpty) return true;
          return normalizeArabic(st.name).contains(q);
        }).toList();
        if (_sortAlpha) {
          list.sort((a, b) =>
              normalizeArabic(a.name).compareTo(normalizeArabic(b.name)));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            backgroundColor: pal.deep,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.campaign),
                tooltip: 'إعلان الحلقة',
                onPressed: () {
                  final ctrl = TextEditingController(text: c.announcement);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('إعلان الحلقة'),
                      content: TextField(controller: ctrl, maxLines: 3),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء')),
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
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: appStore.syncFromCloud),
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
              // Quick Batch Screen + Bulk Paste Actions
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pal.main,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.bolt, size: 20),
                      label: const Text('التسميع والحضور السريع للكل',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BatchDailyScreen(circleId: c.id)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.group_add, size: 18),
                      label: const Text('إضافة دفعة',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5)),
                      onPressed: () => _openBulkAddDialog(context, c, pal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick In-Circle Search + Alphabetical Sort Toggle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'بحث سريع داخل الحلقة...',
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _sortAlpha,
                    selectedColor: pal.soft,
                    label: Text(
                      'أ-ي',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _sortAlpha ? pal.deep : null),
                    ),
                    onSelected: (v) => setState(() => _sortAlpha = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (c.announcement.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Text('📢', style: TextStyle(fontSize: 20)),
                    title: const Text('إعلان الحلقة',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                    subtitle: Text(c.announcement),
                  ),
                ),

              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      c.students.isEmpty
                          ? 'لا يوجد ${pal.studentsWord} في هذه الحلقة بعد'
                          : 'لا توجد نتائج مطابقة للبحث',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...list.map((st) {
                  final rec = st.months[st.activeMonthKey];
                  final an = rec != null ? AiAnalysis.compute(rec, null) : null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      title: Text(st.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          'الحفظ: ${st.juzCount}/30 جزء • التقييم: ${an?.overallScore ?? 0}%'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentProfileScreen(
                              circleId: c.id,
                              studentId: st.id,
                              readOnly: false),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _openStudentDialog(context, c, existing: st)),
                          if (widget.isAdmin)
                            IconButton(
                                icon: const Icon(Icons.swap_horiz, size: 20),
                                onPressed: () =>
                                    _openTransferDialog(context, c, st)),
                          IconButton(
                            icon:
                                const Icon(Icons.delete, color: kRed, size: 20),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('تأكيد الحذف'),
                                  content: Text(
                                      'هل تريد حذف ${st.name} من الحلقة؟'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('إلغاء')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: kRed,
                                          foregroundColor: Colors.white),
                                      onPressed: () {
                                        c.students.removeWhere(
                                            (x) => x.id == st.id);
                                        appStore.saveCircle(c.id);
                                        Navigator.pop(dCtx);
                                      },
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
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
// 5B. Batch Quick Recitation & Attendance Screen (التسميع والحضور السريع للكل)
//     Includes: "تطبيق نفس الورد للكل" + Unsaved Changes Exit Warning (PopScope)
// ---------------------------------------------------------------------------
class BatchDailyScreen extends StatefulWidget {
  final String circleId;
  const BatchDailyScreen({super.key, required this.circleId});

  @override
  State<BatchDailyScreen> createState() => _BatchDailyScreenState();
}

class _BatchDailyScreenState extends State<BatchDailyScreen> {
  int _selectedDay = 1;
  int _daysVisible = kDefaultDaysCount;
  bool _dirty = false;

  // Draft maps keyed by studentId for the currently selected day
  final Map<String, String> _draftAttendance = {};
  final Map<String, TasmiEntry?> _draftTasmi = {};

  @override
  void initState() {
    super.initState();
    _loadDayFromStore(1);
  }

  void _loadDayFromStore(int day) {
    final c = appStore.getCircle(widget.circleId);
    if (c == null) return;
    int maxDays = kDefaultDaysCount;
    _draftAttendance.clear();
    _draftTasmi.clear();
    for (final st in c.students) {
      final rec = st.months[st.activeMonthKey];
      if (rec != null) {
        if (rec.daysCount > maxDays) maxDays = rec.daysCount;
        _draftAttendance[st.id] = rec.attendance['$day'] ?? 'none';
        _draftTasmi[st.id] = rec.tasmi['$day']?.copy();
      } else {
        _draftAttendance[st.id] = 'none';
        _draftTasmi[st.id] = null;
      }
    }
    setState(() {
      _selectedDay = day;
      _daysVisible = maxDays.clamp(kDefaultDaysCount, kMaxDaysCount);
      _dirty = false;
    });
  }

  void _saveAll() {
    final c = appStore.getCircle(widget.circleId);
    if (c == null) return;
    for (final st in c.students) {
      final rec = st.months[st.activeMonthKey];
      if (rec == null || rec.archived) continue;
      if (_selectedDay > rec.daysCount) {
        rec.daysCount = _selectedDay.clamp(kDefaultDaysCount, kMaxDaysCount);
      }
      if (_draftAttendance.containsKey(st.id)) {
        rec.attendance['$_selectedDay'] = _draftAttendance[st.id]!;
      }
      if (_draftTasmi.containsKey(st.id)) {
        rec.tasmi['$_selectedDay'] = _draftTasmi[st.id]?.copy();
      }
    }
    appStore.saveCircle(c.id);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ حضور وتسميع اليوم $_selectedDay للجميع')),
    );
  }

  Future<bool> _confirmDiscardOrSave() async {
    if (!_dirty) return true;
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ تنبيه قبل الخروج',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'توجد تعديلات في الحضور أو التسميع لم يتم حفظها بعد. ماذا تريد أن تفعل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'stay'),
              child: const Text('متابعة التعديل')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child:
                  const Text('خروج بدون حفظ', style: TextStyle(color: kRed))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('حفظ والخروج'),
          ),
        ],
      ),
    );
    if (res == 'save') {
      _saveAll();
      return true;
    }
    return res == 'discard';
  }

  Future<void> _applySameWirdToAll(CircleModel c) async {
    final res = await showTasmiEditorSheet(
      context: context,
      title: 'تطبيق نفس الورد للكل — اليوم $_selectedDay',
      showGradeAndNote: false,
      allowClear: false,
    );
    if (res == null || res.cleared || res.entry == null) return;
    final template = res.entry!;
    setState(() {
      for (final st in c.students) {
        final existing = _draftTasmi[st.id];
        _draftTasmi[st.id] = TasmiEntry(
          text: template.text,
          type: template.type,
          grade: existing?.grade ?? 'ممتاز',
          note: existing?.note ?? '',
        );
      }
      _dirty = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'تم تطبيق (${template.typeLabel}: ${template.text}) للجميع — اضغط حفظ الكل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = appStore.getCircle(widget.circleId);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('الحلقة غير موجودة')));
    }
    final pal = CirclePalette.forGender(c.gender);
    final sorted = List<StudentModel>.from(c.students)
      ..sort((a, b) =>
          normalizeArabic(a.name).compareTo(normalizeArabic(b.name)));

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscardOrSave();
        if (ok && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التسميع والحضور السريع للكل'),
          backgroundColor: pal.deep,
          foregroundColor: Colors.white,
          actions: [
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: const Text('حفظ الكل',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Day Selector Strip (1..daysVisible + Add Day up to 30)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...List.generate(_daysVisible, (idx) {
                          final d = idx + 1;
                          final sel = d == _selectedDay;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text('يوم $d',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: sel ? Colors.white : null)),
                              selected: sel,
                              selectedColor: pal.main,
                              onSelected: (_) async {
                                if (d == _selectedDay) return;
                                final ok = await _confirmDiscardOrSave();
                                if (ok) _loadDayFromStore(d);
                              },
                            ),
                          );
                        }),
                        if (_daysVisible < kMaxDaysCount)
                          ActionChip(
                            label: Text('+ يوم ${_daysVisible + 1}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: pal.deep)),
                            onPressed: () {
                              setState(() {
                                _daysVisible = (_daysVisible + 1)
                                    .clamp(kDefaultDaysCount, kMaxDaysCount);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGoldDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text('تطبيق نفس الورد للكل',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12.5)),
                          onPressed: () => _applySameWirdToAll(c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.check_circle,
                            color: kGreen, size: 18),
                        label: const Text('الكل حاضر',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: kGreen)),
                        onPressed: () {
                          setState(() {
                            for (final st in sorted) {
                              _draftAttendance[st.id] = 'present';
                            }
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Students Batch List
            Expanded(
              child: sorted.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في الحلقة بعد'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                      itemCount: sorted.length,
                      itemBuilder: (_, idx) {
                        final st = sorted[idx];
                        final att = _draftAttendance[st.id] ?? 'none';
                        final tasmi = _draftTasmi[st.id];
                        final hasTasmi =
                            tasmi != null && tasmi.text.trim().isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${idx + 1}. ${st.name}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5),
                                      ),
                                    ),
                                    // Attendance 3-state quick pills
                                    _attPill(
                                      label: 'حاضر',
                                      color: kGreen,
                                      selected: att == 'present',
                                      onTap: () => setState(() {
                                        _draftAttendance[st.id] =
                                            att == 'present'
                                                ? 'none'
                                                : 'present';
                                        _dirty = true;
                                      }),
                                    ),
                                    const SizedBox(width: 4),
                                    _attPill(
                                      label: 'بعذر',
                                      color: kAmber,
                                      selected: att == 'excused',
                                      onTap: () => setState(() {
                                        _draftAttendance[st.id] =
                                            att == 'excused'
                                                ? 'none'
                                                : 'excused';
                                        _dirty = true;
                                      }),
                                    ),
                                    const SizedBox(width: 4),
                                    _attPill(
                                      label: 'غائب',
                                      color: kRed,
                                      selected: att == 'absent',
                                      onTap: () => setState(() {
                                        _draftAttendance[st.id] =
                                            att == 'absent' ? 'none' : 'absent';
                                        _dirty = true;
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final res = await showTasmiEditorSheet(
                                      context: context,
                                      title:
                                          'تسميع ${st.name} — اليوم $_selectedDay',
                                      initial: tasmi,
                                    );
                                    if (res == null) return;
                                    setState(() {
                                      _draftTasmi[st.id] =
                                          res.cleared ? null : res.entry;
                                      _dirty = true;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasTasmi
                                          ? (tasmi.isReview
                                              ? kGoldSoft
                                              : kBlueSoft)
                                          : Theme.of(context)
                                              .scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: hasTasmi
                                            ? (tasmi.isReview
                                                ? kGold
                                                : kBlueMain)
                                            : Colors.grey.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: hasTasmi
                                        ? Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: tasmi.isReview
                                                      ? kGoldDark
                                                      : kBlueMain,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  tasmi.typeLabel,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  tasmi.text,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12.5,
                                                      color: kNavy),
                                                ),
                                              ),
                                              Text(
                                                tasmi.grade,
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: tasmi.isReview
                                                        ? kGoldDark
                                                        : kBlueDeep),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('اضغط لتسجيل التسميع...',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                              Icon(Icons.edit_note,
                                                  size: 18, color: Colors.grey),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dirty ? kGreen : pal.main,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.check_circle),
              label: Text(
                _dirty
                    ? 'حفظ تعديلات اليوم $_selectedDay للجميع'
                    : 'تم حفظ اليوم $_selectedDay',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              onPressed: _saveAll,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attPill({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StudentSearchScreen())),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('إضافة طالب',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (resolved.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('📌 لا يوجد أبناء مثبّتون حالياً',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text(
                            'ابحث عن ابنك أو ابنتك واضغط زر التثبيت للوصول السريع.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kBlueMain,
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.search),
                          label: const Text('البحث عن طالب'),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StudentSearchScreen())),
                        ),
                      ],
                    ),
                  ),
                ),
              if (resolved.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔔 آخر التحديثات',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: kGoldDark)),
                        const SizedBox(height: 8),
                        ...resolved.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                  '${item.student.name}: ${appStore.latestActivitySummary(item.student)}',
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                    ),
                  ),
                ),
              ...resolved.map((item) {
                final pal = CirclePalette.forGender(item.circle.gender);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentProfileScreen(
                            circleId: item.circle.id,
                            studentId: item.student.id,
                            readOnly: true),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: pal.main, width: 6))),
                      child: ListTile(
                        title: Text(item.student.name,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${item.circle.name} • ⭐ ${item.student.points} نقطة'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.push_pin,
                                  size: 18, color: kGoldDark),
                              tooltip: 'إلغاء التثبيت',
                              onPressed: () => appStore.togglePin(
                                  item.circle.id, item.student.id),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 16, color: pal.main),
                          ],
                        ),
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
// 7. Student Search Screen (Passwordless Name Search + Pinning)
// ---------------------------------------------------------------------------
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});
  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
              if (normalizeArabic(s.name).contains(q) ||
                  normalizeArabic(c.name).contains(q)) {
                matches.add((circle: c, student: s));
              }
            }
          }
          matches.sort((a, b) => normalizeArabic(a.student.name)
              .compareTo(normalizeArabic(b.student.name)));
        }

        return Scaffold(
          appBar: AppBar(
              title: const Text('البحث عن طالب'),
              backgroundColor: kBlueDark,
              foregroundColor: Colors.white),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                                child: Text('🕒 عمليات البحث الأخيرة',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              ),
                            ...appStore.recentSearches.map((r) => Card(
                                  child: ListTile(
                                    title: Text(r['studentName'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
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
                      : matches.isEmpty
                          ? const Center(
                              child: Text('لا توجد نتائج مطابقة',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (_, i) {
                                final item = matches[i];
                                final pal =
                                    CirclePalette.forGender(item.circle.gender);
                                final pinned = appStore.isPinned(
                                    item.circle.id, item.student.id);
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: pal.soft,
                                      child: Icon(Icons.person,
                                          color: pal.main, size: 20),
                                    ),
                                    title: Text(item.student.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(item.circle.name),
                                    trailing: IconButton(
                                      icon: Icon(
                                          pinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          color:
                                              pinned ? kGoldDark : Colors.grey),
                                      onPressed: () => appStore.togglePin(
                                          item.circle.id, item.student.id),
                                    ),
                                    onTap: () {
                                      appStore.addRecent(
                                          item.circle.id,
                                          item.student.id,
                                          item.student.name,
                                          item.circle.name,
                                          item.circle.gender);
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
// 8. Student Profile Screen
//    - 2 Tabs in Student/Parent Mode: متابعة الطالب | رصيد النقاط وكشف الحساب (NO Market)
//    - 12 Days Default (+ Add Day up to 30)
//    - Direct Scannable Recitation Rows (حفظ جديد Blue / مراجعة Gold) + 114-Surah Picker
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
  int _studentTab = 0; // 0: Tracking, 1: Points Balance & Statement

  Future<void> _openTasmiDialog(
      CircleModel c, MonthRecord rec, int day, bool locked) async {
    final existing = rec.tasmi['$day'];
    if (locked) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('التسميع — اليوم $day',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existing != null && existing.text.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: existing.isReview ? kGoldDark : kBlueMain,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(existing.typeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Text(existing.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                Text('التقييم: ${existing.grade}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ] else
                const Text('لم يُسجل تسميع في هذا اليوم'),
              if (existing?.note.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('💬 ملاحظة لولي الأمر: ${existing!.note}'),
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

    final res = await showTasmiEditorSheet(
      context: context,
      title: 'تسجيل التسميع — اليوم $day',
      initial: existing,
    );
    if (res == null) return;
    rec.tasmi['$day'] = res.cleared ? null : res.entry;
    appStore.saveCircle(c.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final c = appStore.getCircle(widget.circleId);
        final s = appStore.getStudent(c, widget.studentId);
        if (c == null || s == null) {
          return const Scaffold(body: Center(child: Text('السجل غير موجود')));
        }
        final pal = CirclePalette.forGender(c.gender);

        final mKeys = s.months.keys.toList()..sort((a, b) => b.compareTo(a));
        final curKey =
            (_selectedMonthKey != null && s.months.containsKey(_selectedMonthKey))
                ? _selectedMonthKey!
                : s.activeMonthKey;
        final rec = s.months[curKey] ?? s.months[mKeys.first]!;
        final curIdx = mKeys.indexOf(rec.key);
        final prevRec = (curIdx >= 0 && curIdx + 1 < mKeys.length)
            ? s.months[mKeys[curIdx + 1]]
            : null;
        final an = AiAnalysis.compute(rec, prevRec);
        final canEdit = !widget.readOnly && !rec.archived;
        final daysCount = rec.daysCount.clamp(kDefaultDaysCount, kMaxDaysCount);
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
                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: Colors.white),
                  label: Text(pinned ? 'مثبّت' : 'تثبيت',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (widget.readOnly) ...[
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text('متابعة ${pal.studentWord}')),
                    ButtonSegment(
                        value: 1,
                        label: Text('⭐ رصيد النقاط (${s.points})')),
                  ],
                  selected: {_studentTab},
                  onSelectionChanged: (v) =>
                      setState(() => _studentTab = v.first),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.readOnly && _studentTab == 1)
                ..._buildPointsStatementTab(s)
              else
                ..._buildTrackingTab(
                    c, s, pal, mKeys, rec, an, canEdit, daysCount),
            ],
          ),
        );
      },
    );
  }

  // Student Points Tab: Balance + Statement ONLY (NO Rewards Market)
  List<Widget> _buildPointsStatementTab(StudentModel s) {
    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFFC7A87D), kGold, kGoldDark]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text('رصيد النقاط الحالي',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('⭐ ${s.points} نقطة',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text('📜 كشف حساب النقاط',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 8),
      if (s.pointsHistory.isEmpty)
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'لا توجد حركات نقاط مسجّلة في كشف الحساب بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        )
      else
        ...s.pointsHistory.map((h) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: h.delta >= 0
                      ? kGreen.withValues(alpha: 0.14)
                      : kRed.withValues(alpha: 0.14),
                  child: Icon(
                    h.delta >= 0 ? Icons.add_circle : Icons.remove_circle,
                    color: h.delta >= 0 ? kGreen : kRed,
                    size: 20,
                  ),
                ),
                title: Text(h.reason,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                subtitle: Text(h.date, style: const TextStyle(fontSize: 11.5)),
                trailing: Text(
                  '${h.delta >= 0 ? '+' : ''}${h.delta}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: h.delta >= 0 ? kGreen : kRed),
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
      if (c.announcement.trim().isNotEmpty) ...[
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Text('📢', style: TextStyle(fontSize: 18)),
            title: Text('إعلان ${c.name}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            subtitle: Text(c.announcement, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],

      // Month selector + Archive button
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: rec.key,
              items: mKeys
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text(
                            '${s.months[k]!.label}${s.months[k]!.archived ? ' (مؤرشف)' : ''}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonthKey = v),
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: pal.accentDark,
                  foregroundColor: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('📦 أرشفة الشهر الحالي'),
                    content: Text(
                        'هل تريد أرشفة شهر "${rec.label}" وفتح شهر جديد بـ 12 يوماً؟\nسيُعتمد هذا الشهر في حساب نجوم الشهر.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                        onPressed: () {
                          final nextM = rec.month == 12 ? 1 : rec.month + 1;
                          final nextY =
                              rec.month == 12 ? rec.year + 1 : rec.year;
                          final nk = monthKey(nextY, nextM);
                          s.months.forEach((_, mr) => mr.archived = true);
                          s.months[nk] ??= MonthRecord.empty(nextY, nextM);
                          s.months[nk]!.archived = false;
                          s.activeMonthKey = nk;
                          _selectedMonthKey = nk;
                          appStore.saveCircle(c.id);
                          Navigator.pop(dCtx);
                        },
                        child: const Text('تأكيد الأرشفة'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('📦 أرشفة'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),

      // Juz Progress Bar (0..30)
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
                  Text('📗 الحفظ: ${s.juzCount} / 30 جزءاً',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
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
              LinearProgressIndicator(
                  value: s.juzCount / 30,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: pal.main),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),

      // Badges
      if (an.badges.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: an.badges
              .map((b) => Chip(
                    backgroundColor: b.color,
                    label: Text('${b.icon} ${b.title}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
      ],

      // Attendance Grid (12 Days Default + Add Day up to 30)
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
                  Text('📅 الحضور والغياب ($daysCount يوماً)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${an.attendanceRate}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: pal.main)),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  _LegendDot(color: kGreen, label: 'حاضر'),
                  SizedBox(width: 12),
                  _LegendDot(color: kAmber, label: 'بعذر'),
                  SizedBox(width: 12),
                  _LegendDot(color: kRed, label: 'غائب'),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
                itemCount: daysCount,
                itemBuilder: (_, idx) {
                  final d = idx + 1;
                  final v = rec.attendance['$d'] ?? 'none';
                  final bg = v == 'present'
                      ? kGreen
                      : (v == 'excused'
                          ? kAmber
                          : (v == 'absent'
                              ? kRed
                              : Theme.of(context).scaffoldBackgroundColor));
                  final fg = v == 'none' ? Colors.grey : Colors.white;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: !canEdit
                        ? null
                        : () {
                            const order = [
                              'none',
                              'present',
                              'excused',
                              'absent'
                            ];
                            rec.attendance['$d'] =
                                order[(order.indexOf(v) + 1) % order.length];
                            appStore.saveCircle(c.id);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text('$d',
                              style: TextStyle(
                                  color: fg, fontWeight: FontWeight.w800))),
                    ),
                  );
                },
              ),
              if (canEdit && daysCount < kMaxDaysCount) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      rec.daysCount =
                          (daysCount + 1).clamp(kDefaultDaysCount, kMaxDaysCount);
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

      // Upgraded Recitation Card: Clear Directly Readable Rows (حفظ جديد Blue / مراجعة Gold)
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
                  Text('📖 سجل التسميع اليومي ($daysCount يوماً)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${an.tasmiCount} منجز',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: pal.main)),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  _LegendDot(color: kBlueMain, label: 'حفظ جديد'),
                  SizedBox(width: 14),
                  _LegendDot(color: kGoldDark, label: 'مراجعة'),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(daysCount, (idx) {
                final d = idx + 1;
                final t = rec.tasmi['$d'];
                final has = t != null && t.text.trim().isNotEmpty;
                final isRev = has && t.isReview;
                final typeColor = isRev ? kGoldDark : kBlueMain;
                final rowBg = has
                    ? (isRev
                        ? kGold.withValues(alpha: 0.11)
                        : kBlueMain.withValues(alpha: 0.09))
                    : Theme.of(context).scaffoldBackgroundColor;

                return Padding(
                  padding: EdgeInsets.only(bottom: idx < daysCount - 1 ? 8 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openTasmiDialog(c, rec, d, !canEdit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: rowBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: has
                              ? typeColor.withValues(alpha: 0.45)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: has
                                  ? typeColor
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$d',
                                style: TextStyle(
                                  color: has ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: has
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: typeColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              t.typeLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              t.grade,
                                              style: TextStyle(
                                                color: typeColor,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        t.text,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      if (t.note.trim().isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '💬 ${t.note}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    child: Text(
                                      canEdit
                                          ? 'لم يُسجل بعد — اضغط لإضافة التسميع'
                                          : 'لم يُسجل تسميع في هذا اليوم',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                          ),
                          if (canEdit)
                            Icon(Icons.edit_note,
                                size: 20,
                                color: has ? typeColor : Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (canEdit && daysCount < kMaxDaysCount) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      rec.daysCount =
                          (daysCount + 1).clamp(kDefaultDaysCount, kMaxDaysCount);
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
                  const Text('✨ التحليل الذكي للأداء',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Chip(
                      backgroundColor: an.badgeBg,
                      label: Text(an.level,
                          style: TextStyle(
                              color: an.badgeText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: pal.main, foregroundColor: Colors.white),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ التقرير الشهري'),
                  onPressed: () {
                    final report =
                        '📘 جمعية خير أمة\n${pal.studentWord}: ${s.name}\nالحلقة: ${c.name}\nالشهر: ${rec.label}\nالأجزاء: ${s.juzCount}/30\nالحضور: ${an.present} | بعذر: ${an.excused} | غياب: ${an.absent} (${an.attendanceRate}%)\nالتسميع: ${an.tasmiCount} | التقييم: ${an.overallScore}% (${an.level})';
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ التقرير الشهري')));
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
