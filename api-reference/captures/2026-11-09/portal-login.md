# portal-login 离线接口结构

> 归档完成日期：2026-11-10（UTC+8）；11月9日开始整理。仅描述历史抓包，没有联网复测。类型标记不是真实字段值。

来源：`登录信息门户.txt`；2,786,958 bytes；SHA-256 `6bea6cebb01fa7d6f3c667121942a3ee0efd7442f11196af7cf948c988ca00a9`。

原文件修改时间：2026-11-05T14:07:55.643497+08:00。服务器 Date 范围：['2026-11-05T14:07:30+08:00', '2026-11-05T14:07:42+08:00']。

共 82 条请求（含 CONNECT），保留业务请求 48 条，排除后台/静态/遥测等 34 条。

参数值、响应标量值和请求头值均未保留。JSON 结构合并所有已解析行；动态键归一化，空数组只证明本样本为空。完整顺序与逐请求时间见同名 JSON 的 timeline。

## 请求顺序

| 导出序号 | 服务器时间 UTC+8 | 请求 | HTTP | 响应类型 |
| --- | --- | --- | --- | --- |
| 5 | 2026-11-05T14:07:30+08:00 | `GET i.xmu.edu.cn/DTMP/` | 200 | html |
| 8 | 2026-11-05T14:07:32+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-list` | 200 | json |
| 9 | 2026-11-05T14:07:32+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-tree/detail` | 200 | json |
| 11 | 2026-11-05T14:07:32+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-front/detail/{id}/{id}` | 200 | json |
| 12 | 2026-11-05T14:07:32+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content/monitor/site` | 200 | json |
| 13 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 14 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 16 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 20 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 21 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 22 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 23 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 24 | 2026-11-05T14:07:33+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 27 | 2026-11-05T14:07:34+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/auth/sso/getConfig` | 200 | json |
| 28 | 2026-11-05T14:07:34+08:00 | `GET ids.xmu.edu.cn/authserver/login` | 200 | html |
| 30 | 2026-11-05T14:07:34+08:00 | `POST ids.xmu.edu.cn/authserver/common/getLanguageTypes.htl` | 200 | json |
| 31 | 2026-11-05T14:07:34+08:00 | `GET ids.xmu.edu.cn/authserver/tenant/info` | 200 | json |
| 33 | 2026-11-05T14:07:34+08:00 | `GET ids.xmu.edu.cn/authserver/qrCode/getToken` | 200 | non-json-body-not-retained |
| 35 | 2026-11-05T14:07:34+08:00 | `GET ids.xmu.edu.cn/authserver/bfp/info` | 200 | empty |
| 36 | 2026-11-05T14:07:35+08:00 | `GET ids.xmu.edu.cn/authserver/qrCode/getCode` | 200 | non-json-body-not-retained |
| 39 | 2026-11-05T14:07:36+08:00 | `GET ids.xmu.edu.cn/authserver/qrCode/getStatus.htl` | 200 | non-json-body-not-retained |
| 40 | 2026-11-05T14:07:36+08:00 | `GET ids.xmu.edu.cn/authserver/checkNeedCaptcha.htl` | 200 | json |
| 42 | 2026-11-05T14:07:37+08:00 | `GET ids.xmu.edu.cn/authserver/qrCode/getStatus.htl` | 200 | non-json-body-not-retained |
| 45 | 2026-11-05T14:07:37+08:00 | `GET ids.xmu.edu.cn/authserver/login` | 200 | html |
| 48 | 2026-11-05T14:07:37+08:00 | `POST ids.xmu.edu.cn/authserver/common/getLanguageTypes.htl` | 200 | json |
| 49 | 2026-11-05T14:07:37+08:00 | `GET ids.xmu.edu.cn/authserver/tenant/info` | 200 | json |
| 50 | 2026-11-05T14:07:37+08:00 | `GET ids.xmu.edu.cn/authserver/bfp/info` | 200 | empty |
| 52 | 2026-11-05T14:07:39+08:00 | `GET ids.xmu.edu.cn/authserver/checkNeedCaptcha.htl` | 200 | json |
| 53 | 2026-11-05T14:07:39+08:00 | `POST ids.xmu.edu.cn/authserver/login` | 302 | empty |
| 55 | 2026-11-05T14:07:39+08:00 | `GET i.xmu.edu.cn/DTMP/authLogin` | 301 | html |
| 57 | 2026-11-05T14:07:39+08:00 | `GET i.xmu.edu.cn/DTMP/authLogin/` | 200 | html |
| 58 | 2026-11-05T14:07:39+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/auth/sso/casLogin` | 200 | json |
| 63 | 2026-11-05T14:07:39+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-list` | 200 | json |
| 65 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-tree/detail` | 200 | json |
| 66 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-front/detail/{id}/{id}` | 200 | json |
| 68 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/content/monitor/site` | 200 | json |
| 70 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/websocket/message` | 101 | empty |
| 71 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/system/user/getInfo` | 200 | json |
| 72 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 73 | 2026-11-05T14:07:41+08:00 | `GET i.xmu.edu.cn/DTMP/prod-api/system/dict/data/type/sys_user_type` | 200 | json |
| 74 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 75 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 76 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 77 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 78 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 79 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 80 | 2026-11-05T14:07:41+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |
| 81 | 2026-11-05T14:07:42+08:00 | `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result` | 200 | json |

