# final-grades 离线接口结构

> 归档完成日期：2026-11-10（UTC+8）；11月9日开始整理。仅描述历史抓包，没有联网复测。类型标记不是真实字段值。

来源：`看成绩.txt`；3,872,482 bytes；SHA-256 `4482e2633d15fe16a6525830c20c052c68c3854d87e55a9b47ecb0547d0bd908`。

原文件修改时间：2026-11-05T20:26:00.593657+08:00。服务器 Date 范围：['2026-11-05T20:25:32+08:00', '2026-11-05T20:25:39+08:00']。

共 45 条请求（含 CONNECT），保留业务请求 32 条，排除后台/静态/遥测等 13 条。

参数值、响应标量值和请求头值均未保留。JSON 结构合并所有已解析行；动态键归一化，空数组只证明本样本为空。完整顺序与逐请求时间见同名 JSON 的 timeline。

## 请求顺序

| 导出序号 | 服务器时间 UTC+8 | 请求 | HTTP | 响应类型 |
| --- | --- | --- | --- | --- |
| 1 | 2026-11-05T20:25:32+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/sync-status` | 200 | json |
| 5 | 2026-11-05T20:25:34+08:00 | `GET lnt.xmu.edu.cn/course/{courseId}/learning-activity/full-screen` | 200 | html |
| 11 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user/courses/ai-ability` | 200 | json |
| 14 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}` | 200 | json |
| 15 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/modules` | 200 | json |
| 16 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/activity-publish-setting` | 200 | json |
| 17 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/activities` | 200 | json |
| 18 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/exams` | 200 | json |
| 19 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/courses/{courseId}/classroom-list` | 200 | json |
| 20 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/rubrics` | 200 | json |
| 21 | 2026-11-05T20:25:36+08:00 | `GET lnt.xmu.edu.cn/api/rubrics/template` | 200 | json |
| 24 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user` | 200 | json |
| 25 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user` | 200 | json |
| 26 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/subject-libs` | 200 | json |
| 27 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/subject-libs` | 200 | json |
| 28 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/activities/{activityId}` | 200 | json |
| 29 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/activity-reads-for-user` | 200 | json |
| 30 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/homework/duplicate-lib` | 200 | json |
| 32 | 2026-11-05T20:25:37+08:00 | `POST lnt.xmu.edu.cn/api/course/activities-read/{id}` | 201 | json |
| 33 | 2026-11-05T20:25:37+08:00 | `GET lnt.xmu.edu.cn/api/uploads/{uploadId}/in-rich-content` | 403 | json |
| 34 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/student-submissions` | 200 | json |
| 35 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/students` | 200 | json |
| 36 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/activities/{activityId}/homework-scores` | 200 | json |
| 37 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/make-up-records` | 200 | json |
| 38 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/resubmit-records` | 200 | json |
| 39 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/redo-map` | 200 | json |
| 40 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/zip-status/homework-zip/{activityId}` | 200 | json |
| 41 | 2026-11-05T20:25:38+08:00 | `GET lnt.xmu.edu.cn/api/course/{courseId}/homework/duplicate-lib` | 200 | json |
| 42 | 2026-11-05T20:25:39+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/duplicate-detect/task` | 200 | json |
| 43 | 2026-11-05T20:25:39+08:00 | `GET lnt.xmu.edu.cn/api/homework/{activityId}/duplicate-detect/rate` | 200 | json |
| 44 | 2026-11-05T20:25:39+08:00 | `GET lnt.xmu.edu.cn/api/orgs/{orgId}/departments` | 200 | json |
| 45 | 2026-11-05T20:25:39+08:00 | `GET lnt.xmu.edu.cn/api/air-credit/user` | 200 | json |

## `GET lnt.xmu.edu.cn/api/course/{courseId}/sync-status`

出现 1 次；HTTP：`200`。

