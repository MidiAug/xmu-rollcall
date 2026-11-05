# 助教作业评分接口与 CSV 导入分析

整理日期：2026-11-05。来源：用户提供的助教查看作业、修改成绩及非空成绩 HTTP 导出，全文仅在本机离线处理，未使用其中会话访问服务器。其中包含其他网站流量，本文只提炼畅课相关业务。

**结论：抓包证实可以通过单学生评分接口保存一份作业的分数。客户端现已接入“工具 → 研究生 → 修改作业”，支持 CSV 预览确认后逐条保存，以及选择学生打包下载。实现通过模拟 HTTP 与页面回归，未向真实课程提交成绩或验证真实服务器批量写入。** 当前证据只涉及畅课作业评分，不证明能修改教务系统总评或考试成绩。

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
| `GET /api/homework/{activityId}/student-submissions?need_uploads_size=true` | `submissions[]`：`id`、`created_by.id`、`score`、`instructor_score`、`marked_submitted`、`is_redo`、`is_resubmitted`、`attachments_size` 等 | 提交记录的 `id` 与学生 ID 含义不同；没有提交记录不代表可自动给零分 |
| `GET /api/activities/{activityId}/homework-scores` | `homework_scores[]`：`activity_id`、`student_id`、`final_score` 等 | 非空样本一次返回111人；按学生ID关联，最终分数用final_score，不能由提交列表教师评分代替 |
| `PUT /api/course/activities/{activityId}/score` | 单学生保存分数，见上一节 | 三次 `201`，仅一个学生 |
| `GET /api/homeworks/{activityId}/export-score` | 返回 Excel 文件 | 响应类型为 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`；不是 JSON，也不是批量导入接口；未解析工作簿列和内容 |
| `GET /api/activity/{activityId}/submitter/{studentId}/score-records?page={page}&page_size={pageSize}` | `records[]` 修改历史以及分页字段 | 出现三条记录；不是跨课程全量审计接口 |

全班成绩的非空证据见[字段清单](homework-final-grades-evidence.json)。111行的activity_id、student_id均为整数，final_score均为数字字符串；其他已观测字段包括instructor_comment、score、inter_score、intra_score、review_incomplete_score_minus和status_comment。提交列表中3人的instructor_score为空，但整批接口仍有final_score，因此显示最终分数必须以整批接口为准。客户端校验活动关联、学生重复和数值，失败保留旧快照，不转为N次个人历史请求。此处只描述观测结构，不推断缺失行应自动给零分。

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

## 4. CSV 批量评分客户端流程

现有证据支持的方案是“本地批量导入、逐条保存”，并没有证实服务端提供批量写入端点。

当前限定为用户选定的一门课、一次普通个人百分制作业，导入格式为：

```csv
user_no,score
DEMO0001,86
DEMO0002,90
```

以上学号和成绩均为虚构。`user_no` 必须作为文本读取，保留前导零，不转换为浮点数。目前支持 UTF-8 CSV，不支持直接导入 Excel `.xlsx`。

当前交互和保存顺序：

1. 正常登录，选定课程和作业，显示作业类型及评分配置。课程名单、已有成绩、提交记录按课程/活动身份关联，不能复用另一门课的映射。
2. 本地解析表格，检查列名、重复学号、空分数、非数字以及当前评分规则允许的范围。空白分数报错并阻止整批提交，不转换成零；空白行跳过，明确的零分正常保存。量规、小组、互评等规则未覆盖前不自动套普通个人作业流程。
3. 用 `students[].user_no` 匹配唯一学生，将其 `id` 写入请求。无匹配、多匹配或存在重复行的记录先阻止提交；不要按 CSV 行号或学生名单顺序对齐。
4. 显示预览：课程、作业、学生、新分与未匹配项，并要求选择是否允许覆盖已有成绩。旧分在每条写入之前通过修改历史完整分页读取核对。用户确认本次批次后再执行；未选择覆盖的已有成绩跳过。未提交作业的处理由用户明确决定。
5. 沿用客户端限流和退避，初版顺序保存每条记录，不做高并发整班请求。每条结果关联原始行、活动和学生；切换账号、课程或作业后不得继续使用旧上下文提交。
6. 对成功响应按第一节核对；对超时或连接中断，停止批次并标记结果待确认。用户核对成绩后可重新导入；再次预检发现分数已一致时跳过保存。登录失效、无权限或限流同样停止，不自动重发写请求。
7. 批次结束后重新读取成绩核对，必要时使用导出文件或修改历史辅助确认。结果按成功、失败、跳过、结果待确认分别展示。失败或待确认批次不直接续跑，需核对后重新导入；主动停止的未处理行可再次确认继续。

“一人一次请求”意味着中途失败会产生部分成功，不能承诺整批事务或自动撤销。覆盖之前先保留旧分供复核；本抓包没有清空评分或回滚接口，旧分为空时尤其不能靠提交空值来恢复。

## 5. 验证与待补证据

已完成：离线分析两份抓包，核对三个写入样本，提取脱敏结构；实现课程作业分页、学生名单与提交关联、修改历史核对、CSV 导入与串行保存、打包状态和下载入口。模拟 HTTP 验证零分、覆盖选择、部分失败、超时与会话取消；页面回归覆盖手机/桌面浅深、确认/取消、新包就绪与身份切换。未访问真实服务器、未重放会话、未修改真实成绩。

仍待验证：多学生保存、小数与评分范围、已有分数覆盖、未提交学生评分、空值/清空评分、小组与量规作业、学生可见性、分页完整性、限流与会话失效、断网后的核对及实际 Excel 列结构。非空整批成绩已由新增抓包证实；完整性、评分和权限的真实服务器验收仍须分别报告。

规格与本机验收记录为 AC-TA-GRADING。当前验证为虚构数据与模拟 HTTP；仍需教师/助教在本人授权课程中进行真实服务器验收。学生行先显示当前身份的缓存，进入自动读取全班最终成绩并整批更新；评分历史只用于主动查看记录及写前/写后核对，不用于遍历全班填成绩。

## 6. 可追溯证据

同目录 [JSON 清单](homework-grading-evidence.json) 保存源文件 SHA-256、请求行序号、参数化路由、查询参数名、状态和必要字段类型。序号按所有 HTTP 请求行排序，包含 CONNECT 与其他网站请求；没有把整份抓包或原始 JSON 放进仓库。

清单只保留字段结构与协议元数据，字段值不经“删几个 Cookie”后直接分享。身份、课程、作业、成绩、附件与访问记录均不保留原值。文档中的示例是手工合成，不是原响应的部分脱敏副本。


## 7. 选择学生打包、重新打包与下载

同一份改分抓包也包含打包操作，新提供的作业列表抓包补充了作业分页和“尚无打包”的响应。仅观察到 `zip: null` 与 `status: ready`；其他进行中/失败状态的服务器具体形态尚需真网验证。

```http
POST /api/homeworks/{activityId}/zip
Content-Type: application/json
```

以下是合成示例，学生 ID 均为虚构：

```json
{
  "ids": [900001],
  "all_ids": [900001, 900002],
  "column_setting": {
    "showUserNo": true,
    "showDepartment": false,
    "showReviewCount": true,
    "showPeerReviewScore": true,
    "showIntraPeerReviewScore": true,
    "showInterPeerReviewScore": true,
    "showAttachmentsSize": true,
    "showInstructorScore": true,
    "showComment": true,
    "showGrade": false
  },
  "timezone": -480
}
```

`ids` 已核对为勾选学生的内部 ID，不是提交记录 ID。`all_ids` 在抓包中与课程学生全名单完全一致，不仅包含有提交记录的学生。`timezone` 为当地 UTC 时差分钟数的相反数，上海时区为 -480。POST 返回 `200` 和空对象，不能据此判定打包已经完成。

通过以下接口检查服务器结果：

```http
GET /api/zip-status/homework-zip/{activityId}?no-intercept=true
```

完成时的合成响应（key 仅为示例）：

```json
{
  "zip": {
    "id": 700001,
    "created_at": "2026-01-01T00:00:00Z",
    "key": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "name": "示例作业包.zip",
    "status": "ready"
  }
}
```

下载地址为 `https://c-media.xmu.edu.cn/download/file/{key}`。抓包中该模式与真实媒体下载请求一致；重新打包前后的包 ID、key 和创建时间均变化。

