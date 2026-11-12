CREATE TABLE academic_calendars (
    academic_year TEXT PRIMARY KEY,
    document JSONB NOT NULL,
    CONSTRAINT academic_calendars_document_object CHECK (jsonb_typeof(document) = 'object'),
    CONSTRAINT academic_calendars_year_matches CHECK (document->>'academic_year' = academic_year)
);

INSERT INTO academic_calendars (academic_year, document) VALUES
('2026-2027', $calendar$
{
  "academic_year": "2026-2027",
  "version": "2026-03-05.v1",
  "time_zone": "Asia/Shanghai",
  "source": {
    "url": "https://jwc.jlu.edu.cn/info/1067/12517.htm",
    "image_url": "https://jwc.jlu.edu.cn/__local/B/BD/D3/03BC2E94814535EB7712D3DE8C0_B62BED7C_211D6.png",
    "published_at": "2026-03-05"
  },
  "includes_makeup_day_rules": false,
  "notes": ["日期范围均含首尾日期。", "节日仅标记当日，不包含放假、补课或调休规则。", "新生军训及入学教育、开课日期单独标注，不改变全校教学起始日期。"],
  "terms": [
    {"id": "2026-2027-1", "name": "第一学期", "start_date": "2026-09-07", "end_date": "2027-01-03", "teaching_weeks": 17},
    {"id": "2026-2027-2", "name": "第二学期", "start_date": "2027-03-01", "end_date": "2027-06-20", "teaching_weeks": 16}
  ],
  "periods_source": {"url": "https://jwc.jlu.edu.cn/sksj.htm", "published_at": null, "effective_from_term": "2023-2024-2"},
  "periods": [
    {"number": 1, "start_time": "08:00", "end_time": "08:45"},
    {"number": 2, "start_time": "08:55", "end_time": "09:40"},
    {"number": 3, "start_time": "10:00", "end_time": "10:45"},
    {"number": 4, "start_time": "10:55", "end_time": "11:40"},
    {"number": 5, "start_time": "13:30", "end_time": "14:15"},
    {"number": 6, "start_time": "14:25", "end_time": "15:10"},
    {"number": 7, "start_time": "15:30", "end_time": "16:15"},
    {"number": 8, "start_time": "16:25", "end_time": "17:10"},
    {"number": 9, "start_time": "18:20", "end_time": "19:05"},
    {"number": 10, "start_time": "19:05", "end_time": "19:50"},
    {"number": 11, "start_time": "20:00", "end_time": "20:45"},
    {"number": 12, "start_time": "20:45", "end_time": "21:30"}
  ],
  "events": [
    {"id": "2026-2027-1-teaching", "title": "第一学期教学", "type": "teaching", "start_date": "2026-09-07", "end_date": "2027-01-03", "term_id": "2026-2027-1"},
    {"id": "2026-2027-1-exam", "title": "第一学期考试", "type": "exam", "start_date": "2027-01-04", "end_date": "2027-01-17", "term_id": "2026-2027-1"},
    {"id": "2026-2027-winter", "title": "寒假", "type": "winter_break", "start_date": "2027-01-18", "end_date": "2027-02-28", "term_id": "2026-2027-1"},
    {"id": "2026-2027-2-teaching", "title": "第二学期教学", "type": "teaching", "start_date": "2027-03-01", "end_date": "2027-06-20", "term_id": "2026-2027-2"},
    {"id": "2026-2027-2-exam", "title": "第二学期考试", "type": "exam", "start_date": "2027-06-21", "end_date": "2027-07-04", "term_id": "2026-2027-2"},
    {"id": "2026-2027-summer", "title": "暑假", "type": "summer_break", "start_date": "2027-07-05", "end_date": "2027-09-05", "term_id": "2026-2027-2"},
    {"id": "2026-2027-orientation", "title": "新生军训及入学教育", "type": "orientation", "start_date": "2026-09-04", "end_date": "2026-09-20", "term_id": "2026-2027-1"},
    {"id": "2026-2027-freshman-start", "title": "新生开课", "type": "freshman_teaching_start", "start_date": "2026-09-21", "end_date": "2026-09-21", "term_id": "2026-2027-1"},
    {"id": "2026-09-25-holiday", "title": "中秋节", "type": "holiday", "start_date": "2026-09-25", "end_date": "2026-09-25", "term_id": null},
    {"id": "2026-10-01-holiday", "title": "国庆节", "type": "holiday", "start_date": "2026-10-01", "end_date": "2026-10-01", "term_id": null},
    {"id": "2027-01-01-holiday", "title": "元旦", "type": "holiday", "start_date": "2027-01-01", "end_date": "2027-01-01", "term_id": null},
    {"id": "2027-02-06-holiday", "title": "春节", "type": "holiday", "start_date": "2027-02-06", "end_date": "2027-02-06", "term_id": null},
    {"id": "2027-04-05-holiday", "title": "清明节", "type": "holiday", "start_date": "2027-04-05", "end_date": "2027-04-05", "term_id": null},
    {"id": "2027-05-01-holiday", "title": "劳动节", "type": "holiday", "start_date": "2027-05-01", "end_date": "2027-05-01", "term_id": null},
    {"id": "2027-06-09-holiday", "title": "端午节", "type": "holiday", "start_date": "2027-06-09", "end_date": "2027-06-09", "term_id": null}
  ]
}
$calendar$::jsonb),
('2025-2026', $calendar$
{
  "academic_year": "2025-2026",
  "version": "2026-03-24.v1",
  "time_zone": "Asia/Shanghai",
  "source": {
    "url": "https://jwc.jlu.edu.cn/info/1067/12536.htm",
    "image_url": "https://jwc.jlu.edu.cn/__local/0/4E/4D/1D86AAA69DD1B80945BF444B259_D95897DD_3E35F.png",
    "published_at": "2026-03-24"
  },
  "includes_makeup_day_rules": false,
  "notes": ["日期范围均含首尾日期。", "节日仅标记当日，不包含放假、补课或调休规则。"],
  "terms": [
    {"id": "2025-2026-1", "name": "第一学期", "start_date": "2025-08-25", "end_date": "2026-01-04", "teaching_weeks": 19},
    {"id": "2025-2026-2", "name": "第二学期", "start_date": "2026-03-09", "end_date": "2026-06-28", "teaching_weeks": 16}
  ],
  "periods_source": {"url": "https://jwc.jlu.edu.cn/sksj.htm", "published_at": null, "effective_from_term": "2023-2024-2"},
  "periods": [
    {"number": 1, "start_time": "08:00", "end_time": "08:45"},
    {"number": 2, "start_time": "08:55", "end_time": "09:40"},
    {"number": 3, "start_time": "10:00", "end_time": "10:45"},
    {"number": 4, "start_time": "10:55", "end_time": "11:40"},
    {"number": 5, "start_time": "13:30", "end_time": "14:15"},
    {"number": 6, "start_time": "14:25", "end_time": "15:10"},
    {"number": 7, "start_time": "15:30", "end_time": "16:15"},
    {"number": 8, "start_time": "16:25", "end_time": "17:10"},
    {"number": 9, "start_time": "18:20", "end_time": "19:05"},
    {"number": 10, "start_time": "19:05", "end_time": "19:50"},
    {"number": 11, "start_time": "20:00", "end_time": "20:45"},
    {"number": 12, "start_time": "20:45", "end_time": "21:30"}
  ],
  "events": [
    {"id": "2025-2026-1-teaching", "title": "第一学期教学", "type": "teaching", "start_date": "2025-08-25", "end_date": "2026-01-04", "term_id": "2025-2026-1"},
    {"id": "2025-2026-1-exam", "title": "第一学期考试", "type": "exam", "start_date": "2026-01-05", "end_date": "2026-01-18", "term_id": "2025-2026-1"},
    {"id": "2025-2026-winter", "title": "寒假", "type": "winter_break", "start_date": "2026-01-19", "end_date": "2026-03-08", "term_id": "2025-2026-1"},
    {"id": "2025-2026-2-teaching", "title": "第二学期教学", "type": "teaching", "start_date": "2026-03-09", "end_date": "2026-06-28", "term_id": "2025-2026-2"},
    {"id": "2025-2026-2-exam", "title": "第二学期考试", "type": "exam", "start_date": "2026-06-29", "end_date": "2026-07-12", "term_id": "2025-2026-2"},
    {"id": "2025-2026-summer", "title": "暑假", "type": "summer_break", "start_date": "2026-07-13", "end_date": "2026-09-06", "term_id": "2025-2026-2"},
    {"id": "2025-10-01-holiday", "title": "国庆节", "type": "holiday", "start_date": "2025-10-01", "end_date": "2025-10-01", "term_id": null},
    {"id": "2025-10-06-holiday", "title": "中秋节", "type": "holiday", "start_date": "2025-10-06", "end_date": "2025-10-06", "term_id": null},
    {"id": "2026-01-01-holiday", "title": "元旦", "type": "holiday", "start_date": "2026-01-01", "end_date": "2026-01-01", "term_id": null},
    {"id": "2026-02-17-holiday", "title": "春节", "type": "holiday", "start_date": "2026-02-17", "end_date": "2026-02-17", "term_id": null},
    {"id": "2026-04-05-holiday", "title": "清明节", "type": "holiday", "start_date": "2026-04-05", "end_date": "2026-04-05", "term_id": null},
    {"id": "2026-05-01-holiday", "title": "劳动节", "type": "holiday", "start_date": "2026-05-01", "end_date": "2026-05-01", "term_id": null},
    {"id": "2026-06-19-holiday", "title": "端午节", "type": "holiday", "start_date": "2026-06-19", "end_date": "2026-06-19", "term_id": null}
  ]
}
$calendar$::jsonb);

UPDATE service_meta SET value = '6', updated_at = now() WHERE key = 'schema_version';