查询参数名：`no-loading-animation, status_key`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.course_id: integer
$.status: null
```

## `GET lnt.xmu.edu.cn/course/{courseId}/learning-activity/full-screen`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

HTML 输入字段名：`activity_teaching_model, allow_download, announceAnswer, announceAnswerStatus, announceAnswerType, announceScore, announceScoreType, announce_answer_time, announce_score_time, answer_limit, client_required, closed_time, completion_criterion_value, copy_item_unable, default_options_layout, disableDevtool, disable_copy_paste, disable_right_click, each_praise_score, each_reply_score, eagle_eye, enable_anti_cheat, enable_exam_prerequisite, enable_invigilation, end_date, end_time, face_recognition, has_completion_criterion, inputStatus, instructor_score_percentage, inter_group_score_percentage, inter_review_incomplete_score_minus_percent, inter_score_end_time, inter_score_percentage, inter_score_start_time, intra_group_score_percentage, intra_review_incomplete_score_minus_percent, intra_rubric_visible_time, intra_score_end_time, intra_score_start_time, is_anonymous, is_fullscreen_mode, is_leaving_window_constrained, is_leaving_window_timeout, keyword, learning_design_id, leaving_window_limit, leaving_window_timeout, limit_answer_on_signle_client, limit_short_answer_upload, limit_time, link, lock_screen, max_praise_score, max_reply_score, monitor, name, not-public-control, page, pauseWhenLeavingWindow, pieces_cnt, public-control, referrer_id, repeat_answer, rubric_visible_time, score, scored, select_subjects_randomly, set_praise_rulers, set_reply_rulers, show_intra_rubric, show_rubric, shuffle_options_randomly, shuffle_subjects_randomly, start_date, start_time, subject-by-subject-control, subject-layout, subject-option-sort, subject-sort, subject-type, subject_index_type, submitTimes, submit_by_group, submit_times, title, upload, use_rubric, using_phase, whole-control`。

## `GET lnt.xmu.edu.cn/api/air-credit/user/courses/ai-ability`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

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

## `GET lnt.xmu.edu.cn/api/course/{courseId}/activity-publish-setting`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.exam: string
$.forum: string
$.homework: string
$.others: string
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/activities`

出现 1 次；HTTP：`200`。