客户端每次重新打包前读取包身份作为基线，并隐藏旧下载入口；只有新包 `ready` 且 ID 或 key 已变化才开放“下载打包”和下载选项中的“复制下载链接”。已有包只代表上一次服务器任务，未选人时标为“下载上次打包”；改变学生选择后隐藏不匹配的下载入口，需要重新打包。等待期间改变选择也不会把旧任务的结果标成本次选择的包。

等待期间每 5 秒检查一次，最多自动检查 60 次；页面隐藏、退出或应用进入后台停止自动检查，仍可手动检查。手动检查保留 5 秒节流，不后台永久轮询。打包请求不自动重试；请求未确认时优先检查服务器状态，避免重复发起。下载交给浏览器，不附加应用会话 Cookie，不将包 key 写入日志或仓库。

作业列表接口：`GET /api/courses/{courseId}/homework-activities`，查询包含 `conditions`、`page`、`page_size`、`reloadPage`。抓包使用页大小 20，按模块排序。响应的 `expected_submit_count`、`submitted_count`、`unsubmitted_count` 和 `scored_count` 是作业列表汇总；进入详情后提交明细可能已变化，不将两次读取当作同一时刻快照。

## 8. 客户端页面与平台范围

只有一门教师/助教课程时直接展示作业；没有课程显示空态，多门才出现课程切换。桌面“修改作业”以全宽学生表格为主，选中后显示打包操作；CSV 的格式说明、预览、覆盖选项、进度与结果放在独立导入对话框中。窄桌面仍保留完整功能，表格可横向滚动。

