# 智慧后勤（原生查询与办理）

官方域名 `xdhq.xmu.edu.cn`。2026-11-25 分别用本人本科、研究生账号验证，生产 `LogisticsClient` 的 Dart 联网结果分别为报修/消息 0/0、1/1。个人原始响应、截图、Cookie 和登录中间值只留本机忽略目录，不作为样本提交。

## 登录与身份

- IDS service 为 `https://xdhq.xmu.edu.cn/cass/login`。官方 account 配置的 `casUrl` 之后由前端追加 `/login`，因此不能直接使用 `/cass`。
- 一次正常 IDS 提交后跟随 HTTPS 重定向；桌面回到 `/account/login?userinfo=...`，项目现有 UA 回到 `/appAccount/login?userinfo=...`。
- 将回调参数交给 `POST /api/auth/login/auto`，表单字段 `userInfo/clientId/timestamp/schoolCode/schoolName`。不落盘此参数或响应令牌。
- `GET /api/auth/user/info` 的 `account/unifiedAccount` 须与所选凭据身份相符，再读取业务数据。API 使用独立 CookieJar，绝不转发 TronClass Authorization。
- 后续请求沿官方 TokenKey 和 Token 头；Token 包含 tokenKey、clientId、毫秒 timestamp 和本次请求 GUID。公开客户端的 AES 参数取自官方 account/ihome JS；它们是前端协议参数，不是个人凭据。所有会话值仅驻内存，日志不输出 URL query、请求体与响应体。
- 需要验证码时停止自动提交，交由用户正常登录；不循环重登。

## 已验证的读取协议

响应正文为 Base64 AES/CBC/PKCS7，按官方 `znbx/js/dencrypt.js` 解码。正常业务信封为 `status=success, errorCode=0, data=...`，HTTP 200 不等于业务成功。

| 请求 | 表单 | 返回及用途 |
| --- | --- | --- |
| POST `/api/repair/oneNetPublish/myList` | pageNum、pageSize | data.total / rows；本人的工单列表，响应已包含 logs、项目、描述、地点和服务单位 |
| POST `/api/manager/systemPersonalWait/listMessage` | pageIndex、pageSize | data.total / rows；title、content、sendTime、status；实样 status=0 为未读 |

首屏只读两批数据：报修20条、最近消息6条；报修按显式加载更多翻页，不逐单调用详情接口。111条回归为6次列表请求和1次消息请求。列表内已含报修/审核/派工/完工日志，打开详情时再读一条本人详情和撤销资格，以取得列表缺少的收费、维修前后附件、评价与撤销状态；不在列表中逐单补查。

工单 `ifComplete=1` 为完成，实样 `ifCommont=0` 为尚未评价；未知状态优先保留日志的 statusName，无日志时标明待核对。不根据“已完工”推断已评价。

## 表单与详情读取

以 `/api` 为前缀，均使用已核身份的后勤会话：

| 请求 | 参数与响应 |
| --- | --- |
| `/repair/publish/getAreaTree` | 区域树，节点 id/name/children；本次研究生实样展开364个楼栋叶节点 |
| `/repair/publish/getProjectByAreaId` | areaId；项目树 value/label/children，已核区域返回39个叶项目 |
| `/repair/systemSetting/list` | 动态配置；011的数组含6要求图片，014控制无人维修选项，521控制低分返修 |
| `/repair/publish/getAcceptUserByAreaIdAndProjectId` | areaId/projectId；dept.deptId/deptName/payName 与受理人 |
| `/repair/oneNetPublish/checkIfHadProjectIdByAreaId` | 提交前再次检查楼栋与项目的服务关系 |
| `/repair/repairInfo/get` | id；logVOS、finishedInfo、resourcesVOS、收费、维修前后附件 |
| `/repair/myRepair/ifAllowWithdrawMyRepair` | id；data=1才显示并允许执行撤销，提交前重新核对 |
| `/repair/commontProject/getProject`、`getLabel` | 评价项目及标签，保留服务器 id/name/weight；star由用户选择 |
| `/supervise/systemServiceScope/getScopeTree` | isShowNoDept=0；反馈范围树 id/name/children，保留完整路径ID与叶名称 |
| `/supervise/supervisionPost/queryServiceType` | 咨询2、建议1、表扬3、投诉0，界面采用服务器名称和顺序 |
| `/supervise/oneNet/selectMyPublishPost` | pageIndex/pageSize；本人反馈 total/rows，含 ifDelete 和 replyCount |
| `/supervise/oneNet/get`、`replayList` | id或postId、schoolCode；本人详情与回复 total/rows；部门回复 ifOfficial=1，排除status=2 |

## 原生提交

| 请求 | 编码与提交内容 |
| --- | --- |
| `/repair/publish/publish` | JSON；与官方表单一致的type/ifShielding/areaId/areaName/address/addressDetail/projectId/projectName/repairUserName/repairUserMobile/repairNum/content/ifPublish/ifOnduty/source/ifRecord/resourcesVOS；受理单位由提交前查询的dept补入 |
| `/repair/myRepair/withdrawMyRepair` | 表单id；服务器资格为准，提交后核对最新详情，不乐观删除本地记录 |
| `/repair/visitEvaluateUser/save` | JSON；common为原评价项目加star，content/repairId/source/label；低分可能触发返修，提交前明确确认 |
| `/supervise/supervisionPost/save` | JSON；postTitle/content、projectName路径ID数组、serviceScopeId叶ID、serviceScopeName叶名称、serverType、images、ifAccept/source/keyWords；本人ID/姓名从会话取得，phone沿官方客户端参数AES加密 |
| `/supervise/supervisionPost/deleteByIdByStudent` | 表单postId/remark；服务器软删除，ifDelete=1的本人历史保留并标为已删除 |
| `/manager/systemPersonalWait/statusMessage` | 表单status=0/id；仅用户明确点击标为已读时调用，不自动清空未读 |
| `/file/upload` | 原生multipart，file和system=manager；此端点响应为明文JSON，data.path用于附件关联；最多3件，反馈仅图片，报修可含视频 |

所有业务操作在原生页面完成，不打开官方业务网页或系统浏览器。列表、详情和表单按身份隔离，切换身份关闭旧页面。单次写入期间禁用再次提交；超时或损坏回执不自动重放，显示结果未确认并引导核对记录。提交成功后刷新对应记录，不能用旧缓存授权撤销或评价。

## 本次验证与范围

- 用户明确授权后，使用研究生身份真实发布1条标注接口联调、请勿办理的测试建议并立即删除；原生Dart随后读取本人列表及详情，均确认ifDelete=1。软删除不会抹除本人历史。
- 已用原生Dart实读364个楼栋、39个区域项目、36个反馈范围及4类反馈。常用空/非空工单与消息仍分别核对两个身份。
- 报修提交已通过官方表单校验与受理查询，最终publish请求在本机拦截采集，未创建维修工单。未对已有真实工单提交评价。
- 撤销报修、评分、原生上传和消息已读以生产HTTP适配器/交互回归验证协议；不宣称完成这些操作的真人服务端写入验收。部门回复与非空附件用已核前端字段组合测试，当前本人样本无此类非空实测。
- 原始抓包、测试单据标识、个人资料和凭据留本机忽略目录，不进入Git或公开测试样本。Windows原生窗口、Android/iOS真机仍单独验收。
