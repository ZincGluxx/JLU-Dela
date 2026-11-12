import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/teaching/jlu_timetable_parser.dart';

Map<String, Object?> courseFixture() => <String, Object?>{
  'KBID': 'test-course',
  'JXBID': 'test-class',
  'KCH': 'TEST001',
  'KCM': '示例课程',
  'SKJS': '教师甲/test-id,教师乙/other-id',
  'JASMC': '示例教室',
  'SKXQ': '1',
  'KSJC': '1',
  'JSJC': '2',
  'SKZC': '1111',
  'XF': '2',
};

List<Map<String, Object?>> periodsFixture() => <Map<String, Object?>>[
  {'DM': '1', 'KSSJ': '09:10', 'JSSJ': '09:55', 'SFSY': '1'},
  {'DM': '2', 'KSSJ': '10:05', 'JSSJ': '10:50', 'SFSY': '1'},
  {'DM': '3', 'KSSJ': '11:00', 'JSSJ': '11:45', 'SFSY': '1'},
];

Map<String, Object?> fixture() => <String, Object?>{
  'courses': <Object?>[courseFixture()],
  'periods': periodsFixture(),
  'calendar': <Object?>[
    <String, Object?>{'XQKSRQ': '2026-09-14 00:00:00', 'ZZC': '20'},
  ],
  'changes': <Object?>[],
  'unscheduled': <Object?>[],
};

JluTimetable normalize(Map<String, Object?> input) => normalizeJluTimetable(
  courses: input['courses'],
  periods: input['periods'],
  calendar: input['calendar'],
  changes: input['changes'],
  unscheduled: input['unscheduled'],
);