查询参数名：`sub_course_id`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.activities: array; observed lengths=47
$.activities[]: object
$.activities[].announce_answer_and_explanation: boolean
$.activities[].assign_group_ids: array; observed lengths=0
$.activities[].assign_student_ids: array; observed lengths=0
$.activities[].average_score: number
$.activities[].can_show_score: boolean
$.activities[].completion_criterion: string
$.activities[].completion_criterion_key: string
$.activities[].completion_criterion_value: string
$.activities[].course_id: integer
$.activities[].created_at: string
$.activities[].data: object
$.activities[].data.ai_generate_contents: boolean
$.activities[].data.allow_download: boolean
$.activities[].data.allow_forward_seeking: boolean
$.activities[].data.allow_retract: boolean
$.activities[].data.announce_answer_status: string
$.activities[].data.announce_score_time: null
$.activities[].data.announce_score_type: integer
$.activities[].data.description: string
$.activities[].data.has_assign_target: boolean
$.activities[].data.homework_score_percentage: object
$.activities[].data.homework_score_percentage.instructor_score_percentage: string
$.activities[].data.homework_type: string
$.activities[].data.inter_review_incomplete_score_minus: boolean
$.activities[].data.inter_review_incomplete_score_minus_percent: null
$.activities[].data.intra_review_incomplete_score_minus: boolean
$.activities[].data.intra_review_incomplete_score_minus_percent: null
$.activities[].data.is_announce_mark: boolean
$.activities[].data.link: string
$.activities[].data.mode: string
$.activities[].data.other_resources: array; observed lengths=0
$.activities[].data.pause_when_leaving_window: boolean
$.activities[].data.publish_count: integer
$.activities[].data.publish_time: null | string
$.activities[].data.reference_answer: string
$.activities[].data.score_percentage: string
$.activities[].data.score_rule: string
$.activities[].data.show_intra_rubric: boolean
$.activities[].data.show_rubric: boolean
$.activities[].data.submit_times: null
$.activities[].data.teaching_method: integer
$.activities[].data.week: integer
$.activities[].enable_edit: boolean
$.activities[].end_time: null | string
$.activities[].forum_count: integer
$.activities[].group_set_id: integer
$.activities[].group_set_name: string
$.activities[].has_assign_group: boolean
$.activities[].has_assign_student: boolean
$.activities[].has_score_count: integer
$.activities[].highest_score: integer | number
$.activities[].id: integer
$.activities[].imported_from: null | string
$.activities[].imported_track_id: null | string
$.activities[].inter_review_named: null
$.activities[].inter_score_map: object
$.activities[].inter_score_map.end_time: null
$.activities[].inter_score_map.id: integer
$.activities[].inter_score_map.is_closed: null
$.activities[].inter_score_map.is_started: null
$.activities[].inter_score_map.pieces_cnt: integer
$.activities[].inter_score_map.start_time: null
$.activities[].intra_rubric_id: integer
$.activities[].intra_rubric_instance: object
$.activities[].intra_rubric_instance.conditions: null
$.activities[].intra_rubric_instance.id: integer
$.activities[].intra_rubric_instance.name: null
$.activities[].intra_rubric_instance.rubric: object
$.activities[].intra_rubric_instance.rubric.conditions: null
$.activities[].intra_rubric_instance.rubric.created_at: null
$.activities[].intra_rubric_instance.rubric.created_by: object
$.activities[].intra_rubric_instance.rubric.created_by.id: integer
$.activities[].intra_rubric_instance.rubric.created_by.name: null
$.activities[].intra_rubric_instance.rubric.engage_number: integer
$.activities[].intra_rubric_instance.rubric.group_id: null
$.activities[].intra_rubric_instance.rubric.group_name: null
$.activities[].intra_rubric_instance.rubric.id: integer
$.activities[].intra_rubric_instance.rubric.is_shared_rubric: boolean
$.activities[].intra_rubric_instance.rubric.name: null
$.activities[].intra_rubric_instance.rubric.updated_at: null
$.activities[].intra_rubric_instance_id: integer
$.activities[].intra_score_map: object
$.activities[].intra_score_map.end_time: null
$.activities[].intra_score_map.id: integer
$.activities[].intra_score_map.is_closed: null
$.activities[].intra_score_map.start_time: null
$.activities[].is_assigned_to_all: boolean
$.activities[].is_closed: boolean
$.activities[].is_in_progress: boolean
$.activities[].is_inter_review_by_submitter: boolean | null
$.activities[].is_opened_catalog: boolean
$.activities[].is_review_homework: boolean
$.activities[].is_started: boolean
$.activities[].knowledge_node_ids: array; observed lengths=0,1,4
$.activities[].knowledge_node_ids[]: integer
$.activities[].knowledge_node_reference: array; observed lengths=0,1,4
$.activities[].knowledge_node_reference[]: object
$.activities[].knowledge_node_reference[].course_id: integer
$.activities[].knowledge_node_reference[].data: object
$.activities[].knowledge_node_reference[].id: integer
$.activities[].knowledge_node_reference[].knowledge_node: object
$.activities[].knowledge_node_reference[].knowledge_node.cognitive_dimension: string
$.activities[].knowledge_node_reference[].knowledge_node.course_id: integer
$.activities[].knowledge_node_reference[].knowledge_node.description: null
$.activities[].knowledge_node_reference[].knowledge_node.id: integer
$.activities[].knowledge_node_reference[].knowledge_node.name: string
$.activities[].knowledge_node_reference[].knowledge_node.parent_id: integer
$.activities[].knowledge_node_reference[].knowledge_node.sort: integer
$.activities[].knowledge_node_reference[].knowledge_node_id: integer
$.activities[].knowledge_node_reference[].refer_id: integer
$.activities[].knowledge_node_reference[].refer_type: string
$.activities[].late_submission_count: integer
$.activities[].lowest_score: integer
$.activities[].module_id: integer
$.activities[].non_submit_times: boolean | null
$.activities[].prerequisites: array; observed lengths=0
$.activities[].published: boolean
$.activities[].question_count: integer
$.activities[].rubric_id: integer
$.activities[].rubric_instance: object
$.activities[].rubric_instance.conditions: null
$.activities[].rubric_instance.id: integer
$.activities[].rubric_instance.name: null
$.activities[].rubric_instance.rubric: object
$.activities[].rubric_instance.rubric.conditions: null
$.activities[].rubric_instance.rubric.created_at: null
$.activities[].rubric_instance.rubric.created_by: object
$.activities[].rubric_instance.rubric.created_by.id: integer
$.activities[].rubric_instance.rubric.created_by.name: null
$.activities[].rubric_instance.rubric.engage_number: integer
$.activities[].rubric_instance.rubric.group_id: null
$.activities[].rubric_instance.rubric.group_name: null
$.activities[].rubric_instance.rubric.id: integer
$.activities[].rubric_instance.rubric.is_shared_rubric: boolean
$.activities[].rubric_instance.rubric.name: null
$.activities[].rubric_instance.rubric.updated_at: null
$.activities[].rubric_instance_id: integer
$.activities[].score_item_group_id: integer
$.activities[].score_item_group_name: null
$.activities[].score_item_scored: boolean | null
$.activities[].score_percentage: null | string
$.activities[].score_published: null
$.activities[].score_type: null
$.activities[].sort: integer
$.activities[].start_time: null | string
$.activities[].submit_by_group: boolean
$.activities[].submit_times: integer | null
$.activities[].syllabus_id: integer
$.activities[].teaching_model: string
$.activities[].teaching_unit_id: integer
$.activities[].title: string
$.activities[].type: string
$.activities[].unique_key: string
$.activities[].updated_at: string
$.activities[].uploads: array; observed lengths=0,1,2
$.activities[].uploads[]: object
$.activities[].uploads[].allow_aliyun_office_view: boolean
$.activities[].uploads[].allow_download: boolean
$.activities[].uploads[].allow_private_wps_office_view: boolean
$.activities[].uploads[].audio: null
$.activities[].uploads[].cc_license_code: string
$.activities[].uploads[].cc_license_description: string
$.activities[].uploads[].cc_license_link: string
$.activities[].uploads[].cc_license_name: string
$.activities[].uploads[].created_at: string
$.activities[].uploads[].created_by_id: integer
$.activities[].uploads[].deleted: boolean
$.activities[].uploads[].enable_set_h5_courseware_completion: boolean
$.activities[].uploads[].id: integer
$.activities[].uploads[].is_cc_video: boolean
$.activities[].uploads[].key: string
$.activities[].uploads[].link: null
$.activities[].uploads[].name: string
$.activities[].uploads[].origin_allow_download: boolean
$.activities[].uploads[].owner_id: integer
$.activities[].uploads[].question_count: integer
$.activities[].uploads[].reference_id: integer
$.activities[].uploads[].referenced_at: string
$.activities[].uploads[].scorm: null
$.activities[].uploads[].size: integer
$.activities[].uploads[].source: string
$.activities[].uploads[].status: string
$.activities[].uploads[].third_part_referrer_id: integer
$.activities[].uploads[].thumbnail: null
$.activities[].uploads[].type: string
$.activities[].uploads[].updated_at: string
$.activities[].uploads[].video_src_type: string
$.activities[].uploads[].videos: array; observed lengths=0,2,3,4
$.activities[].uploads[].videos[]: object
$.activities[].uploads[].videos[].duration: number
$.activities[].uploads[].videos[].id: integer
$.activities[].uploads[].videos[].resolution: string
$.activities[].using_phase: string
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/exams`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.exams: array; observed lengths=1
$.exams[]: object
$.exams[].announce_answer_status: string
$.exams[].announce_answer_time: null
$.exams[].announce_answer_type: string
$.exams[].announce_score_status: string
$.exams[].announce_score_time: null
$.exams[].assign_group_ids: array; observed lengths=0
$.exams[].assign_student_ids: array; observed lengths=0
$.exams[].check_submit_ip_consistency: boolean
$.exams[].completion_criterion: string
$.exams[].completion_criterion_key: string
$.exams[].completion_criterion_value: string
$.exams[].created_at: string
$.exams[].data: object
$.exams[].data.announce_answer_status: integer
$.exams[].data.announce_answer_time: null
$.exams[].data.announce_answer_type: integer
$.exams[].data.announce_score_status: integer
$.exams[].data.announce_score_time: null
$.exams[].data.auto_ai_grading_operator_id: integer
$.exams[].data.check_submit_ip_consistency: boolean
$.exams[].data.default_options_layout: integer
$.exams[].data.description: string
$.exams[].data.disable_copy_paste: boolean
$.exams[].data.disable_devtool: boolean
$.exams[].data.disable_right_click: boolean
$.exams[].data.enable_anti_cheat: boolean
$.exams[].data.enable_auto_ai_grading: boolean
$.exams[].data.enable_invigilation: boolean
$.exams[].data.eztest: object
$.exams[].data.is_fullscreen_mode: boolean
$.exams[].data.is_leaving_window_constrained: boolean
$.exams[].data.is_leaving_window_timeout: boolean
$.exams[].data.leaving_window_limit: null
$.exams[].data.leaving_window_timeout: null
$.exams[].data.limit_answer_on_signle_client: boolean
$.exams[].data.limit_short_answer_upload: boolean
$.exams[].data.platform: string
$.exams[].data.publish_time: null
$.exams[].data.subject_index_type: string
$.exams[].default_options_layout: string
$.exams[].description: string
$.exams[].disable_copy_paste: boolean
$.exams[].disable_devtool: boolean
$.exams[].disable_right_click: boolean
$.exams[].enable_anti_cheat: boolean
$.exams[].enable_edit: boolean
$.exams[].enable_exam_prerequisite: boolean
$.exams[].enable_invigilation: boolean
$.exams[].end_time: string
$.exams[].exam_prerequisite: null
$.exams[].group_set_id: integer
$.exams[].group_set_name: string
$.exams[].has_assign_group: boolean
$.exams[].has_assign_student: boolean
$.exams[].id: integer
$.exams[].imported_from: null
$.exams[].is_announce_answer_time_passed: boolean
$.exams[].is_announce_score_time_passed: boolean
$.exams[].is_assigned_to_all: boolean
$.exams[].is_closed: boolean
$.exams[].is_fullscreen_mode: boolean
$.exams[].is_in_progress: boolean
$.exams[].is_ip_constrained: boolean
$.exams[].is_leaving_window_constrained: boolean
$.exams[].is_leaving_window_timeout: boolean
$.exams[].is_opened_catalog: boolean
$.exams[].is_practice_mode: boolean
$.exams[].is_started: boolean
$.exams[].knowledge_node_ids: array; observed lengths=0
$.exams[].knowledge_node_reference: array; observed lengths=0
$.exams[].leaving_window_limit: null
$.exams[].leaving_window_timeout: null
$.exams[].limit_answer_on_signle_client: boolean
$.exams[].limit_short_answer_upload: boolean
$.exams[].limit_time: null
$.exams[].limited_ip: string
$.exams[].make_up_record: null
$.exams[].module_id: integer
$.exams[].module_sort: integer
$.exams[].prerequisites: array; observed lengths=0
$.exams[].publish_time: null
$.exams[].published: boolean
$.exams[].referrer_id: integer
$.exams[].referrer_type: string
$.exams[].score_percentage: string
$.exams[].score_rule: string
$.exams[].score_type: string
$.exams[].sort: integer
$.exams[].start_time: string
$.exams[].subjects_count: integer
$.exams[].subjects_rule: object
$.exams[].subjects_rule.select_subjects_randomly: boolean
$.exams[].subjects_rule.shuffle_options_randomly: boolean
$.exams[].subjects_rule.shuffle_subjects_randomly: string
$.exams[].subjects_rule.sub_subjects_randomly: boolean
$.exams[].submit_by_group: boolean
$.exams[].submit_times: integer
$.exams[].syllabus_id: integer
$.exams[].syllabus_sort: null
$.exams[].teaching_model: string
$.exams[].title: string
$.exams[].total_points: string
$.exams[].type: string
$.exams[].unique_key: string
$.exams[].using_phase: string
```

