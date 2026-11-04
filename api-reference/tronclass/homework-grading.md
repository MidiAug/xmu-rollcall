# 助教作业评分接口与 CSV 导入分析

整理日期：2026-11-04。来源：用户提供的一份助教网页改分 HTTP 导出，全文仅在本机离线处理，未使用其中会话访问服务器。它包含其他网站流量，本文只提炼畅课相关业务。

**结论：抓包证实可以通过单学生评分接口保存一份作业的分数。CSV 导入后逐条保存有协议依据，但尚未实现，也没有实测多学生批量提交。** 当前证据只涉及畅课作业评分，不证明能修改教务系统总评或考试成绩。

## 1. 已证实的保存请求

```http
PUT https://lnt.xmu.edu.cn/api/course/activities/{activityId}/score
Content-Type: application/json;charset=UTF-8
```

人为编造的请求体示例（不是原始学生或成绩）：

```json
{
  "student_id": 900001,
  "score": "86.5"
}
```

| 字段 | 抓包类型 | 解释与限制 |
| --- | --- | --- |
| `activityId` | 路径整数 | 作业对应的学习活动 ID；不能用课程 ID 或提交记录 ID 替代 |
| `student_id` | JSON 整数 | 畅课内部学生 ID；不是学号字符串 |
| `score` | JSON 字符串 | 网页提交分数字符串。样本实际只覆盖整数分，不据此承诺小数、负数、超范围分或空值都可接受 |

抓包中的三次 PUT 对应同一活动、同一学生，均返回 `201 CREATED`，响应类型为 `application/json`。没有观察到一次提交多个学生的请求。前述 `86.5` 仅展示字符串形式，不是小数分实测结果。

响应保留必要字段后的**合成示例**如下；原响应还有更多字段，此处不是完整响应模型：

```json
{
  "data": {
    "activity_id": 800001,
    "student_id": 900001,
    "final_score": "86.5",
    "score": null,
    "instructor_comment": null,
    "inter_score": null,
    "intra_score": null
  },
  "message": "<响应消息，未保留原值>",
  "submission": {
    "final_score": null
  }
}
```

三个样本中 `data.final_score` 都是字符串，数值与请求一致，但格式有变化（例如整数形式变为带小数的形式）。比较时应按十进制数值比较，不能直接比较字符串。`data.score` 与 `submission.final_score` 均为空，因此不能只看这些字段判失败。检查 HTTP 状态、JSON 结构、返回活动和学生 ID、`data.final_score`，并在提交后重新读取核对。

本次只观察到保存分数，没有独立的发布成绩请求，不能承诺学生是否立即可见，也不能把重试当成无副作用操作：重复保存可能产生新的修改记录。

## 2. 作业、学生与成绩关联

基础主机：`https://lnt.xmu.edu.cn`。下表全部为抓包中实际出现的路径；`course` / `courses`、`homework` / `homeworks`、`activity` / `activities` 的单复数必须按接口保留。

