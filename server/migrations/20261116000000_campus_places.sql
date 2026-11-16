CREATE TABLE campus_places (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    campus_id TEXT NOT NULL,
    campus_name TEXT NOT NULL,
    building_id TEXT NOT NULL,
    building_name TEXT NOT NULL,
    department TEXT NOT NULL,
    office_person TEXT,
    floor TEXT,
    room TEXT NOT NULL,
    description TEXT NOT NULL,
    source_url TEXT NOT NULL,
    source_updated_at TIMESTAMPTZ,
    observed_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO campus_places (
    id, name, campus_id, campus_name, building_id, building_name,
    department, office_person, floor, room, description,
    source_url, source_updated_at, observed_at
) VALUES
    (
        'jwc-nanling-teaching-office', '东区教务办公室教学运行办公点',
        'nanling', '南岭校区', 'nanling-yifu-education', '逸夫教育大楼',
        '本科生院东区教务办公室', '李阳', NULL, '908（2）室',
        '原来源：副科长，负责南岭校区学期课程安排、学生选课及教学资源调配。仅办公地点，不从908推断楼层或相邻A区。',
        'https://jwc.jlu.edu.cn/zzjg/ksjzz.htm', NULL, '2026-11-16T04:03:00Z'
    ),
    (
        'jwc-chaoyang-exams', '北区教务办公室考试管理科办公点',
        'chaoyang', '朝阳校区', 'chaoyang-source-canteen', '朝阳校区食堂（来源原名）',
        '本科生院北区教务办公室考试管理科', '刘渊泓', '四楼', '403室',
        '来源原文“朝阳校区食堂四楼403室”，负责本科考试、选课、外语四六级考试等；仅办公地点。',
        'https://jwc.jlu.edu.cn/zzjg/ksjzz.htm', NULL, '2026-11-16T04:03:00Z'
    ),
    (
        'jwc-heping-teaching', '西区教务办公室教务科办公点',
        'heping', '和平校区', 'heping-administration', '行政楼',
        '本科生院西区教务办公室教务科', '张强', '三楼', '315室',
        '负责校区日常教学运行、排课、选课、教室管理等；仅办公地点。',
        'https://jwc.jlu.edu.cn/zzjg/ksjzz.htm', NULL, '2026-11-16T04:03:00Z'
    ),
    (
        'finance-qianwei-south-c237', '财务处结算科科长办公点',
        'qianwei-south', '前卫南区', 'qianwei-dingxin', '鼎新楼C区',
        '财务处结算科', '孙村惠子', NULL, '237室',
        '来源写前卫南区鼎新楼C区237室；科室其他工作人员在C247，并非全科唯一办公点。',
        'https://cw.jlu.edu.cn/zzjg/ksjgzryzz/jsk.htm', NULL, '2026-11-16T04:03:00Z'
    );

UPDATE service_meta SET value = '13', updated_at = now() WHERE key = 'schema_version';