## `GET lnt.xmu.edu.cn/api/courses/{courseId}/classroom-list`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.classrooms: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/rubrics`

出现 1 次；HTTP：`200`。

查询参数名：`fields, no-intercept`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.rubrics: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/rubrics/template`

出现 1 次；HTTP：`200`。

查询参数名：`no-intercept`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.conditions: array; observed lengths=1
$.conditions[]: object
$.conditions[].levels: array; observed lengths=4
$.conditions[].levels[]: object
$.conditions[].levels[].description: string
$.conditions[].levels[].score: number
$.id: integer
$.name: string
```

## `GET lnt.xmu.edu.cn/api/air-credit/user`

出现 3 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 3}`。

响应 JSON 结构：

```text
$: object
$.credit_state: null
$.is_low_air_credit: boolean
$.user_id: integer
$.user_name: string
$.user_no: string
```

## `GET lnt.xmu.edu.cn/api/subject-libs`

出现 2 次；HTTP：`200`。

查询参数名：`with_folder`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

响应 JSON 结构：

```text
$: object
$.subject_libs: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/activities/{activityId}`

出现 1 次；HTTP：`200`。

查询参数名：`sub_course_id`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.assign_group_ids: array; observed lengths=0
$.assign_student_ids: array; observed lengths=0
$.average_score: number
$.can_show_score: boolean
$.cc_license_references: array; observed lengths=0
$.completion_criterion: string
$.completion_criterion_key: string
$.completion_criterion_value: string
$.course_id: integer
$.created_at: string
$.data: object
$.data.allow_retract: boolean
$.data.announce_answer_status: string
$.data.announce_score_type: integer
$.data.description: string
$.data.has_assign_target: boolean
$.data.homework_score_percentage: object
$.data.homework_score_percentage.instructor_score_percentage: string
$.data.homework_type: string
$.data.inter_review_incomplete_score_minus: boolean
$.data.inter_review_incomplete_score_minus_percent: null
$.data.intra_review_incomplete_score_minus: boolean
$.data.intra_review_incomplete_score_minus_percent: null
$.data.is_announce_mark: boolean
$.data.mode: string
$.data.non_submit_times: boolean
$.data.other_resources: array; observed lengths=0
$.data.reference_answer: string
$.data.score_percentage: string
$.data.score_rule: string
$.data.show_intra_rubric: boolean
$.data.show_rubric: boolean
$.data.submit_times: null
$.enable_edit: boolean
$.end_time: string
$.group_set_id: integer
$.group_set_name: string
$.has_assign_group: boolean
$.has_assign_student: boolean
$.has_score_count: integer
$.highest_score: number
$.id: integer
$.imported_from: string
$.imported_track_id: string
$.inter_review_named: boolean
$.inter_score_map: object
$.inter_score_map.end_time: null
$.inter_score_map.id: integer
$.inter_score_map.is_closed: null
$.inter_score_map.is_started: null
$.inter_score_map.pieces_cnt: integer
$.inter_score_map.start_time: null
$.interaction_activity_attributes: null
$.intra_rubric_id: integer
$.intra_rubric_instance: object
$.intra_rubric_instance.conditions: null
$.intra_rubric_instance.id: integer
$.intra_rubric_instance.name: null
$.intra_rubric_instance.rubric: object
$.intra_rubric_instance.rubric.conditions: null
$.intra_rubric_instance.rubric.created_at: null
$.intra_rubric_instance.rubric.created_by: object
$.intra_rubric_instance.rubric.created_by.id: integer
$.intra_rubric_instance.rubric.created_by.name: null
$.intra_rubric_instance.rubric.engage_number: integer
$.intra_rubric_instance.rubric.group_id: null
$.intra_rubric_instance.rubric.group_name: null
$.intra_rubric_instance.rubric.id: integer
$.intra_rubric_instance.rubric.is_shared_rubric: boolean
$.intra_rubric_instance.rubric.name: null
$.intra_rubric_instance.rubric.updated_at: null
$.intra_rubric_instance_id: integer
$.intra_score_map: object
$.intra_score_map.end_time: null
$.intra_score_map.id: integer
$.intra_score_map.is_closed: null
$.intra_score_map.start_time: null
$.is_announce_reference_answer_time_passed: boolean
$.is_announce_score_time_passed: boolean
$.is_assigned_to_all: boolean
$.is_closed: boolean
$.is_in_progress: boolean
$.is_inter_review_by_submitter: boolean
$.is_opened_catalog: boolean
$.is_resubmit_open: boolean
$.is_review_homework: null
$.is_started: boolean
$.knowledge_node_ids: array; observed lengths=0
$.knowledge_node_reference: array; observed lengths=0
$.late_submission_count: integer
$.lowest_score: number
$.module_id: integer
$.need_make_up: boolean
$.need_remind: boolean
$.non_submit_times: boolean
$.prerequisites: array; observed lengths=0
$.published: boolean
$.rubric_id: integer
$.rubric_instance: object
$.rubric_instance.conditions: null
$.rubric_instance.id: integer
$.rubric_instance.name: null
$.rubric_instance.rubric: object
$.rubric_instance.rubric.conditions: null
$.rubric_instance.rubric.created_at: null
$.rubric_instance.rubric.created_by: object
$.rubric_instance.rubric.created_by.id: integer
$.rubric_instance.rubric.created_by.name: null
$.rubric_instance.rubric.engage_number: integer
$.rubric_instance.rubric.group_id: null
$.rubric_instance.rubric.group_name: null
$.rubric_instance.rubric.id: integer
$.rubric_instance.rubric.is_shared_rubric: boolean
$.rubric_instance.rubric.name: null
$.rubric_instance.rubric.updated_at: null
$.rubric_instance_id: integer
$.score_item_group_id: integer
$.score_item_group_name: string
$.score_item_scored: boolean
$.score_percentage: string
$.score_published: boolean
$.score_type: string
$.sort: integer
$.start_time: string
$.sub_meetings: null
$.submit_by_group: boolean
$.submit_times: null
$.syllabus_id: integer
$.teaching_model: string
$.teaching_unit_id: integer
$.tencent_meeting_type: null
$.title: string
$.type: string
$.unique_key: string
$.updated_at: string
$.uploads: array; observed lengths=0
$.user_submit_count: integer
$.using_phase: string
$.version: null
```