| 方法与路径 | 作用或响应结构 | 证据限制 |
| --- | --- | --- |
| `GET /api/courses/{courseId}` | 课程信息 | 不从客户端菜单可见性推断写权限 |
| `GET /api/courses/{courseId}/modules` | 课程模块 | 辅助定位作业 |
| `GET /api/courses/{courseId}/activities?sub_course_id=0` | 活动列表，根字段 `activities` | 该查询值来自本次网页；不能推断所有子课堂都用 0 |
| `GET /api/activities/{activityId}?sub_course_id=0` | 作业详情，包括 `id`、`course_id`、`type`、`submit_by_group`、`score_type`、`score_published` 和 `data` 内评分配置 | 评分量规、互评、小组作业及发布规则不能从普通作业直接推广 |
| `GET /api/course/{courseId}/students?ignore_avatar=false` | `students[]`：`id`、`user_no`、`name`、`roles` 等 | 用学号 `user_no` 关联内部 `id`；姓名只用于人工确认，不作为唯一键 |
| `GET /api/homework/{activityId}/student-submissions?need_uploads_size=true` | `submissions[]`：`id`、`created_by.id`、`score`、`instructor_score`、`marked_submitted`、`is_redo`、`is_resubmitted` 等 | 提交记录的 `id` 与学生 ID 含义不同；没有提交记录不代表可自动给零分 |
| `GET /api/activities/{activityId}/homework-scores` | 根字段 `homework_scores` | 本次在改分前读取，列表为空；非空元素字段尚无此抓包证据 |
| `PUT /api/course/activities/{activityId}/score` | 单学生保存分数，见上一节 | 三次 `201`，仅一个学生 |
| `GET /api/homeworks/{activityId}/export-score` | 返回 Excel 文件 | 响应类型为 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`；不是 JSON，也不是批量导入接口；未解析工作簿列和内容 |
| `GET /api/activity/{activityId}/submitter/{studentId}/score-records?page={page}&page_size={pageSize}` | `records[]` 修改历史以及分页字段 | 出现三条记录；不是跨课程全量审计接口 |

历史响应的根字段包括 `start`、`end`、`page`、`page_size`、`pages`、`total`、`records`。记录包括 `final_score`、`old_final_score`、`score`、`old_score`、`operator_id`、`operator_name`、`created_at`、`score_method`、`version`；其中 `final_score` 在样本中为 JSON 数字，与 PUT 响应的字符串类型不同。不要记录或公开实际操作人及修改时间。

辅助接口也出现在同一流程：

| 路径（均为 GET） | 观察到的用途或结构 |
| --- | --- |
| `/api/course/{courseId}/activity-publish-setting` | 活动发布配置读取；不等于发布成绩 |
| `/api/homework/{activityId}/make-up-records` | `make_up_records[]`，含 `student_id`、`submitted` 与时间字段 |
| `/api/homework/{activityId}/resubmit-records` | `resubmit_records`，本次为空 |
| `/api/homework/{activityId}/redo-map` | `redo_map`，本次为空对象 |
| `/api/homework/{activityId}/duplicate-detect/task` | 查重任务查询，多次出现；不是评分保存 |
| `/api/homework/{activityId}/duplicate-detect/rate` | 查重相关读取；未据此推断评分规则 |
| `/api/course/{courseId}/homework/duplicate-lib` | 查重库相关读取 |
| `/api/rubrics`、`/api/rubrics/template` | 评分量规相关读取；未验证量规评分提交 |

抓包还有打包、附件读取及删除请求。批量评分不需要重放这些操作；尤其 `DELETE /api/uploads/{uploadId}` 是删除附件，不是撤销评分。行为记录与访问统计请求也不能用作成绩接口。

## 3. 登录与权限

观察到的评分请求通过网页会话 Cookie 认证，并带有同站 `Origin`、`Referer` 和 JSON 内容类型。没有在该请求中观察到额外 Authorization 或独立 CSRF 请求头，这不等于服务端不存在其他校验。

复用时使用本人正常登录、在目标课程有评分权限的教师或助教会话。不要复制原始抓包中的旧 Cookie，也不要把会话写进 CSV、文档、源码或日志。资料不包含登录实现或可直接使用的会话。角色和课程范围应由服务器实际授权，不能靠替换学生或活动 ID 获得权限。

## 4. CSV 批量评分建议方案（待实现）

现有证据支持的方案是“本地批量导入、逐条保存”，并没有证实服务端提供批量写入端点。

建议先限定为用户选定的一门课、一次普通个人作业，导入格式为：

```csv
user_no,score
DEMO0001,86
DEMO0002,90
```

以上学号和成绩均为虚构。`user_no` 必须作为文本读取，保留前导零，不转换为浮点数。UTF-8 CSV 可作为首个入口；Excel `.xlsx` 是可另行支持的导入格式，不是这次已经完成的功能。

建议交互和保存顺序：

1. 正常登录，选定课程和作业，显示作业类型及评分配置。课程名单、已有成绩、提交记录按课程/活动身份关联，不能复用另一门课的映射。
2. 本地解析表格，检查列名、重复学号、空分数、非数字以及当前评分规则允许的范围。空白表示跳过，不转换成零；明确的零分不能当空值丢掉。量规、小组、互评等规则未覆盖前不自动套普通个人作业流程。
3. 用 `students[].user_no` 匹配唯一学生，将其 `id` 写入请求。无匹配、多匹配或存在重复行的记录先阻止提交；不要按 CSV 行号或学生名单顺序对齐。
4. 显示预览：课程、作业、学生、旧分、新分、未匹配项和将覆盖的已有成绩。用户确认本次批次后再执行；未选择覆盖的已有成绩跳过。未提交作业的处理由用户明确决定。
5. 沿用客户端限流和退避，初版顺序保存每条记录，不做高并发整班请求。每条结果关联原始行、活动和学生；切换账号、课程或作业后不得继续使用旧上下文提交。
6. 对成功响应按第一节核对；对超时或连接中断，先读取确认是否已经保存，再决定是否重试。遇到登录失效或无权限停止批次并保留进度；限流按服务器反馈等待。不要把整个批次从头盲目重放。
7. 批次结束后重新读取成绩核对，必要时使用导出文件或修改历史辅助确认。结果按成功、失败、跳过、结果待确认分别展示，允许仅重做已确认未保存的行。

“一人一次请求”意味着中途失败会产生部分成功，不能承诺整批事务或自动撤销。覆盖之前先保留旧分供复核；本抓包没有清空评分或回滚接口，旧分为空时尤其不能靠提交空值来恢复。

## 5. 验证与待补证据

已完成：离线定位请求与响应、核对三个写入样本的学生/活动一致性及分数数值、提取脱敏字段结构。未访问服务器、未重放请求、未实现导入器、未修改真实成绩。

仍待验证：多学生保存、小数与评分范围、已有分数覆盖、未提交学生评分、空值/清空评分、小组与量规作业、学生可见性、分页完整性、限流与会话失效、断网后的核对及实际 Excel 列结构。非空 `homework_scores` 响应也需要补样本，不能凭空编造元素模型。

如后续实现，需同步应用规格和验收，并针对学号映射、重复/空白/零分、部分成功、身份切换和超时核对做回归。当前接口资料不代表客户端已经支持批量改分。

## 6. 可追溯证据

同目录 [JSON 清单](homework-grading-evidence.json) 保存源文件 SHA-256、请求行序号、参数化路由、查询参数名、状态和必要字段类型。序号按所有 HTTP 请求行排序，包含 CONNECT 与其他网站请求；没有把整份抓包或原始 JSON 放进仓库。

清单只保留字段结构与协议元数据，字段值不经“删几个 Cookie”后直接分享。身份、课程、作业、成绩、附件与访问记录均不保留原值。文档中的示例是手工合成，不是原响应的部分脱敏副本。
