# 智慧后勤（只读接入）

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

首屏只读两批数据：报修20条、最近消息6条；报修按显式加载更多翻页，不逐单调用详情接口。111条回归为6次列表请求和1次消息请求。列表内已含报修/审核/派工/完工日志，原生详情直接复用，避免重复请求。

工单 `ifComplete=1` 为完成，实样 `ifCommont=0` 为尚未评价；未知状态优先保留日志的 statusName，无日志时标明待核对。不根据“已完工”推断已评价。

## 官方办理入口

以 `/ihome/` 为前缀：`repairCatalogue`（报修）、`myRepairList`（本人报修与评价）、`service/catalogue`（咨询/建议/表扬/投诉）、`service/myService`（本人反馈）、`messageList`（消息）。沿用系统浏览器/Windows隔离内置网页偏好；系统浏览器使用自己的登录状态，不能承诺与App身份自动相同。

原生最近消息只读，不标记已读。没有实现或调用提交报修、评价、撤回、发帖、上传或清除未读接口。官方网页中的业务提交由用户操作。