## `GET lnt.xmu.edu.cn/api/course/{courseId}/activity-reads-for-user`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.activity_reads: array; observed lengths=9
$.activity_reads[]: object
$.activity_reads[].activity_id: integer
$.activity_reads[].activity_type: string
$.activity_reads[].completeness: string
$.activity_reads[].created_by_id: integer
$.activity_reads[].created_for_id: integer
$.activity_reads[].data: object
$.activity_reads[].data.completeness: integer
$.activity_reads[].data.upload_ids: array; observed lengths=1
$.activity_reads[].data.upload_ids[]: integer
$.activity_reads[].id: string
$.activity_reads[].last_visited_at: string
```

## `GET lnt.xmu.edu.cn/api/course/{courseId}/homework/duplicate-lib`

出现 2 次；HTTP：`200`。

查询参数名：`conditions, page, page_size`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

请求 JSON / JSON 内嵌参数结构：

```text
$query.conditions: object
$query.conditions.keyword: string
$query.conditions.order_by: string
```

响应 JSON 结构：

```text
$: object
$.end: integer
$.page: integer
$.page_size: integer
$.pages: integer
$.start: integer
$.total: integer
$.uploads: array; observed lengths=0
```

## `POST lnt.xmu.edu.cn/api/course/activities-read/{id}`

出现 1 次；HTTP：`201`。

查询参数名：``；表单字段名：``。

请求类型：`application/json`；响应类型：`application/json`。

响应解析：`{"json": 1}`。

请求 JSON / JSON 内嵌参数结构：

```text
$: object
```

响应 JSON 结构：

```text
$: object
$.activity_id: integer
$.activity_type: string
$.completeness: string
$.created_by_id: integer
$.created_for_id: integer
$.data: object
$.id: string
$.last_visited_at: string
```

## `GET lnt.xmu.edu.cn/api/uploads/{uploadId}/in-rich-content`

出现 1 次；HTTP：`403`。

查询参数名：`created_at`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.message: string
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/student-submissions`