Android/iOS 的“助教作业”进入独立只读详情，展示作业概览、学生提交状态与自动更新成绩。只读取课程作业、详情、学生、提交记录和全班最终成绩，不读取打包状态，不发起打包或评分写入。按平台区分，手机横屏或平板也不因屏幕变宽而开放批量写入。页面使用同一会话隔离与课程校验逻辑。

## 2026-11-05 单条评分与自动显示

电脑成绩输入框按回车是用户确认该学生本次分数的动作，不再额外弹窗。0至100校验与CSV共用；普通个人百分制作业、已提交学生才开放快捷编辑。沿用TaGradeBatch读取旧值、相同分数跳过、保存后读取结果及不自动重发PUT；丢失响应仅自动补一次读取，仍失败时保留草稿并提示同步失败。CSV的预览、覆盖/未提交选项及确认流程保留。

名单/成绩缓存按真实身份、courseId、activityId隔离，仅镜像显示字段，使用原JsonDiskCache并纳入全局清缓存。每次进入先读缓存，再自动读取详情、名单、提交列表和全班homework-scores；完整关联后一次发布名单和分数，不按学生逐个查score-records，不由作业已批改人数推断每人成绩。final_score作为最终分数，保留零分；不因滚动、悬停触发网络，也没有新增定时轮询。

界面不要求用户逐人核对。失败不推进完整快照时间或清空缓存，刷新不覆盖正在编辑的值和本页已保存的值。手机沿用缓存先显与自动读取，继续禁止评分/打包写入。HTTP验证使用脱敏fixture，真实服务器的小数保存等仍须按原待验收项报告。

## 2026-11-05 附件显示、评分记录与提交节奏

`student-submissions?need_uploads_size=true`的`submissions[].attachments_size`是已捕获的非负整数字节数，网页模板以其真值显示回形针，并通过humanizeBytes显示大小，假值为“无附件”。原两份样本有正整数及字段缺失，新增非空成绩抓包同时出现attachments_size为null；缺附件的记录仍可已提交。客户端按缺失/零显示无附件，采用1024进制格式化B/KB/MB等；不能从捕获证明网页采用相同进制。旧名单缓存无此字段时保持未知占位，自动刷新后补齐；所有评分更新保留该字段。不由is_redo/is_resubmitted猜new或已读。

成绩框旁的“查看评分记录”直接使用上文已验证的score-records路径，完整读取分页，按created_at再按id倒序。历史显示与写前/写后分数读取共用类型化解析，不将实际操作人、历史时间等信息写入持久缓存或日志；只在授权页面临时展示。关闭弹窗取消自身fork的GET，保留名单会话。

CSV的200–500ms为两次实际保存之间的额外随机等待，不代表请求总间隔恰好在该范围；前后读取、全局队列、限流和服务器响应可能使总耗时更长。首条、单条、跳过行及最后一条结束不额外空等；等待后再次检查停止/身份，停止期间不将未发送行误标成结果不确定。没有降低原限流或自动重发PUT。

共享缓存现在一次合并所有成功分数再写盘，保留完整刷新时间。手动更新明确绕过两分钟读取缓存，但仍保留五秒短节流；成功CSV清掉同学生旧草稿，失败行和其他草稿保持。