## `GET i.xmu.edu.cn/DTMP/`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

## `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-list`

出现 2 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: array; observed lengths=22
$.data[]: object
$.data[].deleteFlag: integer
$.data[].id: string
$.data[].mobileHeaderNavigationFlag: integer | null
$.data[].mobilePersonalizationFlag: integer | null
$.data[].parentId: string
$.data[].pcFooterNavigationFlag: integer | null
$.data[].pcHeaderNavigationFlag: integer | null
$.data[].pcPersonalizationFlag: integer | null
$.data[].publishTime: null | string
$.data[].siteCategoryCode: string
$.data[].siteCategoryDesc: string
$.data[].siteCategoryName: string
$.data[].siteCategoryStatus: integer
$.data[].siteCategoryType: integer
$.data[].siteCategoryUrl: string
$.data[].sort: integer
$.data[].tenantId: string
$.msg: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-tree/detail`

出现 2 次；HTTP：`200`。

查询参数名：`siteCategoryId`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: object
$.data.catalogInfo: null
$.data.createBy: string
$.data.createByName: null
$.data.createTime: null
$.data.id: string
$.data.pageInfo: object
$.data.pageInfo.authScope: string
$.data.pageInfo.checkLoginFlag: integer
$.data.pageInfo.digestAlgorithmKey: string
$.data.pageInfo.id: string
$.data.pageInfo.mobileHeaderNavigationFlag: integer
$.data.pageInfo.mobilePersonalizationFlag: integer
$.data.pageInfo.newSitePageCode: string
$.data.pageInfo.newSitePageCodeMobile: string
$.data.pageInfo.newSitePageHtml: string
$.data.pageInfo.newSitePageHtmlMobile: string
$.data.pageInfo.newSitePageSchema: string
$.data.pageInfo.newSitePageSchemaMobile: string
$.data.pageInfo.pageCatalogPath: string
$.data.pageInfo.pageCode: string
$.data.pageInfo.pageName: string
$.data.pageInfo.pageShortName: string
$.data.pageInfo.pageSuffix: string
$.data.pageInfo.pageType: integer
$.data.pageInfo.pageUrl: string
$.data.pageInfo.pcFooterNavigationFlag: integer
$.data.pageInfo.pcHeaderNavigationFlag: integer
$.data.pageInfo.pcPersonalizationFlag: integer
$.data.pageInfo.publishStatus: integer
$.data.pageInfo.publishTime: string
$.data.pageInfo.selectorInfos: null
$.data.pageInfo.seoDescriptions: null
$.data.pageInfo.seoKeywords: null
$.data.pageInfo.siteCategoryId: string
$.data.pageInfo.siteInfoId: string
$.data.pageInfo.siteInfoName: string
$.data.pageInfo.sitePageCode: string
$.data.pageInfo.sitePageCodeMobile: string
$.data.pageInfo.sitePageComponent: integer
$.data.pageInfo.sitePageHtml: string
$.data.pageInfo.sitePageHtmlMobile: string
$.data.pageInfo.sitePageSchema: string
$.data.pageInfo.sitePageSchemaMobile: string
$.data.pageInfo.suitableUserType: string
$.data.pageInfo.tenantId: string
$.data.pageInfo.userAuthStatus: integer
$.data.parentId: string
$.data.publishTime: string
$.data.siteCategoryCode: string
$.data.siteCategoryDesc: string
$.data.siteCategoryName: string
$.data.siteCategoryStatus: integer
$.data.siteCategoryType: integer
$.data.siteCategoryUrl: string
$.data.siteInfo: null
$.data.sort: integer
$.data.tenantId: string
$.data.updateTime: null
$.msg: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/content-front/site/site-front/detail/{id}/{id}`