出现 1 次；HTTP：`200`。

查询参数名：`need_uploads_size`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.submissions: array; observed lengths=111
$.submissions[]: object
$.submissions[].attachments_size: integer
$.submissions[].created_at: string
$.submissions[].created_by: object
$.submissions[].created_by.id: integer
$.submissions[].id: integer
$.submissions[].instructor_comment: null | string
$.submissions[].instructor_score: null | number
$.submissions[].is_redo: boolean
$.submissions[].is_resubmitted: boolean
$.submissions[].marked_submitted: boolean
$.submissions[].recommend: integer
$.submissions[].score: null
$.submissions[].submit_by_instructor: boolean
```

## `GET lnt.xmu.edu.cn/api/course/{courseId}/students`

出现 1 次；HTTP：`200`。

查询参数名：`ignore_avatar`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.students: array; observed lengths=111
$.students[]: object
$.students[].aliases: array; observed lengths=1
$.students[].aliases[]: null
$.students[].avatar_big_url: string
$.students[].avatar_small_url: string
$.students[].comment: null
$.students[].department: object
$.students[].department.code: string
$.students[].department.id: integer
$.students[].department.name: string
$.students[].department.stopped: boolean
$.students[].grade: null
$.students[].group_ids: array; observed lengths=0
$.students[].id: integer
$.students[].imported_track_id: null
$.students[].klass: null
$.students[].name: string
$.students[].nickname: null
$.students[].roles: array; observed lengths=1
$.students[].roles[]: string
$.students[].user_no: string
```

