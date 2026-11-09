# 信息门户与 IDS 登录观察

观察：2026-11-05 14:07:30—14:07:42（UTC+8，HTTP Date）；整理：2026-11-09。来源为一份授权的浏览器 HTTP 导出。这里只保存协议结构，没有重放会话；不承诺协议目前仍可用。

完整参数、字段类型、重定向与请求顺序见[结构清单](captures/2026-11-09/portal-login.md)及[机器可读记录](captures/2026-11-09/portal-login.json)。

## 观察到的链路

1. `GET i.xmu.edu.cn/DTMP/` 打开门户，读取 `site-list`、`site-tree/detail`、`site-front/detail/{id}/{id}`。未登录页也有内容查询，不能用页面存在判断认证成功。
2. `GET /DTMP/prod-api/auth/sso/getConfig` 读取 SSO 配置；随后进入 `ids.xmu.edu.cn/authserver/login`。登录页 `service` 等查询值不保留。
3. IDS 读取语言、租户、浏览器相关信息、二维码 token/二维码及 `getStatus.htl`，并调用 `checkNeedCaptcha.htl`。二维码与 token 是会话材料，不归档；请求发生不等于扫码登录成功，也不据此推导轮询频率。
4. `POST /authserver/login` 使用表单字段 `username`、`password`、`captcha`、`execution`、`lt`、`_eventId`、`cllt`、`dllt`，观察到 302。密码是浏览器当时提交的字段，本文没有保存其值、加密实现或可复用表单状态。
5. 浏览器经 `/DTMP/authLogin` 及尾斜线页面回跳，再请求 `/DTMP/prod-api/auth/sso/casLogin`；CAS 票据只用于该目标服务，不能当畅课令牌复用。
6. 门户随后读取 `/DTMP/prod-api/system/user/getInfo`、用户类型字典及数据集内容。身份、组织、服务收藏、个人偏好等只保留字段结构。

## 数据集与解析边界

`POST /DTMP/prod-api/content-front/data-set/api-result` 在样本出现 17 次。请求根字段为 `dataSetLabel: string`、`params: array`；参数元素为 `key: string`、`value: integer`，观测到空参数数组和两项参数数组。

响应根字段包括 `code`、`msg`、`data`，其中 `data` 含 `dataResult`、`dataSetFields` 及数据集标识/名称。不同数据集的 `dataResult[].data` 可为数组、对象或整数，部分对象再包含 `rows` 和 `total`；不能把所有门户组件强制解析成同一个列表。资料合并类型、不保留数据集标签值与具体内容，因此不能据本文件恢复每个门户组件的配置。

本样本没有证明门户全量服务、不同身份可见性、会话有效期、验证码算法或研究生成绩查询协议。二维码响应是图片，部分状态响应为纯文本；不把它们当 JSON。认证实现仍须使用本人正常登录和目标服务实际授权。