出现 2 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: object
$.data.catalogInfo: null
$.data.createBy: string
$.data.createByName: null
$.data.createTime: null
$.data.id: string
$.data.pageInfo: object
$.data.pageInfo.authScope: string
$.data.pageInfo.checkLoginFlag: integer
$.data.pageInfo.digestAlgorithmKey: string
$.data.pageInfo.id: string
$.data.pageInfo.mobileHeaderNavigationFlag: integer
$.data.pageInfo.mobilePersonalizationFlag: integer
$.data.pageInfo.newSitePageCode: null
$.data.pageInfo.newSitePageCodeMobile: null
$.data.pageInfo.newSitePageHtml: null
$.data.pageInfo.newSitePageHtmlMobile: null
$.data.pageInfo.newSitePageSchema: null
$.data.pageInfo.newSitePageSchemaMobile: null
$.data.pageInfo.pageCatalogPath: string
$.data.pageInfo.pageCode: string
$.data.pageInfo.pageName: string
$.data.pageInfo.pageShortName: string
$.data.pageInfo.pageSuffix: string
$.data.pageInfo.pageType: integer
$.data.pageInfo.pageUrl: string
$.data.pageInfo.pcFooterNavigationFlag: integer
$.data.pageInfo.pcHeaderNavigationFlag: integer
$.data.pageInfo.pcPersonalizationFlag: integer
$.data.pageInfo.publishStatus: integer
$.data.pageInfo.publishTime: string
$.data.pageInfo.selectorInfos: null
$.data.pageInfo.seoDescriptions: null
$.data.pageInfo.seoKeywords: null
$.data.pageInfo.siteCategoryId: string
$.data.pageInfo.siteInfoId: string
$.data.pageInfo.siteInfoName: string
$.data.pageInfo.sitePageCode: string
$.data.pageInfo.sitePageCodeMobile: string
$.data.pageInfo.sitePageComponent: integer
$.data.pageInfo.sitePageHtml: string
$.data.pageInfo.sitePageHtmlMobile: string
$.data.pageInfo.sitePageSchema: string
$.data.pageInfo.sitePageSchemaMobile: string
$.data.pageInfo.suitableUserType: string
$.data.pageInfo.tenantId: string
$.data.pageInfo.userAuthStatus: integer
$.data.parentId: string
$.data.publishTime: string
$.data.siteCategoryCode: string
$.data.siteCategoryDesc: string
$.data.siteCategoryName: string
$.data.siteCategoryStatus: integer
$.data.siteCategoryType: integer
$.data.siteCategoryUrl: string
$.data.siteInfo: object
$.data.siteInfo.childSiteFlag: integer
$.data.siteInfo.createBy: string
$.data.siteInfo.createByName: null
$.data.siteInfo.createTime: null
$.data.siteInfo.defaultFlag: integer
$.data.siteInfo.globalMessageFlag: null
$.data.siteInfo.icpRecordNumber: null
$.data.siteInfo.icpRecordNumberPrefix: null
$.data.siteInfo.icpRecordNumberUrl: null
$.data.siteInfo.id: string
$.data.siteInfo.parentSiteCategoryId: null
$.data.siteInfo.pcFooterNavigationScript: string
$.data.siteInfo.pcHeaderNavigationScript: string
$.data.siteInfo.protocolType: string
$.data.siteInfo.publicNavigationScript: string
$.data.siteInfo.siteAdmins: null
$.data.siteInfo.siteCatalogPath: string
$.data.siteInfo.siteCategoryId: string
$.data.siteInfo.siteCode: string
$.data.siteInfo.siteDomain: string
$.data.siteInfo.siteIndexCode: null
$.data.siteInfo.siteLogo: string
$.data.siteInfo.siteName: string
$.data.siteInfo.siteShortName: string
$.data.siteInfo.siteSuffix: null
$.data.siteInfo.siteTemplateId: string
$.data.siteInfo.siteTemplateName: string
$.data.siteInfo.tenantId: string
$.data.siteInfo.themeColorFlag: integer
$.data.siteInfo.themeColorValue: string
$.data.siteInfo.updateTime: null
$.data.siteInfo.wholeSiteFlag: integer
$.data.sort: integer
$.data.tenantId: string
$.data.updateTime: null
$.msg: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/content/monitor/site`

出现 2 次；HTTP：`200`。

查询参数名：`siteId`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: null
$.msg: null
```

