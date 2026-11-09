# course-permission 离线接口结构

> 归档完成日期：2026-11-10（UTC+8）；11月9日开始整理。仅描述历史抓包，没有联网复测。类型标记不是真实字段值。

来源：`畅课问题1_Full.txt`；9,453,996 bytes；SHA-256 `cab2c3127262da864598a6e63083ed23e3f1f4d2671e00a1002d7f0dd315d297`。

原文件修改时间：2026-11-04T17:18:16.361516+08:00。服务器 Date 范围：['2026-11-04T17:17:46+08:00', '2026-11-04T17:17:57+08:00']。

共 152 条请求（含 CONNECT），保留业务请求 13 条，排除后台/静态/遥测等 139 条。

参数值、响应标量值和请求头值均未保留。JSON 结构合并所有已解析行；动态键归一化，空数组只证明本样本为空。完整顺序与逐请求时间见同名 JSON 的 timeline。

## 请求顺序

| 导出序号 | 服务器时间 UTC+8 | 请求 | HTTP | 响应类型 |
| --- | --- | --- | --- | --- |
| 20 | 2026-11-04T17:17:46+08:00 | `GET lnt.xmu.edu.cn/course/{courseId}/index` | 200 | html |
| 30 | 2026-11-04T17:17:48+08:00 | `POST lnt.xmu.edu.cn/api/course/{courseId}/entry/record` | 200 | json |
| 36 | 2026-11-04T17:17:49+08:00 | `GET lnt.xmu.edu.cn/api/orgs/{orgId}/lang-settings` | 200 | json |
| 43 | 2026-11-04T17:17:49+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/modules` | 200 | json |
| 48 | 2026-11-04T17:17:49+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/outline` | 200 | json |
| 55 | 2026-11-04T17:17:49+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/stats` | 200 | json |
| 59 | 2026-11-04T17:17:49+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/teaching-tasks` | 200 | json |
| 72 | 2026-11-04T17:17:53+08:00 | `GET lnt.xmu.edu.cn/course/{courseId}/learning-activity/full-screen` | 200 | html |
| 85 | 2026-11-04T17:17:54+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user/courses/ai-ability` | 200 | json |
| 90 | 2026-11-04T17:17:55+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}` | 200 | json |
| 103 | 2026-11-04T17:17:55+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user` | 200 | json |
| 106 | 2026-11-04T17:17:56+08:00 | `GET lnt.xmu.edu.cn/errors/no_permission` | 200 | html |
| 127 | 2026-11-04T17:17:57+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user/courses/ai-ability` | 200 | json |

## `GET lnt.xmu.edu.cn/course/{courseId}/index`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

HTML 输入字段名：`activity_teaching_model, added-role, all_day, announceAnswer, announceAnswerStatus, announceAnswerType, announceScore, announceScoreType, client_required, completion_criterion_value, copy_item_unable, copy_to_courses, course-target-type-[[$index]], days, default_options_layout, disableDevtool, disable_copy_paste, disable_right_click, eagle_eye, enable_anti_cheat, enable_exam_prerequisite, enable_invigilation, end_time, face_recognition, hasAlert, has_completion_criterion, instructor_score_percentage, inter_group_score_percentage, inter_review_incomplete_score_minus_percent, inter_score_end_time, inter_score_percentage, inter_score_start_time, intra_group_score_percentage, intra_review_incomplete_score_minus_percent, intra_rubric_visible_time, intra_score_end_time, intra_score_start_time, is_fullscreen_mode, is_leaving_window_constrained, is_leaving_window_timeout, leaving_window_limit, leaving_window_timeout, limit_answer_on_signle_client, limit_short_answer_upload, limit_time, location, lock_screen, monitor, name, never_expire, online_video_completeness_score_percentage, page, percentage, performance_score_percentage, pieces_cnt, repeat_end_date, repeat_frequency, rollcall_score_percentage, rubric_visible_time, scope, score, score_percentage, scored, select_subjects_randomly, sendNtf, send_alert_email, send_email, show_intra_rubric, show_rubric, shuffle_options_randomly, shuffle_subjects_randomly, startBulletinType, start_time, subject_index_type, submitTimes, submit_by_group, submit_times, target-type, title, using_phase`。