Matcher throwsJluParse(String message) => throwsA(
  isA<JluParseException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  group('EMAP response', () {
    test(
      'accepts an empty timetable but rejects missing and truncated data',
      () {
        expect(
          parseEmapRows(<String, Object?>{
            'code': '0',
            'datas': <String, Object?>{
              'cxxszhxqkb': <String, Object?>{
                'rows': <Object?>[],
                'totalSize': 0,
              },
            },
          }, 'cxxszhxqkb'),
          isEmpty,
        );
        expect(
          () => parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{},
          }, 'cxxszhxqkb'),
          throwsJluParse('缺少'),
        );
        expect(
          () => parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{
              'cxxszhxqkb': <String, Object?>{
                'rows': <Object?>[],
                'totalSize': 3,
              },
            },
          }, 'cxxszhxqkb'),
          throwsJluParse('不完整'),
        );
      },
    );

    test(
      'accepts the unpaginated unknown-total response and checks page size',
      () {
        final course = courseFixture();
        expect(
          parseEmapRows(<String, Object?>{
            'code': '0',
            'datas': <String, Object?>{
              'cxxszhxqkb': <String, Object?>{
                'rows': <Object?>[course],
                'totalSize': -1,
                'pageSize': 0,
                'pageNumber': 0,
              },
            },
          }, 'cxxszhxqkb'),
          <Object?>[course],
        );
        expect(
          parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{
              'jc': <String, Object?>{
                'rows': periodsFixture(),
                'totalSize': -1,
              },
            },
          }, 'jc'),
          periodsFixture(),
        );
        expect(
          () => parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{
              'jc': <String, Object?>{
                'rows': periodsFixture(),
                'totalSize': -2,
              },
            },
          }, 'jc'),
          throwsJluParse('缺少'),
        );
        expect(
          () => parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{
              'jc': <String, Object?>{
                'rows': periodsFixture(),
                'totalSize': -1,
                'pageSize': 3,
              },
            },
          }, 'jc'),
          throwsJluParse('分页'),
        );
        expect(
          () => parseEmapRows(<String, Object?>{
            'datas': <String, Object?>{
              'jc': <String, Object?>{'totalSize': -1},
            },
          }, 'jc'),
          throwsJluParse('缺少'),
        );
      },
    );

    test('rejects an error code envelope', () {
      expect(
        () => parseEmapRows(<String, Object?>{
          'code': 500,
          'datas': <String, Object?>{},
        }, 'jc'),
        throwsJluParse('响应结构'),
      );
    });
  });

  group('semester', () {
    test('accepts the school semester code and rejects other shapes', () {
      expect(
        parseCurrentJluSemester(<Object?>[
          <String, Object?>{'DM': '2026-2027-1'},
        ]),
        '2026-2027-1',
      );
      expect(
        () => parseCurrentJluSemester(<Object?>[
          <String, Object?>{'DM': '2026-2027-4'},
        ]),
        throwsJluParse('当前学期'),
      );
      expect(
        () => parseCurrentJluSemester(<Object?>[]),
        throwsJluParse('当前学期'),
      );
    });
  });

  group('teaching weeks', () {
    test('expands the SKZC bitmask', () {
      expect(jluWeekNumbers('00001'), <int>[5]);
      expect(jluWeekNumbers('10101'), <int>[1, 3, 5]);
      expect(() => jluWeekNumbers('1-5'), throwsJluParse('格式'));
      expect(() => jluWeekNumbers(''), throwsJluParse('格式'));
      expect(() => jluWeekNumbers('1'.padRight(65, '1')), throwsJluParse('格式'));
    });

    test('parses text weeks with parity and calendar bounds', () {
      expect(parseJluWeekText('1-6,9周(单)', totalWeeks: 20), <int>[1, 3, 5, 9]);
      expect(parseJluWeekText('1-16周（双）', totalWeeks: 20), <int>[
        2,
        4,
        6,
        8,
        10,
        12,
        14,
        16,
      ]);
      expect(
        () => parseJluWeekText('1-21', totalWeeks: 20),
        throwsJluParse('总周数'),
      );
      expect(
        () => parseJluWeekText('5-1', totalWeeks: 20),
        throwsJluParse('教学周'),
      );
      expect(
        () => parseJluWeekText('2-2周(单)', totalWeeks: 20),
        throwsJluParse('没有选中'),
      );
      expect(() => parseJluWeekText('', totalWeeks: 20), throwsJluParse('教学周'));
      expect(() => parseJluWeekText('1', totalWeeks: 0), throwsJluParse('总周数'));
    });

    test('selects the bitmask first and falls back to text', () {
      expect(jluWeekSelector('10101'), <int>[1, 3, 5]);
      expect(jluWeekSelector('1-2周(单)', totalWeeks: 8), <int>[1]);
      expect(
        () => jluWeekSelector('10101', totalWeeks: 4),
        throwsJluParse('总周数'),
      );
      expect(
        () => jluWeekSelector('1-2', totalWeeks: null),
        throwsJluParse('总周数'),
      );
    });
  });

  group('normalizeJluTimetable', () {
    test('uses the week mask, calendar and section times', () {
      final input = fixture();
      (input['courses']! as List<Object?>)[0] = <String, Object?>{
        ...courseFixture(),
        'SKZC': '10101',
      };
      final result = normalize(input);
      expect(result.semesterStart, '2026-09-14');
      expect(result.totalWeeks, 20);
      expect(result.warnings, isEmpty);
      expect(result.lessons, hasLength(1));
      final lesson = result.lessons.single;
      expect(lesson.courseName, '示例课程');
      expect(lesson.kbId, 'test-course');
      expect(lesson.teacher, '教师甲、教师乙');
      expect(lesson.weekNumbers, <int>[1, 3, 5]);
      expect(lesson.weeksText, '1、3、5周');
      expect(lesson.periodsText, '1–2节');
      expect(lesson.startMinute, 550);
      expect(lesson.endMinute, 650);
      expect(lesson.credits, 2);
      expect(lesson.sourceId, isNot(contains('test-id')));
    });

    test(
      'applies a reschedule and a cancellation without the original occurrence',
      () {
        final input = fixture();
        input['changes'] = <Object?>[
          <String, Object?>{'KBID': 'test-course', 'SKZC': '0001'},
          <String, Object?>{
            'KBID': 'test-course',
            'SKZC': '0100',
            'XSKZC': '0010',
            'XSKXQ': '3',
            'XKSJC': '3',
            'XJSJC': '3',
            'XJASMC': '新教室',
          },
        ];
        final result = normalize(input);
        expect(result.lessons, hasLength(2));
        expect(result.lessons.first.weekNumbers, <int>[1, 3]);
        expect(result.lessons.last.weekday, 3);
        expect(result.lessons.last.weekNumbers, <int>[3]);
        expect(result.lessons.last.classroom, '新教室');
        expect(result.lessons.last.startMinute, 660);
        expect(result.lessons.last.endMinute, 705);
        expect(result.lessons.last.note, '教务调课');
      },
    );

    test(
      'reuses an adjusted occurrence that already exists in the timetable',
      () {
        final input = fixture();
        (input['courses']! as List<Object?>).add(<String, Object?>{
          ...courseFixture(),
          'SKXQ': '3',
          'SKZC': '0010',
          'KSJC': '3',
          'JSJC': '3',
        });
        input['changes'] = <Object?>[
          <String, Object?>{
            'KBID': 'test-course',
            'SKZC': '0100',
            'XSKZC': '0010',
            'XSKXQ': '3',
            'XKSJC': '3',
            'XJSJC': '3',
          },
        ];
        final result = normalize(input);
        expect(result.lessons, hasLength(2));
        expect(
          result.lessons.map((lesson) => lesson.sourceId).toSet(),
          hasLength(2),
        );
      },
    );

    test(
      'rejects an invalid calendar, unknown fields and ambiguous campus times',
      () {
        final invalidCalendar = fixture();
        invalidCalendar['calendar'] = <Object?>[
          <String, Object?>{'XQKSRQ': '2026-02-30'},
        ];
        expect(() => normalize(invalidCalendar), throwsJluParse('开学日期'));

        final missingFields = fixture();
        missingFields['courses'] = <Object?>[
          <String, Object?>{'KCM': '缺少时间'},
        ];
        expect(() => normalize(missingFields), throwsJluParse('字段'));

        final ambiguousCampus = fixture();
        ambiguousCampus['periods'] = <Object?>[
          for (final row in periodsFixture())
            <String, Object?>{...row, 'XXXQ': 'first-campus'},
          <String, Object?>{
            'DM': '1',
            'KSSJ': '08:00',
            'JSSJ': '08:45',
            'SFSY': '1',
            'XXXQ': 'other-campus',
          },
        ];
        expect(() => normalize(ambiguousCampus), throwsJluParse('校区节次'));

        final incompleteChange = fixture();
        incompleteChange['changes'] = <Object?>[
          <String, Object?>{
            'KBID': 'test-course',
            'SKZC': '0100',
            'XSKXQ': '3',
          },
        ];
        expect(() => normalize(incompleteChange), throwsJluParse('新时间'));
      },
    );

    test('selects the matching campus and accepts compact clock values', () {
      final input = fixture();
      input['courses'] = <Object?>[
        <String, Object?>{...courseFixture(), 'XXXQDM': 'A'},
      ];
      input['periods'] = <Object?>[
        for (final row in periodsFixture())
          <String, Object?>{...row, 'XXXQ': 'A'},
        <String, Object?>{
          'DM': '1',
          'KSSJ': '800',
          'JSSJ': '845',
          'SFSY': '1',
          'XXXQ': 'B',
        },
      ];
      expect(normalize(input).lessons.single.startMinute, 550);
    });

    test('warns about unplaced courses and unmatched changes', () {
      final input = fixture();
      input['unscheduled'] = <Object?>[
        <String, Object?>{'KCM': '未排课示例'},
      ];
      input['changes'] = <Object?>[
        <String, Object?>{'KBID': 'other', 'SKZC': '0100'},
      ];
      final result = normalize(input);
      expect(result.warnings, hasLength(2));
      expect(result.warnings, contains(contains('未排定时间')));
      expect(result.warnings, contains(contains('未匹配到原课程')));
    });

    test(
      'parses text week syntax when the school sends it instead of a mask',
      () {
        final input = fixture();
        (input['courses']! as List<Object?>)[0] = <String, Object?>{
          ...courseFixture(),
          'SKZC': '1-4周(单)',
        };
        expect(normalize(input).lessons.single.weekNumbers, <int>[1, 3]);
      },
    );

    test('rejects mask weeks beyond the calendar total', () {
      final input = fixture();
      (input['courses']! as List<Object?>)[0] = <String, Object?>{
        ...courseFixture(),
        'SKZC': '1'.padRight(21, '1'),
      };
      expect(() => normalize(input), throwsJluParse('总周数'));
    });

    test('returns an explicit failure for a missing or invalid calendar', () {
      final missing = fixture();
      missing['calendar'] = <Object?>[];
      expect(() => normalize(missing), throwsJluParse('开学日期'));

      final invalidTime = fixture();
      invalidTime['periods'] = <Object?>[
        <String, Object?>{
          'DM': '1',
          'KSSJ': '25:00',
          'JSSJ': '09:55',
          'SFSY': '1',
        },
      ];
      expect(() => normalize(invalidTime), throwsJluParse('节次时间'));
    });

    test('keeps an empty timetable distinct from a failed parse', () {
      final input = fixture();
      input['courses'] = <Object?>[];
      final result = normalize(input);
      expect(result.lessons, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.semesterStart, '2026-09-14');
    });
  });
}