## `POST i.xmu.edu.cn/DTMP/prod-api/content-front/data-set/api-result`

出现 17 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：`application/json`；响应类型：`application/json`。

响应解析：`{"json": 17}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

请求 JSON / JSON 内嵌参数结构：

```text
$: object
$.dataSetLabel: string
$.params: array; observed lengths=0,2
$.params[]: object
$.params[].key: string
$.params[].value: integer
```

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: object
$.data.dataResult: array; observed lengths=1,10,20
$.data.dataResult[]: object
$.data.dataResult[].author: string
$.data.dataResult[].code: integer
$.data.dataResult[].data: array | integer | object; observed lengths=5,10,15
$.data.dataResult[].data.rows: array; observed lengths=5,8
$.data.dataResult[].data.rows[]: object
$.data.dataResult[].data.rows[].createBy: string
$.data.dataResult[].data.rows[].createTime: string
$.data.dataResult[].data.rows[].dept: string
$.data.dataResult[].data.rows[].icon: string
$.data.dataResult[].data.rows[].id: string
$.data.dataResult[].data.rows[].isCollect: integer
$.data.dataResult[].data.rows[].mobileUrl: string
$.data.dataResult[].data.rows[].name: string
$.data.dataResult[].data.rows[].pcUrl: string
$.data.dataResult[].data.rows[].title: string
$.data.dataResult[].data.rows[].type: null
$.data.dataResult[].data.total: integer
$.data.dataResult[].data[]: object
$.data.dataResult[].data[].createTime: string
$.data.dataResult[].data[].favorFlag: boolean
$.data.dataResult[].data[].icon: string
$.data.dataResult[].data[].id: null
$.data.dataResult[].data[].keyword: string
$.data.dataResult[].data[].serviceId: string
$.data.dataResult[].data[].serviceName: string
$.data.dataResult[].data[].visitsNum: integer
$.data.dataResult[].description: string
$.data.dataResult[].link: string
$.data.dataResult[].msg: string
$.data.dataResult[].pubDate: string
$.data.dataResult[].title: string
$.data.dataSetFields: array; observed lengths=0
$.data.dataSetId: string
$.data.dataSetLabel: string
$.data.dataSetName: string
$.data.dataSetType: string
$.msg: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/auth/sso/getConfig`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.enabled: boolean
$.mobileEnabled: boolean
$.mobileRedirectUrl: string
$.msg: string
$.pcRedirectUrl: string
$.ssoLoginUrl: string
$.ssoLogoutUrl: string
```

## `GET ids.xmu.edu.cn/authserver/login`

出现 2 次；HTTP：`200`。

查询参数名：`service, type`；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 2}`。

HTML 输入字段名：`_eventId, captcha, cllt, dllt, dynamicCode, execution, lt, password, passwordText, responseJson, rmShown, username, uuid`。

## `POST ids.xmu.edu.cn/authserver/common/getLanguageTypes.htl`

出现 2 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

响应 JSON 结构：

```text
$: object
$.languageTypeList: array; observed lengths=2
$.languageTypeList[]: object
$.languageTypeList[].isChoose: integer
$.languageTypeList[].isDefault: null
$.languageTypeList[].isDelete: null
$.languageTypeList[].isUserLanguage: integer
$.languageTypeList[].languageKey: string
$.languageTypeList[].languageName: string
$.languageTypeList[].wid: string
```

## `GET ids.xmu.edu.cn/authserver/tenant/info`

出现 2 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

响应 JSON 结构：

```text
$: object
$.mobileFlay: boolean
$.schoolBgUrlMobile: string
$.schoolBgUrlPc: string
$.schoolLogoUrlMobile: string
$.schoolLogoUrlPc: string
$.themeColorMode: string
$.themeName: string
```

## `GET ids.xmu.edu.cn/authserver/qrCode/getToken`