## `POST lnt.xmu.edu.cn/api/course/{courseId}/entry/record`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
```

## `GET lnt.xmu.edu.cn/api/orgs/{orgId}/lang-settings`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.lang_settings: array; observed lengths=5
$.lang_settings[]: string
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/modules`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.modules: array; observed lengths=11
$.modules[]: object
$.modules[].class_hours: integer
$.modules[].id: integer
$.modules[].imported_from: null
$.modules[].is_hidden: integer
$.modules[].lecturer_id: integer
$.modules[].lecturer_info: null
$.modules[].lesson_time_id: integer
$.modules[].name: string
$.modules[].notice_before_days: integer
$.modules[].sort: integer
$.modules[].sticky_time: null
$.modules[].syllabuses: array; observed lengths=0,1,4
$.modules[].syllabuses[]: object
$.modules[].syllabuses[].comments: null
$.modules[].syllabuses[].date: null
$.modules[].syllabuses[].id: integer
$.modules[].syllabuses[].imported_from: null
$.modules[].syllabuses[].module_id: integer
$.modules[].syllabuses[].objective: null
$.modules[].syllabuses[].sort: integer
$.modules[].syllabuses[].summary: string
$.modules[].syllabuses[].syllabus_id: integer
$.modules[].syllabuses[].teaching_type: string
$.modules[].syllabuses[].teaching_week: null
$.modules[].teaching_week_ids: null
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/outline`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.comment_chinese: object
$.comment_chinese.description: string
$.comment_chinese.id: integer
$.comment_chinese.key: string
$.comment_chinese.title: string
$.comment_chinese.uploads: array; observed lengths=0
$.common_fields: array; observed lengths=13
$.common_fields[]: object
$.common_fields[].description: string
$.common_fields[].id: integer
$.common_fields[].key: string
$.common_fields[].title: string
$.custom_fields: array; observed lengths=0
$.end_date: null
$.external_url: null
$.id: integer
$.is_closed: boolean
$.is_imported: boolean
$.status: string
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/stats`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.activity_count: integer
$.knowledge_node_count: integer
$.module_count: integer
$.subject_lib_count: integer
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/teaching-tasks`

出现 1 次；HTTP：`200`。

查询参数名：`conditions, page, page_size`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

请求 JSON / JSON 内嵌参数结构：

```text
$query.conditions: object
```

响应 JSON 结构：

```text
$: object
$.end: integer
$.items: array; observed lengths=5
$.items[]: object
$.items[].end_time: string
$.items[].id: integer
$.items[].module: string
$.items[].not_scored_num: integer
$.items[].percentage: string
$.items[].scored_num: integer
$.items[].start_time: string
$.items[].submitted_num: integer
$.items[].title: string
$.items[].total_num: integer
$.items[].type: string
$.page: integer
$.page_size: integer
$.pages: integer
$.start: integer
$.total: integer
```

## `GET lnt.xmu.edu.cn/course/{courseId}/learning-activity/full-screen`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

HTML 输入字段名：`activity_teaching_model, allow_download, announceAnswer, announceAnswerStatus, announceAnswerType, announceScore, announceScoreType, announce_answer_time, announce_score_time, answer_limit, client_required, closed_time, completion_criterion_value, copy_item_unable, default_options_layout, disableDevtool, disable_copy_paste, disable_right_click, each_praise_score, each_reply_score, eagle_eye, enable_anti_cheat, enable_exam_prerequisite, enable_invigilation, end_date, end_time, face_recognition, has_completion_criterion, inputStatus, instructor_score_percentage, inter_group_score_percentage, inter_review_incomplete_score_minus_percent, inter_score_end_time, inter_score_percentage, inter_score_start_time, intra_group_score_percentage, intra_review_incomplete_score_minus_percent, intra_rubric_visible_time, intra_score_end_time, intra_score_start_time, is_anonymous, is_fullscreen_mode, is_leaving_window_constrained, is_leaving_window_timeout, keyword, learning_design_id, leaving_window_limit, leaving_window_timeout, limit_answer_on_signle_client, limit_short_answer_upload, limit_time, link, lock_screen, max_praise_score, max_reply_score, monitor, name, not-public-control, page, pauseWhenLeavingWindow, pieces_cnt, public-control, referrer_id, repeat_answer, rubric_visible_time, score, scored, select_subjects_randomly, set_praise_rulers, set_reply_rulers, show_intra_rubric, show_rubric, shuffle_options_randomly, shuffle_subjects_randomly, start_date, start_time, subject-by-subject-control, subject-layout, subject-option-sort, subject-sort, subject-type, subject_index_type, submitTimes, submit_by_group, submit_times, title, upload, use_rubric, using_phase, whole-control`。

## `GET lnt.xmu.edu.cn/api/air-credit/user/courses/ai-ability`

出现 2 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

响应 JSON 结构：

```text
$: object
$.has_any_course_ai_ability: boolean
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}`

出现 1 次；HTTP：`200`。

查询参数名：`fields`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.academic_year: object
$.academic_year.code: string
$.academic_year.id: integer
$.academic_year.name: string
$.academic_year.sort: integer
$.allow_admin_update_basic_info: boolean
$.allow_edit_knowledge_base: boolean
$.allow_update_basic_info: boolean
$.allowed_to_invite_assistant: boolean
$.allowed_to_invite_student: boolean
$.allowed_to_join_course: boolean
$.archived: boolean
$.audit_status: string
$.auto_archive_course_date: string
$.classroom_schedule: null
$.compulsory: boolean
$.course_attributes: object
$.course_attributes.audience_type: integer
$.course_attributes.data: object
$.course_attributes.data.course_outline: object
$.course_attributes.data.course_outline.KCDM: string
$.course_attributes.data.course_outline.KCKX: null
$.course_attributes.data.course_outline.KCZ: null
$.course_attributes.data.course_outline.LLJXXS: string
$.course_attributes.data.course_outline.SJJXXS: string
$.course_attributes.data.course_outline.SYJXXS: string
$.course_attributes.data.course_outline.SYZY: null
$.course_attributes.data.course_outline.XXKC: string
$.course_attributes.data.course_outline.YWLBDM: string
$.course_attributes.data.course_outline.ZXS: string
$.course_attributes.data.has_score_item_group: boolean
$.course_attributes.education_type: integer
$.course_attributes.practice_hours: string
$.course_attributes.student_count: integer
$.course_attributes.teaching_class_name: string
$.course_code: string
$.course_type: integer
$.cover: string
$.credit: string
$.credit_state: object
$.credit_state.credit_remaining: integer
$.credit_state.status: string
$.department: object
$.department.code: string
$.department.id: integer
$.department.name: string
$.display_name: string
$.end_date: null
$.grade: null
$.has_ai_ability: boolean
$.id: integer
$.imported_from: string
$.instructors: array; observed lengths=1
$.instructors[]: object
$.instructors[].avatar_big_url: string
$.instructors[].avatar_small_url: string
$.instructors[].email: null
$.instructors[].id: integer
$.instructors[].name: string
$.instructors[].portfolio_url: null
$.instructors[].user_no: string
$.is_blocked: null
$.klass: null
$.knowledge_graph_publish_type: string
$.learning_mode: string
$.name: string
$.org: object
$.org.is_enterprise_or_organization: boolean
$.org.is_transfer_arrears: boolean
$.problem_graph_publish_type: string
$.public_scope: string
$.score_published: boolean
$.second_name: null
$.semester: object
$.semester.code: string
$.semester.id: integer
$.semester.name: string
$.semester.real_name: string
$.semester.sort: integer
$.show_archive_course_tips: boolean
$.start_date: string
$.students_count: integer
$.subject_code: string
$.syllabus_enabled: boolean
$.teaching_mode: string
$.url: string
```

## `GET lnt.xmu.edu.cn/api/air-credit/user`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.credit_state: null
$.is_low_air_credit: boolean
$.user_id: integer
$.user_name: string
$.user_no: string
```

## `GET lnt.xmu.edu.cn/errors/no_permission`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

HTML 输入字段名：`all_day, days, end_time, hasAlert, location, repeat_end_date, repeat_frequency, scope, score, sendNtf, send_alert_email, start_time, title`。
