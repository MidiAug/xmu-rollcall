# 2026-11-09 桌面接口归档

整理开始：2026-11-09；归档完成：2026-11-10（UTC+8）。目录日期标识本次整理批次。本批只做离线提取，没有使用原凭据访问服务器，也没有执行评分、登录或预约。

| 原文件 | 业务观察时间 UTC+8（HTTP Date） | 说明与结构 |
| --- | --- | --- |
| 畅课问题1_Full.txt | 2026-11-04 17:17:46—17:17:57 | [课程入口与权限页](course-permission.md) / [JSON](course-permission.json) |
| 助教改成绩.txt | 2026-11-04 17:23:22—17:24:38 | [评分、导出、打包与删除附件](ta-grading.md) / [JSON](ta-grading.json) |
| 助教看作业.txt | 2026-11-04 17:29:46—17:29:57 | [助教作业读取](ta-homework.md) / [JSON](ta-homework.json) |
| 登录信息门户.txt | 2026-11-05 14:07:30—14:07:42 | [门户与 IDS](portal-login.md) / [JSON](portal-login.json) |
| 看成绩.txt | 2026-11-05 20:25:32—20:25:39 | [畅课最终成绩](final-grades.md) / [JSON](final-grades.json) |

## 关键结论

- “看成绩”是畅课作业成绩，不是教务本科/研究生成绩查询；不能据此修改教务成绩协议。
- 11 月 4 日两份助教抓包的 `homework_scores` 为空；11 月 5 日样本包含 111 行，字段为 `student_id`、`activity_id`、`final_score` 等。分别保留空与非空证据，不把空样本推成服务端能力限制。字段关联见[助教说明](../../tronclass/homework-grading.md)。
- 三次 `PUT /api/course/activities/{activityId}/score` 返回 201；请求为 `student_id: integer`、`score: string`。这是历史操作观察，归档过程没有写入任何成绩。
- `POST /api/homeworks/{activityId}/zip` 包含 `ids`、`all_ids`、`column_setting` 与 `timezone`；观察到所选数组和完整数组规模不同。打包范围不能仅凭当前搜索结果决定。
- `GET .../export-score` 是工作簿下载；本批保留 MIME 类型，不保存真实工作簿或推断列结构。`DELETE /api/uploads/{uploadId}` 删除附件，不是撤销评分。
- 课程问题样本包含 `/errors/no_permission` 页面。页面存在、HTML 返回 200、课程元数据读取成功，都不能单独证明具有评分权限。
- 门户的 IDS 登录、CAS ticket 回跳及门户会话与畅课会话分别处理，见[流程说明](../../portal-login.md)。

## 如何读结构文件

每份 Markdown 给出请求顺序和字段类型；同名 JSON 额外保留请求头/响应头**名称**、逐请求服务器时间与完整合并结构。`observed_lengths` 是样本数组长度集合；字段类型并集不表示字段在每一行都存在。`{dynamic-key}` 表示已移除真实动态键，`{id}` 等表示路径占位符；字段缺失和 null 需分别处理。

提取前先按 HTTP 请求边界切分，再处理 chunked、gzip、Brotli、Zstandard 和 JSONP。每个已选 JSON 响应均成功解析，数组扫描全部行。HTML 只保留输入字段名；二维码、图片、附件、工作簿和页面脚本不保留。结构清单不保证列出所有页面脚本中的隐藏逻辑，也不能恢复被移除的字段值。

HTTP Date 精度为秒，可能重复或与客户端有钟差；请求先后以 `export_request_index` 为准。`client_time_without_date` 如出现，仅代表原头中的时分秒，没有补造日期。检测时间来自历史响应头，本批归档不是 2026-11-09 的在线可用性验证。

## 原件生命周期

上表五份原件已于2026-11-10移入Windows回收站；每份均保存字节数和 SHA-256，清理前复核未变化。全部 11 份文件的跨项目去向与清理回执登记在提供者本机总索引。未清空回收站，不视作安全擦除。原件不随本目录分发，后续复测需重新取得有效授权和样本。