出现 1 次；HTTP：`200`。

查询参数名：`ts`；表单字段名：``。

请求类型：``；响应类型：`text/plain`。

响应解析：`{"non-json-body-not-retained": 1}`。

## `GET ids.xmu.edu.cn/authserver/bfp/info`

出现 2 次；HTTP：`200`。

查询参数名：`_, bfp`；表单字段名：``。

请求类型：``；响应类型：``。

响应解析：`{"empty": 2}`。

## `GET ids.xmu.edu.cn/authserver/qrCode/getCode`

出现 1 次；HTTP：`200`。

查询参数名：`uuid`；表单字段名：``。

请求类型：``；响应类型：`image/png`。

响应解析：`{"non-json-body-not-retained": 1}`。

## `GET ids.xmu.edu.cn/authserver/qrCode/getStatus.htl`

出现 2 次；HTTP：`200`。

查询参数名：`ts, uuid`；表单字段名：``。

请求类型：``；响应类型：`text/plain`。

响应解析：`{"non-json-body-not-retained": 2}`。

## `GET ids.xmu.edu.cn/authserver/checkNeedCaptcha.htl`

出现 2 次；HTTP：`200`。

查询参数名：`_, username`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 2}`。

响应 JSON 结构：

```text
$: object
$.isNeed: boolean
```

## `POST ids.xmu.edu.cn/authserver/login`

出现 1 次；HTTP：`302`。

查询参数名：`service`；表单字段名：`_eventId, captcha, cllt, dllt, execution, lt, password, username`。

请求类型：`application/x-www-form-urlencoded`；响应类型：``。

响应解析：`{"empty": 1}`。

重定向（不含参数值）：`i.xmu.edu.cn/DTMP/authLogin [query: ticket]`。

## `GET i.xmu.edu.cn/DTMP/authLogin`

出现 1 次；HTTP：`301`。

查询参数名：`ticket`；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

重定向（不含参数值）：`i.xmu.edu.cn/DTMP/authLogin/ [query: ticket]`。

## `GET i.xmu.edu.cn/DTMP/authLogin/`

出现 1 次；HTTP：`200`。

查询参数名：`ticket`；表单字段名：``。

请求类型：``；响应类型：`text/html`。

响应解析：`{"html": 1}`。

## `GET i.xmu.edu.cn/DTMP/prod-api/auth/sso/casLogin`

出现 1 次；HTTP：`200`。

查询参数名：`ticket`；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: object
$.data.access_token: string
$.data.expires_in: integer
$.msg: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/websocket/message`

出现 1 次；HTTP：`101`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：``。

响应解析：`{"empty": 1}`。

## `GET i.xmu.edu.cn/DTMP/prod-api/system/user/getInfo`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

响应 JSON 结构：

```text
$: object
$.currentRole: object
$.currentRole.describe: string
$.currentRole.displayOrder: integer
$.currentRole.id: string
$.currentRole.managePerms: string
$.currentRole.roleCode: string
$.currentRole.roleName: string
$.currentRole.selectorNum: null
$.managePerms: string
$.permissions: array; observed lengths=0
$.user: object
$.user.email: null
$.user.gender: string
$.user.orgCode: string
$.user.orgName: string
$.user.telephone: null
$.user.userCode: string
$.user.userName: string
$.user.userType: string
```

## `GET i.xmu.edu.cn/DTMP/prod-api/system/dict/data/type/sys_user_type`

出现 1 次；HTTP：`200`。

查询参数名：``；表单字段名：``。

请求类型：``；响应类型：`application/json`。

响应解析：`{"json": 1}`。

已观察的根级协议标记（仅白名单状态值，不代表所有业务都成功）：`{"code": ["200"]}`。

响应 JSON 结构：

```text
$: object
$.code: integer
$.data: array; observed lengths=2
$.data[]: object
$.data[].createBy: string
$.data[].createTime: string
$.data[].cssClass: null
$.data[].dictCode: integer
$.data[].dictLabel: string
$.data[].dictSort: integer
$.data[].dictType: string
$.data[].dictValue: string
$.data[].isDefault: null
$.data[].listClass: string
$.data[].remark: null
$.data[].searchValue: null
$.data[].status: string
$.data[].updateBy: null
$.data[].updateTime: null
$.msg: string
```