## `GET lnt.xmu.edu.cn/api/activities/{activityId}/homework-scores`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.homework_scores: array; observed lengths=111
$.homework_scores[]: object
$.homework_scores[].activity_id: integer
$.homework_scores[].final_score: string
$.homework_scores[].instructor_comment: null | string
$.homework_scores[].inter_score: null
$.homework_scores[].intra_score: null
$.homework_scores[].review_incomplete_score_minus: null | string
$.homework_scores[].score: null | string
$.homework_scores[].status_comment: null
$.homework_scores[].student_id: integer
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/make-up-records`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.make_up_records: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/resubmit-records`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.resubmit_records: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/redo-map`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.redo_map: object
```

## `GET lnt.xmu.edu.cn/api/zip-status/homework-zip/{activityId}`

出现 1 次；HTTP：`200`。

查询参数名：`no-intercept`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.zip: null
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/duplicate-detect/task`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/homework/{activityId}/duplicate-detect/rate`

出现 1 次；HTTP：`200`。

查询参数名：`target_ids`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.items: array; observed lengths=0
```

## `GET lnt.xmu.edu.cn/api/orgs/{orgId}/departments`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.departments: array; observed lengths=13
$.departments[]: object
$.departments[].code: string
$.departments[].departments: array; observed lengths=0,2,7,11,14,15,27,38,51,73
$.departments[].departments[]: object
$.departments[].departments[].code: string
$.departments[].departments[].departments: array; observed lengths=0,1,2,3,4,5,6,7,8,9,10,12,13,14,15,16,17,66
$.departments[].departments[].departments[]: object
$.departments[].departments[].departments[].code: string
$.departments[].departments[].departments[].departments: array; observed lengths=0,1,2,3,4,5,6,7,8,9,10,11,13,14,17,18,24,28,31
$.departments[].departments[].departments[].departments[]: object
$.departments[].departments[].departments[].departments[].code: string
$.departments[].departments[].departments[].departments[].departments: array; observed lengths=0,1
$.departments[].departments[].departments[].departments[].departments[]: object
$.departments[].departments[].departments[].departments[].departments[].code: string
$.departments[].departments[].departments[].departments[].departments[].departments: array; observed lengths=0
$.departments[].departments[].departments[].departments[].departments[].id: integer
$.departments[].departments[].departments[].departments[].departments[].name: string
$.departments[].departments[].departments[].departments[].departments[].parent_id: integer
$.departments[].departments[].departments[].departments[].id: integer
$.departments[].departments[].departments[].departments[].name: string
$.departments[].departments[].departments[].departments[].parent_id: integer
$.departments[].departments[].departments[].id: integer
$.departments[].departments[].departments[].name: string
$.departments[].departments[].departments[].parent_id: integer
$.departments[].departments[].id: integer
$.departments[].departments[].name: string
$.departments[].departments[].parent_id: integer
$.departments[].id: integer
$.departments[].name: string
$.departments[].parent_id: integer
```
