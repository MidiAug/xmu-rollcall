## 2026-11-03 真实最小桌面窗口保持地图目录

[PASS] AC-ATLAS-MIN-DESKTOP：原规则仅按地图页宽度小于800切手机布局；900x640整窗扣除现有软件主导航后，地图页仅756宽，导致此前的900宽独立页面测试漏掉折叠。改为桌面平台始终保留校园地图内部侧栏，手机窄屏仍为底部目录；弹性200至280规则不变，软件主导航及课程地点地图均未改。
新增使用AppLayout.minimumWindowSize、sidebarWidthOf和标题栏占位的浅深组件回归，确认实际页面不足800、内部目录为200且没有底部目录按钮；它是扣除外框的布局夹具，不是真实App Shell或原生窗口自动化。实际查看build/campus-atlas-review/minimum-window-false.png及true.png；底图在测试中未联网加载。
验证：4份相关测试39项通过（build/atlas-no-collapse-tests.log），flutter analyze无问题（build/atlas-no-collapse-analyze.log）。已有手机320/390和课程地点回归同时通过。热更新另记运行回执，无正式发布。
## 2026-11-03 校园地图内部目录弹性宽度与相机稳定验收

[PASS] AC-ATLAS-INNER-WIDTH：只改工具Tab校园地图内的搜索/楼群/楼宇目录栏，以页面可用宽度24%布局并限制200至280。280为最大值；1200/900/1500页面连续调整分别验证280/216/280，无溢出。软件最左侧签到/作业/课表/工具导航及设置里的课程地点地图均未改。
[PASS] AC-ATLAS-STILL-CAMERA：地图标记点击（楼群、楼宇、分区）和当前楼宇分区切换只更新选中高亮、介绍和目录，不改变相机中心或缩放。目录点击仍表示主动定位，保留导航至目标的行为。连续选两个地图楼群及两个学武楼分区验证中心/缩放保持；既有目录选点及定位回归通过。

验证：4份相关测试共37项通过，flutter analyze无问题；日志build/atlas-stable-camera-tests.log、atlas-stable-camera-analyze.log。组件截图已实看，瓦片在测试中未联网；不称在线地图/真机验收。改动仅CampusAtlasPage及对应测试/文档，无App Shell或共享地图改动。提交后热重载另验证调试会话回执。
## 2026-11-03 校园地图单列目录与建筑故事验收

[PASS] AC-ATLAS-COMPACT：仅工具Tab校园地图改为280宽单列逐级目录，全部/其他/楼群进入楼宇列表并可返回；搜索跨列表。其他楼宇是列表合集，没有相机目标、面域或合并标记，点击集合不改变相机中心，选择单楼仍各自定位。
[PASS] AC-ATLAS-LEVEL18：仅CampusAtlasPage将分区门槛19改18，楼宇层保持17；选有分区楼宇进入18.2，无分区进入17.3以维持楼宇层。共享CampusMap、设置课程地点页面、匹配器与源目录均未改动。连续缩放往返与设置地点流程回归通过。
[PASS] AC-ATLAS-STORIES：选中卡改简短建筑介绍及校方资料链接，分区明确展示所属楼宇简介；资料随App保存，点击卡不自动联网。33份单楼简介、14份楼群/片区故事，18个校方来源，按稳定ID覆盖三校区143处楼宇中的58处（含25处明确标记的片区背景），剩余85处提示资料待补充，不冒充校史全覆盖。机构成立、落成典礼、建成和冠名日期分开，片区故事不冒作单楼建成年代。同名思明/翔安成义楼不会互串。

来源在lib/features/location/campus_stories.dart逐条关联URL，2026-11-03联网核对；包括庄汉水楼1988建成/2011冠名，群贤1921奠基/1922落成、建南1951至1954、嘉庚1998开工/2001竣工、翔安2014落成典礼、西部片区2021命名公示、德旺图书馆2014使用/2016揭牌、漳州从楼2003/主楼2005等。个别无单楼史料只介绍所在片区，校方资料由用户主动点击在浏览器打开；未请求账号、课表或设备定位数据。

验证：4份相关测试35项通过（build/atlas-story-final-tests.log），flutter analyze无问题（build/atlas-story-final-analyze.log）。实看1200浅色庄汉水简介与窄目录、320深色学武A区父楼简介，及浅深截图；空底图为测试未联网加载瓦片，不称在线地图/真机验收。热更新另记录运行回执；无正式发布。
## 2026-11-03 校园地图目录与标签避让验收

[PASS] AC-ATLAS-DIRECTORY：搜索下移除数量行；桌面左列164宽、名称单行省略，右侧24宽数字列。independent-*维护桶不再作为分组或聚合标记，未归组楼宇直接拥有入口与点，源目录及匹配归属不改。
[PASS] AC-ATLAS-AREA：沿用已维护多边形，普通地块填色7.5%、边框55%/1.5，选中19%、边框95%/2.5；无维护轮廓不造边界。侧栏选择保持定位/高亮，地图按实际缩放小于17楼群、17至19楼宇、19起独立分区切换；选组后缩小再放大回归通过，当前相机值避免迟到缩放回调覆盖新层级。
[PASS] AC-ATLAS-LABELS：校园地图按屏幕空间矩形贪心避让，选中标签优先，范围外剔除，四周4px间隙；放大、平移、窗口变化后重算，只隐藏标签，目录仍完整。不添加聚类依赖。标签测量在相机外，既有课程地图的分组/平移复用行为保留；完整名称不重复弹同名提示，截断由AppTruncatedText提供全文。
[PASS] AC-RADAR-COMPACT：失败提示从420x220改360x190、内边距20，消息可滚动；选点图仍使用大地图弹窗。原有取消/重选、提交锁定与身份回归通过。

验证：5份相关测试共42项通过（build/atlas-refinement-final-tests.log），flutter analyze无问题（build/atlas-refinement-analyze.log）。新增真实目录缩放往返、地块强度、单行数字列、无虚构收纳，以及相邻点避让/选中优先/放大恢复和非重叠矩形断言。实看浅色总览、深色选组、多边形填色与边界、手机区域选择和紧凑失败提示PNG；截图build/campus-atlas-review/overview-refined-false.png、group-refined-true.png及build/radar-interaction-review/failure-1100.0-false.png。测试在线瓦片未加载，此为空底图组件证据，不称真机/真网地图验收。未替换用户运行窗口、未发布正式包。
## 2026-11-03 值守反馈与雷达地图弹窗

[PASS] AC-RADAR-DIALOG：签到卡缺位置直接打开圆角地图弹窗；当前业务身份学院决定默认校区，未知学院沿用课表/个人地点推断；地图可拖动和点击，未点选不提交，左坐标右签到。底部签到是本次明确确认，不二次弹确认。地图边界同三个校区浏览范围。
[PASS] AC-RADAR-RESULT：明确位置拒绝在同一卡片动画变为错误提示，重选保留上一点供调整，取消关闭。已有预设被拒绝先提示再直接选点，进弹窗不重提被拒绝点；成功关闭回原卡并立即显示已签到。提交中锁定地图、按钮和关闭；网络失败不会显示地点错误；账号切换后的迟到结果不改原任务和地点记忆。未知课次不扩散保存到整门课，继续保留原账号/课次边界。
[PASS] AC-WATCH-FEEDBACK：运行/启动期间点击值守课程和模式开关提示先暂停/稍候，不改运行范围；暂停后课程入口可用。完整探查、检测间隔、自动签到原本允许运行时调整，保持原行为。加载和未登录的禁用没有伪装成可操作状态。
[PASS] AC-ATLAS-READONLY：区域选择只高亮原标签，无额外选点图钉；签到卡长课程名复用单行省略及截断提示。

验证：13个相关测试文件共111项通过，flutter analyze无问题。含真实Repository+HTTP适配器的400/403/422明确scope拒绝、普通403/401/429/500原异常路径，桌面/Android组件签到成功/失败、主号/协助已有回归、三校区、320大字、390/1100浅深色截图。实看build/radar-interaction-review的桌面浅色选点、手机深色选点/失败、320大字，以及campus-atlas-review手机区域选择；测试HTTP瓦片为400，空底图仅为组件证据，不称真机或在线地图验收，未执行真实签到。

额外检查rollcall_feedback_test存在5项旧结构断言失败（桌面旧按钮名、旧菜单和已完成卡人数控件移除）；在fa3c3c0隔离工作区同样5项同名用例失败，本轮未改这些旧断言。日志build/radar-interaction-final-regression.log、radar-interaction-final-analyze.log、feedback-baseline-tests.log。没有替换当前运行窗口或发布正式包。

协议依据：只采用公开实现的明确错误码radar_out_of_rollcall_scope，不采用距离搜索或猜测经纬度。来源https://github.com/hot-YUser/auto-rollcall-thu-tronclass/blob/main/troTHU/runtime_helpers.py（2026-11-03联网读取）和现有reference副本；厦大服务不是每次都返回距离/可识别原因，不把其他失败归咎于地点。Engineering三层检索未命中本协议，不回写跨项目知识。
## 2026-11-03 地点地图性能与只读校园地图验证

地点管理仅传入当前身份的课表匹配点及必要校正点，空课表没有全目录标记。平移复用标记列表和已计算楼宇中心；192点、每组4次中心读取的相同派生复现，热身后3次1924/1972/2126ms降至38/27/28ms，不是FPS测量。地图中心限制在三校区周边，最小缩放12。
校园地图按导出目录的楼群归属和区域轮廓只读浏览；工具和搜索均可进入。桌面双列侧栏，手机底部目录、搜索键盘避让及就近分区切换。按校区适配全部维护点和区域，缩放分楼群/楼宇/分区层级，只有层级变化才更新描述。
验证：48项地点/绑定/工具/搜索聚焦回归通过；之后8项三校区及320/390/1100浅深组件渲染通过，已实看桌面浅色及手机深色PNG。组件HTTP在测试环境返回400，无在线底图实机验收；未测Android真机。最终flutter analyze无问题。截图build/campus-atlas-review，复现计时build/map-derivation-before.json及after.json。原生截图接口未可靠取得目标画面，本轮视觉证据以组件渲染为准。

### 2026-10-29 本轮Android交付

最终源码`8f53c59`构建release成功，81.3MB（`build/mobile-signin-release.log`），更新`dist/xmu-rollcall-0.3.0-android.apk`，包名和0.3.0+6不变；apksigner验证通过，证书SHA-256与前次安装相同。构建时ADB无连接设备，本轮未覆盖安装或执行真机交互验收，也未向真实课堂提交签到。下面的截图与回归分别是隔离呈现和网络边界替身证据，不能替代真实设备/线上提交验收。

## 2026-10-29 用户授权的已知输入直接签到

用户本轮明确授权：Android数字签到已有有效码时，点“去签到”直接提交，不再进入二级确认；无有效码仍进入手填。雷达先取当前账号/课程/课次有效配置或成功记忆；否则仅用同一活动时间窗口内、唯一课程地点匹配出的未拒绝点。活动时间沿用radarActivityReferenceTime，不把页面当前/下一节课地点误用于另一课次。缺点、已拒绝或时间/归属不明确时才进入位置补充页。

点击是本次用户主动提交，不修改后台自动签到开关、去重/限流或稳定deviceId。雷达仍走同一repository及位置校验，排队发送前复核身份、活动及点位；旧响应不覆盖已改变的点位错误。成功记忆仍限定原账号及课次，不把未知/跨账号/旧课程通用坐标自动升级为授权。二维码及手动补充页的既有流程不变。

服务器确认成功后立即按owner/target/activity标记本地完成，列表随后返回旧状态也不能再次提交。Android任务卡恢复现有已签到人数组件，未完成时沿原间隔更新，完成后取一次最终人数并停止后续轮询；切后台/隐藏/暂停和人数限流沿用原逻辑，不引入1Hz网络请求。

验证：`mobile-signin-verified-tests.log`相关122项通过；后续整体界面/位置回归87项、活动范围聚焦29项及最终提交/人数25项通过；`mobile-signin-final-analyze.log`无问题。新生产组件回归用网络repository边界替身覆盖：数字、显式位置、同课次成功记忆、课表匹配位置直接提交且无二级页/确认框；无位置/拒绝点/另一时间段地点进入补充页；排队中账号/点位改变提交数为0；请求进行中按钮禁用；服务器成功但列表不更新时仍显示已签到，人数最终更新后推进40秒不再轮询。保留原自动签到、人数暂停、历史/身份回归。

本轮没有调用真实签到接口，没有把fixture成功当作真实提交；真机交互与安装另记。新入口继续使用原HTTP/存储真身，没有新增协议、凭据或位置授权存储格式。

## 2026-10-29 Android签到反馈与个人区修订

Android下拉确认后，空列表显示“暂无正在签到的课程”；离开/重选签到Tab或切换账号清除这条本页临时结果。刷新失败显示“暂时无法确认签到状态”，不能沿用上一次的无签到结论；正常未检测状态与课表范围说明仍分别显示。检测操作可见高度32px，沿用原生按钮触控留白，与左侧状态底部协调；运行中固定倒计时区域宽度并使用等宽数字，停止改图标+文字，不改变检测起停/时段/通知流程。

我的页移除头像与身份卡底色，姓名28px/1.3与签到标题一致、同20px左边距顶部对齐，学号在下；姓名后为淡色退出，调用原注销流程。左下只放当前主账号缓存学院和学期/教学周，无数据不伪造，不随协助身份切换，也不增加网络请求。姓名仍可进入账号管理，背景图与非Android呈现不变。

验证：相关122项回归通过（`mobile-signin-verified-tests.log`）；后续状态失败反馈、布局/资料检查87项及聚焦范围29项通过，最终静态分析无问题（`mobile-signin-final-analyze.log`）。状态回归实际调用刷新回调，验证成功空态、失败态不沿用空态，以及离开/返回清除；倒计时100s/9s的宽度相等。我的页断言无CircleAvatar、姓名28px、退出入口存在；原账号管理、长学院名、320宽1.3倍字号继续通过。

实看`build/mobile-campus-design/idle-light.png`、`running-light.png`、`long-dark.png`及`.tools/settings-polish/mobile-account-light.png`/dark/narrow。姓名与签到标题的实际渲染顶线一致，开始检测底边接近状态文本底线，浅深色与长内容没有溢出。隔离截图不代替真机触控验收。

调研依据：Material的Progress indicators要求把操作状态和结果清楚反馈（https://m2.material.io/go/design-progress-indicators/）；NN/g资料页案例强调个人身份与所属群组信息（https://media.nngroup.com/media/reports/free/Mobile_Intranets_and_Enterprise_Apps.pdf）。据此结合本项目已有缓存，选择学院+学期/教学周作为左下上下文；这是本项目的设计取舍，不将案例描述为必须添加这些字段的规范。

### 2026-10-29 数据设置更新入口APK

`15a71ea`源码Android release构建成功，81.3MB，沿用0.3.0+6（`build/timetable-data-settings-release.log`）；`dist/xmu-rollcall-0.3.0-android.apk`已替换为低频更新入口迁移后的产物，apksigner验证通过，证书与此前一致。ADB设备列表为空，本轮未安装，待接机后再覆盖安装。回归和隔离截图结果见下，不将构建成功当作真机验收。

## 2026-10-29 按操作频率安排刷新入口

常用刷新留在任务发生处：签到、作业继续保留原快捷刷新/下拉交互。低频课表手动更新归“设置/我的 → 数据与诊断 → 数据更新 → 教务课表”，正常课表页只保留本周/学期切换；加载失败仍保留就地重试/重新登录，不让用户为了恢复失败加载绕路到设置。

数据更新行显示当前查看账号和上次成功更新时间；打开页面只读取该账号缓存，不挂载自动同步。点击“更新”走共享force路径，按钮显示更新中并暂时禁用，结果在原行反馈，保留15秒门槛和30分钟网络失败退避。身份行按owner/target uid重建，旧请求结束后不改写其他账号界面状态。此为功能入口迁移，各端沿用现有控件样式；前端美化仍只针对Android。

验证：`timetable-data-settings-tests.log` 43项通过；补充结果反馈/截图后的课程回归`timetable-data-settings-final-tests.log` 6项通过，静态分析无问题。生产组件分别在Android/Windows打开课表，确认无常规刷新按钮；导航到真实SettingsDataPage时请求数仍0；点击更新真实AcademicSync调用Reader一次、更新时间变化后原行显示“课表已更新”，15秒内再次点击不重复请求。实看`build/timetable-data-settings/android.png`，384宽身份、日期与按钮并排可读；测试模式下的开发预览区不代表release会显示。共享节流及开学后两周规则未改变。

### 2026-10-29 最终策略APK

`3c1a352`源码构建Android release成功，81.3MB（`build/timetable-term-final-release.log`），更新`dist/xmu-rollcall-0.3.0-android.apk`；正式包名及0.3.0+6不变，证书SHA-256与此前安装证书一致。手动刷新入口的384/960生产页面捕获2项通过，并实看`.tools/academic-ui/term-384.png`确认手机顶栏按钮与本周/学期不重叠。构建完成前ADB列表仍为空，本轮没有安装或真机测试；待用户接机后再覆盖安装，不将上次生成的旧策略APK当作本次产物。

## 2026-10-29 最终课表更新策略（用户确认）

替代此前稳定期7天及开学附近日更策略：只有开学后的第1—2周按7天间隔自动更新；从第3周起，本学期已有缓存不因时间增长而过期，也不因入页、普通登录恢复或重新登录而强制同步。首次无缓存仍获取一次；按现有学期/校历识别进入新学期时重新获取。查询发生在新学期后但服务仍返回旧学期时，以已有fetchedAt防止每次入页重复探查，后续仍遵循前两周周更、之后停止。

课表页提供“刷新课表”按钮，各客户端复用同一受限流保护的force路径；15秒手动尝试门槛、30分钟网络失败退避、在途合并与身份守卫不变。正常新登录不再传force:true，有效课表同样复用缓存；明确的登录失败修复及学期锚点补正保留原修复路径。界面样式仍只调整Android；数据更新策略不按平台分叉。

验证：`timetable-term-policy-tests.log` 45项通过；补充手动入口后的`timetable-term-manual-tests.log` 43项通过；正常登录接线调整后`timetable-term-auth-tests.log` 20项通过，最终静态分析无问题。纯策略回归覆盖第7天边界、第3周、缓存数周不变、新学期首查、预发布课表及学校暂返旧学期不反复查。生产组件回归改为上学期缓存先显、新学期同步完成后更新；Android/Windows都实际点击刷新，第二次15秒内不重复发起请求。登录恢复/身份撤销与缓存隔离回归继续通过，不宣称执行真实教务查询。

## 2026-10-29 用户确认的平台范围

本轮及此前连续反馈的前端样式只作用于Android，不以窗口宽度代替平台判定。个人身份卡本就仅Android；设置行收紧、地点列表放大、搜索分组/项间距及分隔线、签到历史/设置的上对齐与灰色现在显式受TargetPlatform.android约束。Windows窄屏、iOS等非Android触控呈现恢复原有密度/对齐。底部浮动导航和检测masthead原本已限定Android。课表缓存、同步节流、身份隔离和其他数据逻辑仍由全部客户端共用。

验证：66项相关回归通过；加入平台隔离与同步次数断言后的24项设置/课表回归通过，静态分析无问题。新增390宽Android/Windows并列断言，地点管理设置行分别56px/64px，学院身份字段只在Android新卡片出现。地图和搜索原功能、Android主页继续回归。本轮属于平台范围收敛，未声称进行了新一轮设备视觉验收。

## 2026-10-29 用户纠正：有效课表不因入页同步

数据策略由各客户端共享，不按Android/Windows分叉。academicTimetableProvider先读当前uid的本地课表；缓存仍有效且无待修复学期锚点时直接返回，不调用sync、不解析认证、不写attempt。相同AcademicSchedule对象的展示转换继续复用。缓存过期/缺失才进入共享同步入口，入口把本地节流判断提前到身份/会话解析之前。

稳定期缓存有效7天；按当前课表实际第一周周一判断，开学前14天到开学后第13天有效1天，不再按整月2/3/8/9判定开学附近。普通尝试30分钟、手动刷新15秒、请求失败30分钟退避及单uid在途合并不变；新登录、学期锚点补正、身份守卫和旧缓存保留沿用原路径。前端样式调整仅Android，数据、缓存、节流不分客户端。

验证：`timetable-throttle-tests.log` 66项通过；补充/加强后的课程与设置回归`timetable-throttle-final-tests.log` 24项通过；`flutter analyze --no-pub lib test`无问题。新回归反复失效并读取有效课表Provider，记录真实AcademicSync.sync调用数0、身份解析数0、attempt未写入；直接调用共享sync也验证缓存/15秒门槛在认证前返回。以9月29日和9月10日分别验证实际开学周边的7天/1天边界。缓存过期后的真实同步、单次请求、更新发布、失败退避及账号隔离继续通过。未把每次本地时间比较描述成网络检查，也未宣称跨设备真网性能验收。

### 2026-10-29 本轮构建交付

源码`9b839e8`的Android release构建成功，81.2MB（`build/profile-density-android-release.log`），产物`dist/xmu-rollcall-0.3.0-android.apk`。aapt核对正式包名、versionName0.3.0/versionCode6；apksigner验证通过，证书SHA-256与此前覆盖安装证书相同。最终`flutter analyze --no-pub lib test`无问题（`profile-density-final-analyze.log`）。构建期间ADB设备列表变空，构建完成后再次查询仍无设备，已请用户重连；本轮未执行覆盖安装，未声称真机观感或性能已验证。

## 2026-10-29 个人身份卡与移动列表密度

Android我的页将56px头像、姓名、学号/账号信息和学院收进完整身份卡，沿用原插画背景；学院只从登录主账号的本地教务课表读取，无值则隐藏，不因签到选择协助账号而切换，也不新增网络请求。学院最多两行，长名称省略，整个身份卡继续打开账号管理/登录。普通设置行48px最小高度加上下各4px内边距，外观行56px；组左右边距16px、组间16px。地点管理单栏列表采用68px最小高度、36px图标底、15px标题/12px说明，双栏维持原紧凑规格。

呈现检查按进入我的→查看身份区/设置组→进入地点管理列表顺序，使用生产Flutter组件隔离渲染：

1. 我的：`.tools/settings-polish/mobile-account-light.png`、`mobile-account-dark.png`实看姓名/学号/学院归入卡片，设置组收紧；学院按主账号读取，新增切换协助后仍显示主账号学院的回归。
2. 大字体：`mobile-account-narrow.png`实看320宽、1.3倍字号、长学院两行省略；账号管理点击及退出入口回归通过。
3. 地点：`build/location-header-review/list.png`实看68px单栏行、36px图标底与更大文字；地图/选点/返回/课程绑定14项通过，双栏仍保留原规格。原测试手机行高≤60断言按本次用户要求改为68—72，桌面上限仍60。

核心70项回归通过；补充设置、campus_cache及学院用例通过，地图行高旧断言修订后14项通过。`flutter analyze --no-pub lib test`无问题。截图只证明所检查尺寸/主题的呈现，不宣称完整无障碍或设备实测性能；本轮真机安装另记。

## 2026-10-29 课表缓存先显与展示转换复用

进入课表时，只要当前目标账号有有效本地课表，先显示缓存，不等待academicTimetableProvider原有教务同步完成；同步结果仍走原Provider发布，错误/登录提示、身份守卫、限流和刷新规则不变。无缓存继续显示加载。academicCachedScheduleProvider按uid和academicRevision共享本地读取，供课程页、校园摘要及个人资料使用，不触发同步；academicDisplayCoursesProvider在同一课表对象被订阅期间复用课程展示转换，本周/学期切换不重复转换整学期课次。

验证：`profile-density-tests.log`中70项通过，`flutter analyze --no-pub lib test`无问题。新增回归使用真实AcademicSync和内存存储，仅在AcademicTimetableReader边界阻塞响应；请求未完成时TimetableGridView已呈现缓存，切换学期不重复请求且转换列表保持同一对象；放行后真实存储和Provider更新为新课程。额外campus_cache、学院及地图/设置检查中，仅旧手机地点行高上限断言与本轮新68px设计冲突，更新断言后地图14项通过。未给出未经设备测量的毫秒性能提升，也未宣称完全消除所有解析。

## 2026-10-29 导航胶囊与个人页层级修订

Android导航高亮为随Tab槽宽铺开的椭圆胶囊，不使用正圆；高亮相对导航外框上下/端点内缩5px，54px高度取27px圆角，与64px外框的32px圆角构成一致内缩轮廓。保留连续滑动、快速改向与减少动画行为。个人页顶部移除重复“我的”标题，以56px头像、22px姓名和账号状态作为唯一身份区；整行继续进入账号管理或登录，导航文字仍为“我的”。

验证：`flutter analyze --no-pub lib test`无问题；导航运动、设置外观/账号、搜索和移动主页30项通过。已有账号交互回归增加“我的”只在导航出现一次的断言；导航运动断言改为横向胶囊。实看`.tools/settings-polish/mobile-account-light.png`、`mobile-account-dark.png`和`build/nav-motion/in-flight.png`，浅深色身份区及移动中的胶囊正常；Android release构建成功（81.2MB，`build/nav-pill-profile-android-release.log`），比对设备427b338f原APK与新包证书一致后`adb install -r`返回Success，启动成功，版本0.3.0+6，保留原数据；真机观感由用户观察。

## 2026-10-29 Android导航圆形滑动高亮

Android四Tab浮动导航改为同一圆形底层高亮，270ms easeOutCubic连续移动；尺寸按槽宽限制至54px。移除各项独立选中背景，保留图标/文字选中、点击反馈、角标与搜索。current由原切页逻辑确认，系统减少动画时直接定位，IgnorePointer避免滑块截获点击。

`flutter analyze --no-pub lib test`无问题；导航运动、导航提醒、搜索与移动主页共18项通过，运动回归验证1→4途中位置、途中改到作业的连续性、最终中心、圆形尺寸、角标及减少动画。已实看`build/nav-motion/in-flight.png`，高亮位于工具/我的之间且没有额外背景。真实手机交互效果交由用户体验。

Android release重新构建成功（81.2MB，`build/nav-motion-android-release.log`），新包与设备427b338f现有APK证书一致；`adb install -r`返回Success并启动成功。继续0.3.0+6，保留原数据，未执行真实签到。

### 2026-10-29 本轮手机覆盖安装

`7031ed5` 源码构建 Android release 成功（81.2MB，`build/ui-spacing-android-release.log`），沿用0.3.0+6。连接设备427b338f，从设备读取原APK并验证新旧证书SHA-256一致；`adb install -r`返回Success，安装后查询versionName0.3.0/versionCode6。未卸载或清空数据；APK同时更新至`dist/xmu-rollcall-0.3.0-android.apk`。启动Intent已成功交给当前前台实例，页面实际观感交由用户检查，未执行真实签到。

## 2026-10-29 手机签到、搜索与作业角标微调

- 历史/设置图标上对齐并使用muted灰色，保持48px点击区域；Android开始检测改浅底描边，启动/停止条件保持原逻辑。
- 搜索列表明确只保留底部安全区，组标题上距12px；行内水平14px、图文间距12px、最小64px高度，文字随系统缩放，组内轻分隔。作业导航数量角标offset调整为(8,-4)。
- `flutter test`：搜索、移动主页、页头几何、页面inset、签到身份/二维码和导航提醒共65项通过；保留搜索底部安全区后单独重跑搜索1项通过。
- `flutter analyze --no-pub lib test`：No issues found。首次全目录分析长时间未返回，停止后改用源码范围，未声称全目录分析通过。
- 实看生产组件渲染：`build/android-masthead-polish/search.png`、`build/mobile-campus-design/idle-light.png`、`long-dark.png`。搜索初次渲染暴露显式样式丢字体继承，已改为沿用主题bodyMedium后重新渲染核对；浅色、深色和320宽1.3倍字体无溢出。
- 本轮未构建安装包、未安装或执行真机验收；未调用真实签到或联网查询。

# 2026-10-28 账号范围、区域地点和 GPA 工具

Final result: implemented scope verified; authenticated grade endpoint and Android physical-device checks remain unverified.

## Current behavior and evidence

- Refresh controls share the same surface/border. The homework refresh control has a 44px extent matching its segmented control. Timetable cells now use ellipsis for clipped text; full room text remains available in course details.
- Place filter has a visible selected fill. Course-place groups collapse room numbers into building/wing, resolve building aliases/fullwidth letters and show associated course names; custom wing coordinates apply to the other rooms in that wing. Room numbers remain in the actual timetable.
- `build/gpa-ui-review/gpa-960.0-false.png` and `gpa-384.0-true.png` were opened for visual inspection, alongside light/dark variants. Fixtures use fictional courses. They confirm app typography, three summary metrics, term selection, local update time, course checkboxes and long-title truncation. Font capture includes the real CJK/Fluent/Material faces; no generated bitmap UI or real grades are embedded.
- GPA is lazy: the campus tool card does not query grades. Opening the calculator reads its identity-specific snapshot, using a one-day cache; explicit refresh is throttled to at least 15 seconds. First/old caches query all grades, otherwise the server's recent-term identifiers determine replacement. Only server grade points and credits are weighted, with unknown points excluded.

## Isolation audit and regressions

- Existing requests, raw course catalogs, academic timetables, homework, history, attendance and automatic submission paths already carry target identity/session checks. Their account and queue regressions still run.
- Fixed global saved locations and schedule-gating preference. Scoped keys and legacy migration now keep them separate; only explicitly configured legacy assist point IDs migrate into that assist's list. Logged-out draft locations use a separate key; switching identity resets the location editor and campus selection so a draft cannot be saved into the next identity.
- Pending GPA response is discarded after selection/owner/session changes, including secure-store owner verification. Local rows exclude student identifiers/session data. Pagination or server error cannot replace a complete cached snapshot.
- Automatic start and explanation use the same selected-identity planner, wait for that identity's settings and do not borrow loading-state data from the previous identity. New widget regression switches from an allowed owner to an assist with an empty known schedule and asserts disabled start plus the no-class explanation.
- Term starts use cached TronClass `start_date` metadata, with a one-time old-catalog schema refresh and a unique most-common teaching Monday in the term's season; manual start remains highest priority. Unknown/ambiguous dates keep the published-calendar fallback.

## Validation

- Full suite: 730 passed, 2 existing network-config tests skipped (`build/gpa-all-final.log`).
- Focused UI/role regressions: 40 passed (`build/gpa-ui-regressions-final.log`).
- Static analysis: no issues (`build/gpa-final-static.log`); final location/grade subset: 12 passed (`build/gpa-delivery-focused.log`).
- Live development process: existing Windows app PID 70280, original `flutter run` session retained. Final library changes are hot-reloaded after restart (2 libraries in 3,004ms). Final grade subset: 8 passed; selected-role UI subset: 35 passed. One hot restart is used for the new provider/cache schema so migrations and identity dependencies initialize together; no release installation or duplicate app instance.
- Source capture `D:/Liu/Desktop/成绩查询.txt` is read-only and is neither committed nor replayed for authentication. Interface contract and audit notes stay in ignored local docs/research/54-grades-and-account-scope.md.

## Remaining checks

Authenticated end-to-end GPA retrieval is left for the first user-opened calculator; the automated suite uses fake records and protocol response shapes. Physical Android execution is not claimed. Device appearance, window/notification settings and imported-account management remain local management state, while business requests and records follow the selected identity.

---

# 2026-10-28 元信息对齐与地点列表微调

- User visual evidence: clipboard-38761503 (icons above text), clipboard-0baa780e (small sidebar dot), clipboard-8c7974a3 (pending link alignment). This is a targeted UI correction, not a new design direction.
- Corrected render evidence: `.tools/desktop-workspace/timeline-single-dark.png`; `build/place-ui-review/map-960.0-false.png` and dark/mobile variants. Viewed actual renders after the change. Map fixture tiles are intercepted by the test harness as documented below.
- Metadata icons now center in the first text line box (12px × 1.5 × text scale), preserving alignment when rooms wrap. Detail metadata uses one Fluent regular family, including clock and dismiss.
- Pending course action has no middle-dot separator, uses a 24px tinted icon anchor at the content edge and a separate open-map arrow. Desktop reminder grows from 5px to 7px and the entire navigation row owns the short actionable tooltip.
- Location list uses dense 56px two-line rows. Equal expanded segments share label/selection geometry; the filter has a permanent 40px slot, so switching tabs changes neither track width nor label centers. Geometry regression covers both selected states at 384/960 in light/dark, plus row height and whole-navigation tooltip bounds.
- Related suite: 30 passed (`build/polish-alignment-tests.log`), plus exact icon/text vertical-center regression passed (`build/polish-icon-center-test.log`); static analysis: no issues (`build/polish-alignment-analyze.log`). No protocol, storage or submit behavior changed. The unchanged all-suite baseline was 715 passed / 2 skipped in the preceding delivery.
- Existing Debug VM needed one hot restart after attaching (first hot reload reported zero libraries); process 27264 remains the same Windows app. No release build/install or Android physical-device verification in this UI-only follow-up.

---

# 2026-10-28 地点管理与工作区反馈修订

Final result: pass for implemented scope; external and physical-device gaps below remain unverified.

## Source and evidence

- Selected visual truth: `.tools/location-design/selected-campus-right.png` (1487×1058), refined from the user's selected first design with campus switching in the top-right header.
- Flutter capture: `build/place-ui-review/map-edit-960.0-false.png` (960×900, DPR 1), plus initial/saved states at 384/960 logical pixels in both themes.
- Combined comparison: `.tools/location-design/comparison-full.png`; focused list comparison: `.tools/location-design/comparison-list.png`. Source navigation cropped for the main-content comparison, aspect ratios retained; the composition sheet fits each image independently and is not a pixel-diff or identical-viewport claim. Fixtures have two rooms rather than the source's six.
- Native Debug window: viewed through Computer Use after hot reload at 1104×772. Real map tiles rendered; right-aligned campus control, room list and pending-room inspector verified. User data was not changed or submitted. The temporary pending selection was cancelled after inspection. Native screenshots were displayed by the tool, not re-exported from screenshot payloads.

## QA iterations and five fidelity surfaces

1. Initial capture exposed square CJK glyphs inside ListTile: the local title/subtitle styles inherited ListTile's independent font defaults. Fixed by using the app's bodyMedium/bodySmall styles. The post-fix combined comparison shows readable room names and metadata.
2. Post-fix review: no remaining P0/P1/P2 differences within the selected layout scope. The list/map split, selected tint, search, pending/located groups, upper-right campus switch and lower-right inspector are present. The mock's underline tabs use the app's existing segmented control; font size, Fluent icons and button geometry follow current product tokens. Zoom/pan use the existing map gestures; no simulated locator button was added. These are intentional component reuse choices, not missing functional controls.

- Typography: app's Chinese/Segoe families; 13px room rows, 11px subordinate status, 14px inspector heading, existing page-title token. Rechecked after font fix. Homework titles use one line with clip and softWrap=false, while detail titles remain complete.
- Spacing/layout: fixed 300px desktop list, 16px split gap, map fills remaining height. No page-level vertical stack of banner/map/form/list. At narrow widths, list and map switch instead of squeezing columns. Inspector and location draft respond to keyboard insets. Shared desktop heading uses a 44px minimum row height; homework filters sit in header actions.
- Colors: existing sea-teal tokens, faint list separators, selected surface, semantic location status. Dark illustrations preserve colors with reduced brightness/saturation and soft edge alpha, without inversion.
- Image quality: actual CampusMap tiles and markers are reused rather than embedding the mock's raster map. Widget tests deliberately intercept HTTP (400), so blank tiles/failure notices in those fixtures are not used as evidence of a live-map visual match; the running native window provided separate live-tile evidence. Existing sidebar/card paintings remain the original assets.
- Copy/content: actual schedule classroom names and custom locations only; building references labeled as approximate, not surveyed classroom coordinates. User selections cannot silently authorize automatic radar submission. Empty campus, pending location and save failure states remain explicit.

## Behavior and validation

- Latest-history footer uses the same currentCourseHistoryProvider and HistorySummary as HistoryPage, includes unsigned records and remains pinned below the independently scrolling task list. Removed the separate local-submit/history-cache scan.
- Course detail uses a compact location row, then one map with one selected point and no campus picker or other preset markers. Opening and returning both have verified intermediate heights during 240ms transitions. Legacy explicit binding retains mounted state across the picker and returns the selected result.
- Desktop notice dots sit at the far right with a reserved slot; mobile badges stay on icons. Settings/history toolbar buttons have outlines. Single-course rail reaches below the card and metadata icons align.
- Static analysis: `flutter analyze --no-pub lib test`, no issues, `build/followup-verified-analyze.log`.
- Full suite: 715 passed, 2 existing network-config tests skipped; `build/followup-verified-all.log`. Focused course/map run: 10 passed, `build/followup-course-final.log`. Prior failures in old UI finders, retained picker state and retap lifecycle were fixed, not ignored.
- Hot reload attached to the existing Debug VM; the original app PID 27264 remains. This turn initially needed one hot restart, then subsequent changes hot-reloaded successfully; final reload updated 16 libraries. No second daily app instance or release installation.

## Remaining limits

No trustworthy comprehensive three-campus classroom coordinate library was found in the checked attendance projects; see local `docs/research/53-classroom-presets-and-dark-artwork.md`. Building references remain approximate. Android physical-device behavior, authenticated attachment downloads and native continuous resize/frame performance are not revalidated by these widget tests.

## Implementation checklist

- [x] User-selected location layout and upper-right campus switching.
- [x] Compact course location, single-point map and two-way animation.
- [x] Header actions and single-line clipped homework titles.
- [x] Canonical latest history footer, timeline/icons and theme treatment.
- [x] Source/implementation combined visual review, font correction and post-fix comparison.
- [x] Running Debug hot reload.

---

# Earlier QA records (historical, superseded where this report differs)

# 地点管理与工作区体验 QA — 2026-10-28

## 地点与界面修订验收（2026-10-28）

- 全量：713 passed、2 skipped（原有网络配置项）；日志build/place-all-final.log。最终缓存时间捕获/内置点授权单元回归13 passed；最终页头及视觉/身份/设置聚焦47 passed；地图流程/说明附件截图5 passed。flutter analyze无问题；Windows Release构建通过。最终交付命令日志build/place-analyze-delivery.log、build/place-windows-delivery.log。
- 实际查看：build/place-ui-review下384/960浅深色的地点管理、保存后与作业详情截图；.tools/desktop-workspace下900浅色、1440深色、字号和DPR场景。检查了最终水彩滤镜和900窗口页头按钮一行排布；这些是隔离Flutter渲染及虚构数据，未接入当前用户账号或提交签到。
- 地点匹配覆盖全半角、空格、中文楼号、别名、跨校区同名歧义、自定义优先；显式内置ID可供后台reader使用，名字匹配本身不授权自动签到。课程详情和地图保持一个Dialog；新增自定义点后待补全立即消失。自定义增改删与旧存储兼容，内置不可改动。
- 未实测：在线高德瓦片（widget测试拦截HTTP返回400，截图仅验证标注/布局和底图失败提示）、真实平台附件下载及浏览器认证、原生双击/悬停/系统tooltip事件与Android真机。已编译不等于这些实机验收通过；无安装、发布或push。
- 官方来源、目录缺项和坐标边界记录在本地docs/research/52-campus-places.md，78个内置点仅代表楼宇参考位置；目录未覆盖西部片区等新地点，允许用户地图补全，不用校区中心猜测。

# Desktop interaction and identity QA — 2026-10-28

final result: passed

This gate covers the requested stable UI states and identity/detection contracts. Continuous native resize flicker remains an explicit acceptance limit, not a claim of complete elimination.

## Sources and comparison

- User references: `codex-clipboard-c313270d-4ddd-4942-bdc4-7af07c301f4a.png` (course menu), `codex-clipboard-b21e8321-11c2-4ddb-803d-ddbd1ea13a5e.png` (sidebar margins), and `codex-clipboard-273667fd-28ed-4061-ad1a-aca3f8cbbd07.png` (text-action padding), plus the written corrections.
- `.tools/identity-menu-comparison.png` puts the source and current course-action cluster together. Fixture course names/counts differ deliberately; comparison concerns arrow, menu width, control alignment and spacing, not a pixel-identical course-data clone.
- Actual widget renders: `build/desktop-ui-review/homework-course-menu-{320,384,960}.png`, `schedule-detection-{320,384,960}.png`, `.tools/monitor-typography/monitor-settings-*.png`, and `.tools/desktop-workspace/*-dpr*.png`.
- Renders load real CJK and bundled icon fonts. An initial capture used default test fonts for homework body text; it was corrected to the production AppTheme and recaptured before comparison.

## Findings fixed and rechecked

1. P2 arrow direction: account uses right-to-up; normal selects and disclosure controls use right-to-down. The half-turn behavior is removed.
2. P2 course menu geometry: fixed menu width follows the filter + gap + refresh group (142 logical pixels on desktop). Tests assert both menu edges equal the corresponding action-group edges, including a real course-page flow.
3. P2 focus residue: background pointer clicks outside the focused control dismiss its focus. Menu selection/Escape still return keyboard focus for reopening. The root-page regression presses Tab, closes the menu, clicks blank content and checks that trigger focus clears across six viewports/scales.
4. P2 layout: text links have 10px horizontal padding; sidebar illustration lives on the full-width background rather than inside control padding; settings group captions align to the card outer edge and row padding is consistent. Requested radar/QR footer is removed.
5. P2 settings behavior: the obsolete daily clock editor is removed. The form displays the selected identity's merged course windows for today, a clear no-range state and the automatic-only policy switch. 320/384/960 widths, light/dark and large text were checked.

## Identity and detection verification

- Academic sync resolves separate owner/assist credentials, IDS jar and JW cache. Sending and publication recheck target membership, management owner and session revision. A removed identity cannot publish a late result. Assist authentication recovery opens assist import rather than owner login.
- Restarted Windows Debug actually authenticated the selected assist and fetched term 20261: **3 courses / 7 schedule rows**. The live timetable was inspected. No attendance submission was performed.
- Student UUIDv5 uses the fixed app URL namespace and normalized student number across platforms/installations. Known identities migrate once; unknown student numbers preserve existing IDs. Migration updates the in-memory owner cache; parallel roster mutations preserve both identities. Durable rules: `test/fixtures/account_identity.md`.
- Automatic discovery uses the union of actual class windows, 30 minutes before/after; no timetable means waiting. Explicit manual list/engine requests bypass the time policy. Android messages distinguish explicit manual requests from automatic rescheduling. Old daily clock preferences no longer constrain the new policy.

## Native resize work and limits

The Windows host now clips the Flutter child surface, avoids full-parent invalidation and suppresses redundant GDI background erasure for the host/view. The clipping behavior follows [Microsoft's window-style documentation](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles). This addresses a concrete redraw path; it does not establish a measured native FPS improvement or prove that all flicker is gone.

The rebuilt Debug process was restarted and inspected with the real assist timetable. A shrink attempt produced no reliable size change. A later drag was rejected because user input was detected, so further pointer control stopped. There is no reliable continuous-frame recording of live resizing in this pass. Previous retained-tab layout-count regressions still cover skipped hidden-page layouts.

## Final checks

- `flutter analyze --no-pub`: no issues (`.tools/identity-last-analyze.log`).
- `flutter test --no-pub`: 699 passed; 2 network tests skipped by existing configuration (`.tools/identity-last-tests.log`).
- Final account/route/workspace subset: 55 passed; identity/storage subset: 12 passed; visual/policy subset: 22 passed; final course-menu capture: 3 passed; settings visual subset: 7 passed.
- Final saved-source Windows Release succeeded, exit 0 (`.tools/identity-last-windows.log`). Debug remains running with the final hot reload.
- No installation, publication or push. Android device behavior is not claimed as physically verified.

# 地图视角与浮层修复 — 2026-10-28

- 校区公开瓦片抽样：z18 返回正常图像；z19/z20 虽 HTTP 200，却返回 256×256 单色占位图。因此原生层级限制为18，最高允许本地放大到21；坐标计算精度不因瓦片放大而提升。
- 选点与视角状态分离：平移及缩放后点选只更新草稿和面板；点击列表中已有地点保留倍率并定位，切换校区重新定位。地图来源和 logo 控件在地图手势层外，移至右上角，展开内容也阻止点击穿透。
- 提示左/下与编辑面板右/下统一12px。标题旁显示六位小数的纬度、经度（GCJ-02），可选中复制。实际查看 build/place-ui-review/map-viewport-draft.png，确认坐标同行、右上来源控件和底部面板布局；另生成384/960宽度、浅深色地点流程截图。测试 HTTP 被拦截为400，截图不作为在线底图渲染证据。
- 验证：flutter analyze --no-pub lib test 无问题；地点地图流程、选点、桌面地点工作流和课表布局20项通过。新增真实指针回归断言来源控件不选点、20级选点前后中心/倍率不变、浮层边距及坐标文本。日志 build/map-viewport-analyze-final.log、build/map-viewport-tests-final.log。
- 当前 Windows Debug 已热重载（23 libraries）；未进行Android真机或全校区在线瓦片覆盖验收。

# GPA规则与成绩入口修复 — 2026-10-28

- 运行中的Windows Debug原日志：成绩应用入口页面200、成绩POST查询403。补请求头或仅初始化角色仍403；改用官方成绩appShow入口（4768574631264620），再初始化角色，同身份只读查询返回200及69条成绩。最终数据已按账号缓存；未复用抓包Cookie、未提交签到。短时诊断入口已完全移除，app.dart恢复原样；最终仅保留原有脱敏HTTP日志。
- 规则核查：2022本科生成绩管理办法第九/十一条及表1/2（https://gk.xmu.edu.cn/info/1065/25331.htm）；学分认定和转换办法第五条（https://life.xmu.edu.cn/info/1058/1030.htm）。两级制/P/NP、EX/DF/W/N/A不计入；F/0绩点计入；每次修读成绩均计入，优先于旧2018手册中间重修成绩排除说法。通识课程不一概排除，以有效教务绩点和认定标记为准，提供自选口径。XFJD是课程绩点，不除学分；保留荣誉绩点，字母均分按官方表2换算，指标显示两位小数。
- 范围含总绩点、具体学年、近1—6学年、近1/2/3/4/6/8个有成绩的学期和指定学期，包含夏季及短学期。课程分类/排除原因可见；切换范围不联网。旧版本缓存即使一天内也全量补齐新字段，失败保留缓存；UID、身份修订及会话守卫保留。
- 验证：成绩协议、规则、账号切换、教务课表、GPA界面及桌面工作区40项通过（build/gpa-rules-tests-final.log）；最终界面/缓存升级7项复核通过，含新增旧缓存全量升级回归（build/gpa-rules-visual-final.log）。最终flutter analyze --no-pub lib test无问题（build/gpa-rules-analyze-delivery.log）。桌面工作区回归断言设置按钮在记录右侧。
- 已实际查看build/gpa-ui-review/gpa-960.0-false.png和gpa-384.0-true.png，并生成其余两种主题/宽度组合。修正新增Chip/规则标题在隔离字体中的方框；实际指针回归覆盖学年切换、近学期数量、通识筛选、课程勾选及规则展开。截图用虚构成绩，未导出真实成绩。Android真机及其他身份在线成绩查询仍未验收。

# GPA实际学年与交互审阅 — 2026-10-28

- 本轮先运行隔离GPA界面回归并捕获修改前960浅色/384深色截图，保存在build/gpa-scope-audit/before-desktop.png、before-mobile.png；再查看本轮后的同宽度同主题总览与学年多选截图。原三项等重卡片在手机占用三行、规则说明先于列表；现在GPA为主、均分及计入学分为辅，列表按学期分组，规则说明下置。
- 流程1：总绩点→学年。只列实际存在的学年，支持多选合并；两学年样例中不存在2024选项，不再有“近1—6学年”列表。取消所有学年显示明确空态。流程2：近学期→数量，只列1到现有学期总数，切换在本地重算。流程3：课程勾选→恢复默认选择，门数、总览及通识筛选同步；长课程名通过公用截断组件补充全文悬停。
- 参考仅为固定源码：democard/xmu_assistant@bbcedf701f8b66200a5897767e0d14c7c6cef5fe。采用按学期分组和统计口径分离的思路；没有安装、运行或截取该应用真实界面，没有复制上游代码。它仅统计百分制，模拟换算C-为1.5，不能替代校方2022规则；本地模拟、已修学分和排名/证明作为后续参考，不在本轮新增。
- 检查：21项成绩规则/区域/身份缓存/接口及GPA界面回归通过，静态检查无问题（build/gpa-scope-tests-final.log、build/gpa-scope-analyze-final.log）。320/384/960浅深色六种界面实际指针回归覆盖多选、空选、近学期、通识、恢复默认、规则展开；生成总览与多选截图，并实际查看桌面前后及窄屏深色多选状态。没有发现溢出；未进行系统读屏器或Android真机验收，不能据此宣称完整无障碍合规。

# 教学区域聚合与研究生成绩 — 2026-10-28

- 11个用户提供的翔安区域点已内置（含补充确认的西部4号楼），保存原始6位坐标。主列表按学武/坤銮/文宣/西部2/4号楼聚合，不平铺ABC。地图18级以下聚合，点击楼宇或放大后展示区域；区域标签含楼名以防相邻楼宇ABC混淆。聚合中心是LatLng展示数据，不存在可提交的SavedLocation ID；显式区域选择仍保留精确坐标与身份授权。
- 真实指针回归：主列表没有A/B/C行；楼宇面板可展开子区；放大后出现具体区域；选B区后视角不重置，坐标24.605494/118.313825。后台读取同一ID返回B区原点而不是均值，协助身份不能借用主号配置。旧78楼宇目录及旧显式绑定兼容，没有把匹配结果自动授权为签到。
- 实际查看build/place-ui-review/building-overview.png、building-expanded.png、building-region-selected.png与build/gpa-ui-review/graduate-empty.png；测试环境拦截瓦片返回400，图像只验证标注/布局/面板，不声称本轮在线底图实测。末次扩大区域标签避免楼名省略；已有384/960浅深色流程回归继续覆盖。
- 主账号研究生身份由用户确认。真实只读验证本科入口转向403权限页，研究生成绩应用正常打开，POST xscjcx_by返回HTTP200及0条；用户抓包同样rows=[]/totalSize=0，hqjdxf空值。使用KCMC/KCDM、CJXSZ/CJ、JDZ/XF映射，已发布的真实非空研究生记录尚未出现，非空/重复修读/身份不符/格式错误以虚构样例回归。权限页只分类，不发出HTTP请求或扩大白名单；临时诊断及刷新挂钩已移除。
- GPA education随账号缓存；研究生完整结果不套本科近期合并，空列表可以替换旧数据。第一页缺模型或错误code不能伪装成空成绩；两级制等无效记录规则保留，研究生字母分数不借本科换分。空成绩切换到学年仍为正常状态，不报格式错误。
- 签到页非检测时段增加短说明，今日无课/缺课表保持原文案。候选清单按官方公共教学服务资料整理，学信楼/西二教学楼核实为西部2号楼别名；未提供坐标的候选不内置，漳州旧设施资料明确标记需当前课表核对。
- 验证：全量746 passed、2既有网络项skipped（build/region-graduate-all-tests.log）；最后定向33项（含新增权限页分类）通过，校区前缀/标注复核18项通过，研究生空态及GPA复核7项通过（build/region-graduate-delivery-tests.log、build/region-labels-final-tests.log、build/graduate-empty-delivery-tests.log）。最终flutter analyze --no-pub lib test无问题（build/region-graduate-last-analyze.log）。Android真机和研究生非空正式成绩未实测。

# 地点管理控件与聚合标注微调 — 2026-10-28

- 用户四张参考图：小屏返回按钮对比不足，筛选需要矩形选中底，地图标注数量及留白过多、上下锚点不一，左列表课程长名与状态混排。对应修复为不透明返回表面/边框/阴影、8px圆角筛选、高亮底与边框；聚合标注仅楼名，文字测量宽度，统一Alignment.center；以区域边界中点定位，学武接近B区，提交坐标不变。
- 左列表为28px楼宇图标底、单行标题、简短区域/课程数量、圆角选中态，不再逐行堆长课程名和重复“已定位”；待补全保留课程名，已定位课程全文可悬停查看。选择子区域仍高亮父楼宇。
- 实际查看build/place-ui-review/building-overview.png、building-region-selected.png、map-edit-384.0-false.png，检查紧凑标注、选中父行及不透明返回控件；既有浅深色/384与960工作流截图也已重建。Widget环境拦截瓦片HTTP400，截图只验证界面及交互，不作为在线底图证据。
- 初始相关18项回归通过；最后地图/点位9项复核通过（build/location-polish-delivery-tests.log）。全局静态检查无问题，末次5个变更文件定向静态检查无问题（build/location-polish-analyze.log、build/location-polish-delivery-analyze.log）。回归断言筛选矩形边框、返回按钮不透明及边框、聚合居中/无数量、区域几何中心，原视角保持和区域坐标测试继续通过。Android真机未实测。


# 地点管理课程面板与原楼宇中心 — 2026-10-28

- 根据本轮四张用户截图修订：缩小地图的分区楼宇使用原目录中的楼宇参考中心（含坤銮楼），放大后仍使用用户给出的精确区域点；无分区的西部教学楼保留用户坐标。聚合点仅用于显示，提交ID与坐标不变。
- 删除待补全筛选，切换组件占满原列表宽度。已定位课程地点面板直接展示课程；多分区按有课程的区域分组，省略空分区的状态行、箭头和大行距。无课分区楼宇保留紧凑区域入口；点地图上的具体区域只显示该区课程。已定位课程面板移除“补充区域位置”，自定义编辑及待补全流程仍可用。
- 实际查看 build/place-ui-review/building-region-courses-960.0.png 与 building-courses-384.0.png，确认桌面分组、窄屏直接课程列表及底部紧凑面板。截图使用虚构课程；Widget环境网络被拦截，截图不作为在线底图验证。
- 25项地点/选点/课程区域存储回归通过（build/location-course-panel-delivery-tests.log），覆盖384/960宽度、浅深色原有工作流、课程直列/分区、点击具体区域只显示对应课程、坤銮原中心及西部楼宇精确点。全项目flutter analyze --no-pub lib test无问题（build/location-course-panel-delivery-analyze.log）。Windows Debug成功热重载24个库，保留原开发进程；Android真机未实测。


# 地点列表范围与区域中点纠正 — 2026-10-28

- 本轮用户截图显示旧楼宇参考点偏左上；撤回上一版参考中心选择，使用完整区域经纬度边界中点。侧栏只有部分区域课程时，定位视角仍使用完整楼宇区域集合；区域精确坐标和提交ID不变。缩小标注补上15px定位图标，按图标+文字宽度计算，维持居中锚点。
- 课程地点列表仅列当前课程使用的地点，不再把闲置内置预设混入已定位列表；地图仍显示预设标注。无匹配课程只显示空态，不再显示A/B/C操作按钮；有匹配课程继续紧凑分组。自定义地点列表及补全流程保留。
- 实际查看build/place-ui-review/building-overview.png、building-region-courses-960.0.png、building-region-selected.png，核对定位图标、仅两个实际课程楼宇的列表、空态无按钮。Widget网络被拦截，截图不作为在线底图验收。
- 最终相关25项回归通过（build/location-course-only-tests-final.log），含浅深色384/960流程及课程区域存储；5个变更Dart文件静态检查无问题（build/location-course-only-analyze-final.log）。Windows当前Debug保留原进程并热重载；Android真机未实测。


# 桌面设置审阅、分层返回与待办 — 2026-10-28

1. 设置首页（已调整）：本轮先捕获并查看build/settings-before-desktop.png，看到桌面常用区重复提供侧栏课表、应用组混放外观/窗口/提醒/维护。随后按原组件体系重组，保留账户、地点与协助入口，去掉桌面重复课表入口；手机保留课表入口。修改后实际查看.tools/settings-polish/960-light.png，外观/关闭窗口两选择器仍等宽、右对齐；通知与维护单独成组。
2. 低频维护（可用）：实际查看.tools/settings-polish/960-light-about.png，更新和下载线路继续位于关于二级页，数据诊断保留二级入口；不把低频工具展开到首页，不增加没有需求的开关。设置测试覆盖320/960、浅深色、1.3倍文本、指针与键盘、外观保存和诊断复制。截图使用虚构账号；未验收系统读屏器或Android真机。
3. 分层返回（通过回归）：新增桌面早期Esc处理与鼠标后退键；只关闭菜单、再退页面，根层停留。根Navigator.maybePop与Tab的maybePop保留PopScope内部步骤，课表地图和窄屏地点地图先退内部视图。回归专门断言不可直接关闭的弹窗先回课程步骤、选择菜单与页面分开退、首页不关闭应用；额外鼠标按键不触发菜单外点关闭造成连续退两层。没有操控用户日常窗口验证这些动作，使用隔离测试。
4. 地点与待办（已调整）：取消地点搜索框，标注左右各9px，课程地图默认17级。已知楼宇聚合中心从完整内置区域集合计算，单一A区课程不能使聚合点移到A区；多教室同区字符串含混合括号可匹配B区，跨区/跨楼继续未匹配。实际查看build/todo-ui-review/todo-false.png和todo-true.png，课程名、单行省略标题、截止信息依次显示，48×64图标底与信息块对齐，34px实心文档图形提高辨识；仅从当前身份课程目录补齐待办课程名。

最终验证：地点/桌面工作区/选点25项通过（build/workspace-refinement-flow-tests.log）；设置/返回/待办/课程区域/缓存44项通过（build/workspace-refinement-controls-final.log），合计69项。flutter analyze --no-pub lib test无问题（build/workspace-refinement-analyze-final.log）。图形测试里的地图瓦片被拦截，不作为本轮在线底图验收。Windows当前开发进程热重载102个库成功；没有重启、推送或发布。


# 课表地点提醒热重载一致性 — 2026-10-28

- 检查本机Riverpod 2.6.1源码：debugReassemble只在debugGetCreateSourceHash变化时使Provider失效；本项目手写Provider没有该hash。地点管理直接调用新匹配函数，而未匹配列表可能仍保留旧派生状态。Shell.reassemble现在只使当前本地校园快照失效，连带重算分组和提醒；不清持久数据，不触发课程联网刷新。
- 新增真实reassembleApplication回归：同一Provider容器先保留旧未匹配项，切成“文宣楼(4号楼）B404、B405”后普通重建仍保留，执行热重载后变为空且导航提示消失。14项相关回归通过（build/place-warning-delivery-tests.log）；4种导航主题/尺寸复核通过（build/place-warning-tooltip-visual.log）。静态检查无问题（build/place-warning-delivery-analyze.log）。
- 提示为“有上课地点未定位，请在地图上标记”，课表入口为“X个上课地点未定位 / 打开地图”。已实际查看build/desktop-ui-review/place-tooltip-light.png，确认全文单行可见、指向地图标记操作；已生成深色版本。原始日常窗口没有被自动点击，当前开发进程成功热重载49个库。


# 设置控件统一与课表地点绑定闭环 — 2026-10-28

- 设置部分统一Fluent regular20图标，替换关于、诊断、通知与协助等页混用的Material符号；外观图标改为线性调色板，避免半实心圆造成粗细差异。SettingsSection内操作统一14px/500字重、10px圆角、18px按钮图标及36px桌面/44px触控最小高度，保持主操作填色、次操作描边；退出使用描边。实际查看.tools/settings-polish/960-light.png，确认外观图标、行入口与右侧控件的密度；浅深色设置截图均重建，视觉复核2项通过（build/location-binding-settings-visual.log）。
- 地点管理取消加号、自由空白选点新建及我的地点Tab，只保留课程来源。相同楼宇/区域去重合并，多个区域教室先拆区；全角括号按原输入显示。用户先选择未定位条目，再选坐标；名称只读，说明尽量与教务或导入课表一致。没有把已有个人数据删掉，也不修改全局预设。
- 新增严格的位置拒绝分类，排除网络、401/429、5xx、权限及活动结束等通用失败。桌面与Android自动任务持久化当前owner/user的失败点版本，活动仍只尝试一次；自动读取会拒绝已失败的点。错误优先排在地点管理，明确显示位置校验未通过。具体课次能从当前目录唯一归属时使用该地名，无法定位到教室的旧绑定单独列出；不误标同一门课其他区域。
- 保存校正必须选不同坐标；只更新既有绑定的坐标与地点引用，保留课程、课次及授权标记，既不添加新课程授权，也不打开自动提交。原样保存不能解除错误；旧反馈不覆盖新坐标。失败版本含坐标，避免清除旧记录时误删新错误；账号间、主/协助间独立。
- 隔离真实指针/持久化回归覆盖384/960宽度：错误在待定位之前、只读名称、绑定新坐标、清除错误、旧无地名绑定校正、预设坐标未被改写、已存在授权保留。实际查看build/place-ui-review/binding-errors-960.0.png和binding-correction-384.0.png；这些是虚构课程与模拟服务端失败，地图瓦片在Widget测试中被拦截，不能当成在线地图或真实签到成功证据。
- 本轮全量767 passed、2个既有联网配置项skipped（build/location-binding-final-all-tests.log）。此前完整回归发现全角括号显示回退，修正后全部通过；最后绑定相关18项也通过（build/location-binding-last-flow-tests.log）。全项目静态检查无问题（build/location-binding-final-analyze.log）。末次再收紧时间/权限范围及定位超时排除词，34项分类/自动签到回归通过（build/location-binding-classification-final.log），对应两文件静态检查见build/location-binding-classification-analyze.log。Windows当前开发窗口已热重载；Android后台代码已接入但未做真机签到验收，没有发起真实签到验证。


# 待办层级与Android真机体验构建 — 2026-10-28

- 用户截图三行等重内容难以区分，长课程名和作业名更明显。概览改为课程/截止的次级顶行与作业标题主行，使用独立轻边框卡片、40px方形文档底和加粗标题；日期标签省去重复“截止”字样，完整截止日期保留在提示中。课程和标题只截断时出现全文提示，不删减源文本，不改变作业点击入口。
- 实际查看build/todo-ui-review/todo-false-1.0.png和todo-true-1.3.png；浅深色及1.0/1.3字体四种组合重建。11项待办/桌面工作区回归通过（build/todo-hierarchy-final-tests.log），覆盖同行课程/截止、主标题单行、长按显示全文且不误触跳转、正常点击仍进入作业。静态检查见build/todo-hierarchy-final-analyze.log。
- 连接Android 16/API36真机（2410DPN6CC），已装应用为0.2.0/versionCode5。使用scripts/package-android.ps1 -NoPub构建当前源码release成功，约79.8MB（build/android-ui-review/build-release.log），版本标识沿用0.3.0+6，不是新发布版本。
- 从手机读取旧APK并与新APK比较证书SHA-256，一致；通过adb install -r覆盖安装成功，未卸载或清理数据。安装后查询versionCode6/versionName0.3.0，启动现有包成功，看到原账号及正常签到首页；实际查看build/android-ui-review/phone-home.png。刚启动时的加载中截图phone-current.png未作为验收页面。只观察启动和首页，未代用户点击签到或执行真实提交，也未宣称全部手机页面均已逐项验收。
- APK：dist/xmu-rollcall-0.3.0-android.apk，SHA-256 BC22C10AC2BAF5399C49A3F746381CC4AE496843E7E9F889F42AAD8D54DFFF83。手机使用触控布局，共享设置/作业详情/地图等更新随本次源码构建进入，桌面右侧概览仍为宽屏区域。Windows开发进程另行热重载，设备截图与APK均不入Git；没有推送或发布。


# 移动选择器、学院校区回退与待办详情 — 2026-10-28

- 地点管理窄屏右上校区、学期设置与课程关联移除原生DropdownButton/FormField，使用AppShellSelect，保留标题/字段标签及长文本裁切。384宽度回归验证初始翔安、打开菜单后切到漳州，且无布局异常。桌面继续页头右侧分段切换。
- 默认校区优先实际课堂地点，无可识别地点才参考学生学院名称。学院来源为已有initXsxx身份响应中的明确名称字段，不用开课学院，不新增请求；仅保存学院名称至当前uid课表快照。官方招生目录与漳州校区介绍核对常见学院；未知名称不猜测。旧缓存为空，需正常课表同步后补入；未宣称当前真实账号必然返回学院。回归覆盖教务响应提取、误用教学单位排除、旧快照兼容及账号隔离。
- 三处BottomSheet关闭顶部拖拽条并补齐内容顶距；课程详情及同层地图共用加深加粗的24px关闭图形与44px触控范围，课程标题行向上对齐。使用真实Fluent字体重建并实际查看.tools/timetable-polish/mobile-light-03-detail.png，确认顶部无条、关闭图形与标题同一行；另覆盖深色大字号及桌面布局。Widget地图瓦片请求由测试环境拒绝，不作为在线地图证据。
- 待办预览将单项和查看全部拆成不同回调，单项使用对应HomeworkItem打开HomeworkDetailPage。桌面真实Shell回归验证seed.id=3、详情返回；长按显示全文不误触，正常点击回传指定作业。查看全部继续进入列表。
- 72项聚焦回归通过（build/campus-ui-final-regression.log）；覆盖教务解析/缓存、校区与地点、课表弹层、选择菜单、作业详情和桌面导航。初次视觉运行曾因本地Material字体路径配置错误导致setUpAll失败，修正为D:/Dev/Flutter后重跑通过；最终渲染加入preview_fonts加载Fluent字体。
- Android已构建release并与现有APK核对签名相同，首次覆盖安装成功并观察正常首页（build/android-ui-review/campus-refresh-home.png），数据保留。Windows开发进程热重载110个库成功。最终学院元数据加载保护与联合学院名称补充后再次构建/安装记录见下。未执行真实签到。
- 最终静态检查无问题（build/campus-ui-final-analyze.log）；最终Android release构建成功（build/android-ui-review/campus-final-release.log，79.8MB），证书再次一致，adb install -r成功，versionName0.3.0/versionCode6，启动成功。最终Windows热重载23个库成功。保持现有账号与数据，没有推送、发布或执行真实签到。


# Android工具导航与移动视觉层次 — 2026-10-28

- 设计知识实际命中并阅读Engineering的20-主题/09-深色界面的氛围与信息层级.md和08-界面减法与任务模型.md。采用画布/卡片/控件的颜色角色、重要信息字号与分组，以及实际截图校验；不照搬视频中的紫蓝环境光、不增加占位工具或重复说明。本轮只读知识库，项目选择保存在本仓库。
- 修改前实际查看build/mobile-style-review/settings-before.png：白色页面和白色分组只有很浅的线分隔，账户权重与普通行相近，图标偏小。移动画布改青灰、内容维持白色，深色区分画布/卡片/控件；个人页账户摘要增大，常用入口提供36px图标底座，按钮与选择菜单使用单独底色和边界。实际查看.tools/settings-polish的384-light/dark与320-dark，确认长描述可换行、大字号不挤压操作；最终副本build/mobile-style-review/settings-after-light.png、settings-after-dark.png。
- 安卓底栏为签到/作业/工具/我的，工具复用campusTools身份及独立Navigator；桌面文案统一工具。圆角选中底色和Semantics.selected保留更新点在图标右上，更新状态切换前后导航尺寸和位置一致，返回流程不变。工具页仅GPA真实入口，窄屏卡片填满内容宽度；实际查看build/mobile-style-review/tools-320.0-false.png，320宽1.3字体验证点卡片进入GPA、返回恢复工具页，另覆盖384宽及深色。
- 首次窄屏大字截图发现PageScaffold固定页头高度造成8px底部溢出；改最小高度后重建并复核同一截图。选择菜单回归中的默认颜色断言同步新移动控件角色，悬停、键盘、选择、Esc与边缘定位断言继续执行。辅助文字在新增移动语义表面的对比测试通过，不据此宣称整应用无障碍认证。
- 签到触控工具栏刷新/记录/设置统一44px底色和边界、设置最右，复用Fluent图标；通用Panel与二级页按移动画布显示，桌面宽屏画布与密度沿用原规则。
- 74项相关回归通过（build/mobile-style-final-regression.log），覆盖四Tab懒加载、工具GPA往返、浅深色设置、更新点、选择菜单键盘/悬停、课表、作业详情和桌面工作区。全项目flutter analyze无问题（build/mobile-style-final-analyze.log）。
- Android最终release构建成功（build/android-ui-review/mobile-style-final-release.log，79.8MB），证书SHA-256与原安装一致，adb install -r成功、启动命令成功；沿用0.3.0+6，不是发布新版本，不清数据。随后只读截图显示用户正在打开手机控制中心，已拒绝作为页面验收证据并删除该临时截图，没有操作用户控制中心；页面视觉依据为隔离Flutter渲染，未宣称真机逐页验收。Windows现有开发进程热重载100个库成功。未执行真实签到，没有推送或发布。


# Android地点单顶栏与手势条间距 — 2026-10-28

- 地点管理的单栏列表/地图共用同一顶栏：初始地点管理，选地点后地点列表，地图内浮动列表返回入口隐藏。顶栏返回与系统返回都执行showList，回到列表再按返回才按原路由离开；宽屏两栏不改标题，独立嵌入组件仍可保留自己的返回入口。校区变化后的地图状态用帧后回调同步，不在父组件构建期间setState。
- 校区选择器增加inToolbar呈现，背景32px、外部上下各6px可点击留白，总触控高度44px，48px顶栏内可见上下各8px边距。普通选择器高度与菜单键盘/关闭行为保持原规则。实际查看build/location-header-review/list.png与map.png，确认标题切换、地图内没有第二个返回按钮，校区控件和标题居中；隔离测试不加载真实地图瓦片，空白地图不作为在线地图验收。
- mobileNavBottomTrim由8改为2，有系统手势安全区时增加最多6px留白，仍只计算一次viewPadding，不受键盘viewInsets影响。24px模拟手势区下，底栏总高为56内容+22留白+1边框=79，键盘打开后高度保持一致。更新点位置和菜单关闭回归继续通过。
- 54项聚焦回归通过（build/mobile-location-header-verified-tests.log），含顶栏/系统返回、校区切换、保存坐标、同层地图详情、Esc、表单选择菜单与更新点。首轮旧测试仍查找已移除的原生下拉和地图浮动返回按钮，已同步新契约；新底栏高度断言补计原有1px边框。
- Android release构建成功（build/android-ui-review/location-header-release.log，79.8MB），证书SHA-256与原包一致，adb install -r成功、启动命令成功；保留原0.3.0+6与账户数据。真机未执行签到；页面几何与返回行为为隔离渲染和自动化回归证据。Windows开发窗口另行热重载，最终状态见后附记录。
- 最终flutter analyze无问题（build/mobile-location-header-final-analyze.log），Windows现有开发进程热重载95个库成功；没有重启或清理应用数据，没有推送或发布。


# 安卓刷新入口减法与无背景Tab强调 — 2026-10-28

- 签到触控工具栏移除刷新，仅保留账号、记录及设置，宽屏桌面刷新保持；作业Tab在Android/iOS主题下不显示姓名/刷新行，原下拉刷新与缓存/身份逻辑不变。AppRefreshButton触控状态去掉背景和边框，保留点击范围、旋转反馈及原刷新回调，覆盖GPA和课程作业页。
- 底部Tab移除选中背景块，选中图标采用同语义实心Fluent版本（我的仍为人物）并与文字同用primary；图标下方2px间距，不再有30px底板带来的额外空隙。按压仅轻微透明度反馈，原手势条间距和更新点保留。实际查看build/desktop-ui-review/nav-mobile-light.png，确认图标/文字整体强调、无背景块；图中央是隔离测试占位，不作整个业务页验收。
- 作业列表和课程作业列表全部原clip单行文本改ellipsis；课程信息和摘要已用ellipsis的继续保留，数据不截短。实际查看build/desktop-ui-review/homework-hub-384.png：顶部不再出现账户/刷新行，长历史作业标题出现省略号，详情仍可打开。该隔离测试有debug banner，非发布截图。实际查看build/gpa-ui-review/gpa-384.0-false.png，右上只有刷新图标、无圆角背景。
- 83项相关回归通过（build/mobile-simplify-final-tests.log），覆盖320/384/960布局、作业详情/课程全部入口、账号隔离与刷新节奏、导航更新点、GPA及桌面工作区。首轮测试补漏图标import、恢复未选中我的Tab仍为regular图标的正确断言后重跑通过。全项目flutter analyze无问题（build/mobile-simplify-final-analyze.log）。
- Android release构建成功（build/android-ui-review/mobile-simplify-release.log，79.8MB），新包证书与原包一致，adb install -r及启动成功，沿用0.3.0+6并保留账户数据。Windows现有开发进程热重载100个库成功。视觉证据来自隔离渲染，未声称真机全部页面已逐项验收，未执行真实签到；没有推送或发布。

## 2026-10-28 安卓适配层与交互一致性审查

- 范围：地点管理列表→地图→坐标绑定/校正，校区选择，课表与叠课，GPA、作业课程筛选、签到历史、设置与关于页。先捕获本轮修改前截图，再修改和复核；没有把隔离截图当作真机业务验收。
- 依据：Engineering《界面减法与任务模型》《深色界面的氛围与信息层级》；Flutter adaptive best practices/input、Android touch target指引。采用按任务区分组件角色、语义表面和共享触控尺寸，不另造一套页面主题。
- 实际债务：移动选择器原先复用桌面锚定菜单并叠加inToolbar补丁；页面又重复决定触控/布局；地图外层padding与弹层inset相加造成屏幕边距不等；视图切换混用桌面胶囊；32/36/44尺寸散落；关于页URL换行导致同组行高不齐。并非单独改一个圆角就能解决。
- 统一规则：AppMobileUi集中56顶栏、48触控目标、16内容边距/面板圆角；触控呈现和分栏布局独立。移动顶栏用文字+箭头选择入口，选择从底部展开，有标题/当前勾选/关闭，无拖拽白条；长列表打开定位到当前项。课表、GPA等视图切换改文字和下划线；桌面保留原锚定菜单和分段轨道。
- 地点管理：手机地图铺满可用区域；绑定面板左右下16，内容过高可滚动；320×640、1.3倍文字、键盘260场景保存操作仍可到达。列表去掉全高白色嵌套容器，保留行层级和选中态；单一顶部返回逻辑不变。坐标绑定、地点匹配、提交逻辑未修改。
- 交互：补全选择弹层的返回、关闭全部、调用组件销毁、当前值更新时清理；退出后不调用失效context；清理空闲弹层主动安排帧；打开选择先释放输入焦点。模态弹层遮罩会阻止点击底部Tab，测试改为程序导航验证路由清理，不将遮罩行为误判为Tab缺陷。
- 细节：关于URL仅显示一行但复制完整值；课表叠课切换按钮在手机上改为顶部预留空间，避免标题被挤成逐字竖排；刷新入口保持手机无背景样式；已有底部Tab文字/icon强调、无背景的约定保留。
- 证据：build/android-consistency-review/before/{location-form,gpa,settings}.png；after/{location-form,campus-sheet,gpa,settings,timetable}.png。实际查看前后设置、绑定表单、GPA、课表和校区弹层。早期课表缺字体、弹层截图未覆盖root overlay均被拒收并重新捕获；最终校区图关闭debug banner。测试地图屏蔽网络瓦片，仅验证控件与几何，不据此宣称地图网络已验证。
- 回归：build/android-consistency-complete-tests.log全量780通过、2跳过；build/android-consistency-complete-analyze.log无问题；另有选择弹层生命周期、旧移动断言更新、地图键盘边距回归。最终干净校区截图单项测试再次通过（build/android-consistency-clean-preview.log）。早期Ink不支持constraints的编译问题及旧宽度断言均已修复，最终验证在修复后完成。
- 交付：build/android-ui-review/android-consistency-complete-release.log构建release成功79.8MB，0.3.0+6；证书SHA256与原包一致。设备427b338f执行adb install -r成功并启动，未清数据。Windows已有开发进程热重载49/3261库成功。本轮没有执行真实签到、推送或发布；真机各页的实际观感仍以用户使用反馈为准。
- 维护边界：本轮抽离了移动呈现规则，地点管理仍有较大的业务Widget；未为纯拆文件扩大改动。规格/验收/架构和ANDROID_UI.md已同步本地docs，该目录按仓库策略忽略，不强制提交。

## 2026-10-28 手机校园视觉第一阶段：签到首页与我的

final result: passed（源码实现、隔离视觉与交互回归）；Android真机安装/逐页观察尚未执行：本轮后半程ADB未发现设备。

- Git起点干净，遵照用户“改之前提交”建立c2c4cff检查点（上一稳定实现0c6702e）。本轮以用户认可的图1顶部+中部减法稿和待签到稿为目标；不重新选择图2/3，也不延伸成营销页或桌面改版。
- 目标保留在.tools/mobile-campus-reference/idle-and-settings.png、active.png。前者是双页概念板，不能把整张宽度当单页宽；后者853×1844与390×844手机视口基本同宽高比。对照按单页内容/逻辑宽度看构图和层级，不声称高分辨率生成图与真实字体逐像素相同。真实逻辑视口390×844，窄屏320×844、文字1.3倍；没有画设备状态栏或伪造系统安全区。
- 资产：内置ImageGen生成并实际保存assets/illustrations/campus_header.png（约1.34MB），核心提示为“右侧厦大风格橙瓦教学楼、浅青绿水彩、左上及底部透明留白、无任何文字/UI”，参考选定修订稿。该图为校园氛围插画，非学校官方实景证明。标题、按钮、账号、课程均为真实Flutter组件，图像排除语义和点击；深色复用亮度/饱和度处理。
- 构图：MobileCampusHeader复用同一顶图，主体无重复白卡；手机20水平留白与选定主页方向相符，地点管理等二级页原16规则不变。主卡保留18内边距，课程/待办以16/15标题和13辅助文字组织；保持必要48触控目标，不为强行一屏塞满而缩字。教室长名称分行显示地点/时间，较目标横排有意调整。长页可滚动，上次签到在内容末尾而不遮挡任务；短页靠近导航上方。
- 签到：空闲、待签到、运行中、完成、长标题/错误和身份切换沿原状态源呈现；主卡“去签到”进入原数字/定位/二维码流程。数字码预填回归确认入页repo.calls=0，检查后才提交；完成按钮禁用。手机主卡不常驻人数与课堂参考，参考仍可按需由课程菜单展开。检测启动/停止保留在有活动的顶部账号行；时段外和无课仍由原检测窗禁用，不增HTTP定时器或自动提交授权。
- 课程/待办：CampusContextView.mobile使用原磁盘快照，当前/下一课时间线无卡片和状态徽章；位置/时间icon按行高居中。只展示最近一项待办，课程/标题分别单行省略，点击进入原详情，查看全部进入作业。历史按服务端签到历史最新非占位记录显示，未签到记录不被较早成功记录替代，账号切换沿原Provider隔离。
- 我的：真实账号标题/可用身份信息，未提供校区时不伪造“翔安”；常用、应用两组无重复说明和图标底块，外观整行可点并有键盘焦点，主题持久化及取消正常；账号管理面板保留退出入口，关于保留新版本标记与原二级页面。四个底部Tab仍只强调icon/文字，无选中背景。
- 实际查看并同目标对照：build/mobile-campus-design/{idle,active,running,done}-light.png及dark对应图；long-dark.png是320宽1.3倍文字的长课程，不出现横向溢出，待办/历史滚动后可操作；.tools/settings-polish/mobile-account-light.png和dark.png及384-light.png。修正了早期未等待图片解码的空顶部截图，以precacheImage后的截图为最终证据；最终去签到箭头在文案后。
- 交互与功能：build/mobile-campus-actions-final.log相关45项通过；build/mobile-campus-settings-final.log设置17项通过；build/mobile-campus-delivery-captures.log移动状态10项通过。全量最终build/mobile-campus-verified-all-tests.log为792通过、2跳过；build/mobile-campus-verified-analyze.log无问题。首次全量在编辑数字预填回归期间编译旧版本而失败，最终在源码冻结后完整重跑通过，不将早期结果当完成。
- 构建：build/android-ui-review/mobile-campus-verified-release.log release成功80.9MB，仍0.3.0+6，最终dist/xmu-rollcall-0.3.0-android.apk；签名SHA256为7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5，与前版一致。Windows现有开发进程热重载19/3263库成功。ADB设备列表为空，已向用户询问重连/先交APK，未卸载、未清数据、未在真机提交签到、未推送/发布。
- 残余P3：真实Android字体与系统上下安全区仍需要接机逐页观察；此处已通过布局、隔离渲染及签名构建，不能代替用户真机观感。背景资产对小尺寸解码使用cacheWidth1200；不增加模糊或持续装饰动画。课表/GPA等二级页沿上轮统一组件，未宣称本轮全部手机页面已重新设计。项目规格/验收/架构/功能台账已更新本地docs，沿仓库忽略策略不强制提交。

## 2026-10-29 安卓覆盖安装补验

用户确认手机重连后，ADB识别设备427b338f（2410DPN6CC）。对上一阶段最终APK再次验证签名一致，执行adb install -r成功并am start启动；安装版本0.3.0+6、targetSdk36。未卸载、未清除应用数据。此项解除上一记录中的“设备未连接，尚未安装”限制；不等同于真机各业务页面已逐项视觉验收，未执行真实签到。

## 2026-10-29 状态栏色带与手机内容层级修正

final result: passed（隔离视觉、系统区域像素回归、完整测试和覆盖安装）；未把本轮手机合成截屏作为业务页视觉验收。

- 用户指出状态栏区域与下方颜色不统一、整页缺少层级。源码证据：PageScaffold安全区绘制mobileCanvas，MobileRollcallHome与移动我的页内层却绘制content；根页没有AnnotatedRegion，二级页才设置系统栏样式。该底色分裂和同等权重的裸列表是本次修复范围。
- 根页现在统一声明透明状态栏/手势导航区和匹配背景的图标明暗，关闭系统强制对比色带，继续只避让一次SafeArea。pageBackground按Android/iOS平台或桌面窄屏选移动画布，横屏/大屏不会因为宽度变大切回桌面白底。首页、我的正文使用同一mobileCanvas。
- 内容层级收敛为画布/独立签到操作/课程与待办内容组；课程和待办共用一块surface、组内轻分隔，组标题14辅助色低于课程16主文字。我的常用/应用各一块surface，16圆角/内边距、20外边距，不给每行再加卡。顶图透明度浅色.42、深色.28，降低与文字和控件争抢。历史仍在内容底部，Tab高亮、检测规则、身份隔离、提交确认不变。
- 视觉证据：build/mobile-hierarchy-review/after/{home-light,active-dark,settings-light,settings-dark}.png；实际查看浅色首页、深色活动、浅深色我的，校验分组、对齐、文本层级和边距。第一次设备截图虽在采集前窗口信息指向本应用，实际出现其他界面/浮层，已拒收并删除本地与设备临时图片，未展示为本产品证据。后续以隔离生产Widget渲染和像素测试验收，不再凭焦点元信息抓取用户画面。
- 回归：mobile_page_insets_test对浅深色32px顶部安全区取真实RGBA像素，验证顶部与正文画布像素相同、内容只偏移32px，透明系统栏/图标明暗正确。首轮截图Future处于测试假时钟导致等待，终止该任务并将toImage包在runAsync后重跑通过；不把卡住的首轮当完成。
- build/mobile-hierarchy-review/focused.log相关27项通过，insets-fixed.log新增2项通过；all-tests.log最终全量794通过、2跳过，analyze.log无问题。规格、安卓视觉契约和功能台账已同步本地忽略docs目录；CHANGELOG记录用户可见效果。
- android-release.log release构建成功80.9MB，最终dist/xmu-rollcall-0.3.0-android.apk仍0.3.0+6。核对SHA256证书与前版一致后，对427b338f执行adb install -r成功，保留数据；没有启动/切换用户正在使用的其他界面，没有执行真实签到。Windows原开发进程热重载97/3263库成功。Android系统栏最终实机观感仍待重新打开应用观察，不用隔离测试代称真机逐页验收；未推送/发布。

## 2026-10-29 手机等高顶区、日期与摘要条目修订

final result: passed（隔离渲染、几何和交互回归、构建/覆盖安装）；未声称真机每页视觉已逐项确认。

- 用户要求签到/我的顶部同高、背景同大小/位置、日期在标题右侧，并改善课程/待办。原图随child撑开，两页不同Padding和内容高度导致画幅不一致。本轮让MobileCampusHeader按相同宽度/字号规则提供184基本高度、窄屏加40、大字每1倍加72（scale限制1–2），图片统一fill/cover/bottomRight，与活动状态或账号说明无关；我的去掉额外垂直16，内容20内边距居中。
- 首页日期紧随签到标题并共享文字基线，普通宽度显示完整月日，窄屏/大字号简写月/日而保留完整语义。两页背景区到主体20、主体组间20，课程底8，使空白按共同节奏分配，不靠图片拉伸填空。系统栏与正文底色的上一轮修复保持。
- 当前课程为无边框轻底色选中区，下一课程透明；时间/节点/课程首行对齐，位置/时间icon保持居中。初次渲染发现320宽1.3字号的10:10换行，已让时间列随字号增宽并强制单行；最终截图已复查修正，非忽略视觉缺陷只保留通过断言。
- 待办为44蓝色文档标识、左侧两行课程/作业名称、右侧两行截止日期/时间；各名称单行省略，日期完整提示保留。点击仍进入该条详情，未改作业/缓存/账号/提交协议；桌面摘要原布局保留。
- 实际查看build/mobile-header-rhythm/after/home-light.png、settings-light.png及long-dark.png，另有生产状态浅深色截图在build/mobile-campus-design。两页正常顶图在相同390视口呈现一致；长内容页面可滚动看后续待办/历史，不压缩大字体到一屏内。几何回归对不同内容的顶区和图片尺寸/相对偏移作直接比较，覆盖320/390宽和1/1.3/2倍字号6种组合；生产首页验证日期在标题右方、时间单行。
- focused-final.log相关39项通过；all-tests.log源码冻结后全量800通过、2跳过；analyze.log无问题。android-release.log release构建成功81.0MB，仍0.3.0+6，核对原签名后对427b338f执行adb install -r成功，保留数据；没有执行真实签到或切换用户其他应用，没有推送/发布。桌面现有开发进程热重载4/3263库成功。
- CHANGELOG与本地规格/验收/安卓契约/台账已同步，docs继续遵循仓库忽略规则。该轮没有新增图片资产，仅统一已有图片的布局边界。

## 2026-10-29 Android顶图上移与浮动导航/校园助手/课程收纳调研

final result: passed（本轮已实现的Android顶图修复）；浮动导航、全局搜索、全天课程合并与收纳仍为调研方案，未宣称已实现。

- 用户提供浮动四Tab+独立搜索截图及Sticky Stack参考，并强调只改Android。顶图由于素材透明天空而偏低，本轮仅在Theme.platform为Android时将绘图区top延伸至-60、bottom仍为0，原顶区裁剪；文字/按钮/顶区等高规则保持。Windows分支仍top=0，几何回归明确断言，不改变桌面样式。
- 实际查看重新捕获的build/mobile-campus-design/idle-light.png：建筑上沿提高到标题区域附近，下沿继续贴顶区底部，两页共用同样规则。tests.log相关39项通过，其中Android/Windows×320/390×1/1.3/2几何组合12项；analyze.log无问题；android-release.log release构建成功81.0MB，签名与前版一致。验证后的APK已对427b338f覆盖安装成功并保留数据；未执行真实签到或切换用户其他应用。
- 调研复用了Engineering《界面减法与任务模型》《界面动效自然度调整与回放检查》，知识库没有可直接采用的该款导航/课程收纳实现，公开参考区sliver检索无命中。联网补读Apple浮动Tab与search role、Flutter SliverPersistentHeader/BackdropFilter、sliver_tools README及liquid_glass_renderer要求。本机Flutter3.44，所读玻璃库最新预发布要求3.47和预览GPU API，建议先轻磨砂且不升级SDK。没有添加依赖。
- 校园内容查到信息与网络中心的2026新生服务指南及信息学院分本科/研究生的问答手册；建议搜索结果以应用功能/帮助、当前账号缓存、带来源与适用范围的官方指南分组，后续自然语言问答另定来源更新与模型边界。未抓取/复制个人凭据，不调用外部模型问答。
- 课程方案建议上方不变，下方合并课程和签到以避免同一课程重复；需扩展现有仅current/next的摘要为全天课次。下课与签到完成独立，待处理活动不得因动画而隐藏，不明确匹配的活动单列。两种收纳已用英语10:10–11:50例子向用户解释：时间/状态触发默认收起，与滚动距离触发视觉压叠是不同维度；用户尚未选定，不实施相关主页面改写。
- 具体参考：https://github.com/Kavantix/sliver_tools 、 https://github.com/Fayis2021/collapsible_cards 、 https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html 、 https://inc.xmu.edu.cn/info/1431/9562.htm 、 https://informatics.xmu.edu.cn/welcome/index.html 。collapsible_cards只读README，目录访问/API限额/raw404导致内部源码未核；不声称它是成熟生产方案。完整调研在本地忽略目录docs/research/android-navigation-search-timeline.md，未回写Engineering或强制提交docs。

## 2026-10-29 Android检测融入顶部、内容上移

final result: passed（源码、隔离视觉、相关回归及签名构建）；未声称本轮真机各页已逐项视觉验收。

- 用户确认背景位置可用，只要求签到/我的顶区内容向上、检测状态/开始操作融顶。MobileCampusHeader仅Android将child从centerLeft改topLeft，20内边距、184与字号/宽度增高规则不动，图片top=-60/bottom=0完全不变；Windows仍centerLeft且图片top=0。
- Android首页账号选择与检测操作同一Wrap行，账号宽144保证常用姓名清晰；下方灰点/单行状态处理尚未检测、时段外/无课、切换加载与失败。未登录和切换重试也融入顶区。运行时由既有检测控件呈现倒计时/停止，避免重复状态行；运行优先于列表加载，即使刷新列表为空且isLoading，停止检测仍可使用。原监控权限、时段、退避、身份守卫和提交确认逻辑未修改。
- 正文移除Android空闲/加载/未登录的重复状态卡，课程/待办前移；实际签到任务卡与获取失败重试保留。非Android继续原白色状态卡与原顶部控件，桌面页面不调整。
- 实际查看build/android-header-controls/after/{home-light,running-light,settings-light,long-dark}.png及生产状态浅深色截图。顶部文字较上一轮前移，画幅和建筑位置保持；小屏/1.3字号不横向溢出，图像不是静态UI截图替代真实按钮。
- delivery-tests.log相关76项通过，包括Android/Windows顶图几何与顶部锚点、日期与检测入口位置、主题/登录/账户管理、无课时段限制、QR路由/账号隔离，以及运行中AsyncLoading不挤走停止操作的新增断言。20.00000000000003与20的浮点误差改为.01容差；一次补丁误命中状态字符串分支造成的编译失败已修正，最终测试在修复后的冻结源码上重跑通过。
- delivery-analyze.log无问题；delivery-release.log构建release成功81.0MB，仍0.3.0+6。最终包签名与前版一致，已对427b338f覆盖安装成功；未卸载或清数据、未执行真实签到、未切换用户其他应用、未推送发布。只做Android呈现，不对桌面运行实例作热重载。
- CHANGELOG和本地忽略docs的规格/验收/台账/Android契约已同步。浮动导航/全局搜索/全天课程收纳仍为上一轮调研，不混入本次修改。

## 2026-10-29 Android顶区、首页减法与浮动导航

- 范围仅Android，Desktop延续现有布局；我的/签到共用168基础顶区，窄屏及大字适配增高，图像top=-76/left=18/right=-18，主体随顶区上移16。我的为整行账户摘要；账号切换去外框，检测主操作靠右，运行倒计时/停止同组。运行中列表AsyncLoading仍可停止。
- 首页取消待办及上次签到，仅Android不订阅历史摘要；桌面待办及记录布局保留。四个首页显示浮动四Tab和独立搜索，二级及更深页面隐藏；搜索根路由不重复底栏，返回恢复原Tab。公共嵌套路由观察器驱动底栏，新增数据诊断/返回及搜索/返回回归。
- 作业角标读取当前身份本地待办镜像及已知提交状态，排除关闭/到期/已完成，按课程活动去重；无缓存不显示数字，不额外挂载联网扫描。已知提交状态刷新后修订信号联动，身份切换加载阶段隐藏旧数字。新增Provider隔离、去重、到期及提交回归。
- 搜索提供本地功能/使用帮助、当前身份缓存课程与作业和4个官方指南入口；不访问外部AI、不发送搜索词，作业结果进入该条详情，课程结果标明在课表中查看。身份变化清空查询，个人结果点击有身份守卫。
- 实际查看build/mobile-campus-design/idle-light.png、running-light.png、long-dark.png以及.tools/settings-polish/mobile-account-{light,dark}.png：中文字体、浅深色、窄屏大字和新底栏已复核；搜索截图build/android-masthead-polish/search.png字体最初缺失，补测试专用ListTile字体映射后重新生成并实看中文结果。截图使用生产控件和隔离数据，未声称真机所有页面均已目视验收。
- final-analyze.log无问题；导航聚焦回归nav-regression.log 12项通过，home-only-nav.log 7项通过，搜索字体重渲染1项通过。先前全量807通过/4失败源于旧导航尺寸断言与零数字仍构建Badge，已修正并重新运行完整套件，不隐藏失败。
- final-release.log构建Android release成功81.1MB，仍0.3.0+6；校验既有证书SHA256一致后对427b338f执行install -r成功。未卸载或清数据、未执行真实签到、不接管用户其他应用，未push或发布。构建中的既有Kotlin插件迁移提示不阻止当前构建。
- CHANGELOG及本地忽略docs的规格/验收/台账已同步；不强制添加docs。全天课程收纳仍留待后续，未在本次擅自改写。
- 最终delivery-tests.log完整套件812项通过、2项既有跳过，无失败；delivery-analyze.log无问题。按新要求，原先3项Android二级页点击Tab的旧回归改为通过平台导航入口验证同样的草稿/忙碌守卫，identity-final.log 35项通过后又重跑完整套件。新增首页/二级页底栏显隐回归同时通过。

## 2026-10-29 维护阶段1
规则与四阶段计划已写入本地忽略的AGENTS.md和docs/spec/ROADMAP.md，未修改忽略策略。新增共享作业缓存读取/合并，角标/摘要/搜索能读取课程接口独有作业；Overview写入课程镜像同步修订。新增远端课程缓存清理服务，覆盖教务/成绩与刷新标记并失效内存；用户手工安排/日期/地点保留。
stage1-tests.log相关31项通过，含真实缓存/Provider的课程独有任务与所选身份切换；stage1-focused-analyze.log对9个修改项检查无问题，CHANGELOG结构检查通过。全库分析仍在运行，最终阶段再执行完整检查。本阶段无协议或外观变更，未构建安装。

## 2026-10-29 维护阶段2：检测范围边界
DetectionWindow仅保留区间模型/运算与异常；DetectionWindowStore负责原键名的读取/保存/旧偏好归属，detectionWindowProvider单独接入账号状态。所有使用点改显式导入，不通过模型重新导出Provider。依赖遍历确认MonitorEngine只传递依赖4个Dart文件、不再到达认证或platform，区间模型无项目依赖。stage2-tests.log 80项通过（含身份隔离、旧偏好、时段、忙碌/草稿及QR），stage2-verified-analyze.log无问题。全库分析曾扫到上轮build内的临时审查探针并报测试专用API位置警告，已删除该自有临时文件，未通过修改分析配置屏蔽警告。

## 2026-10-29 维护阶段3：刷新职责与明确状态
作业页取消_lastCheckAt/_lastCheckIdentity/_checking，Overview统一负责有效期和在途合并，ensureFresh返回本调用是否完成检查，避免页面重复刷新提交状态/助教任务。页面仍负责可见性、前后台和计时触发。可见性回归现在调用真实Overview刷新算法，仅替换数据边界并记录实际检查次数。签到顶区通过outsideDetectionWindow接收明确状态，取消根据中文文案contains反推。
stage3-verified-tests.log 65项通过，新增结果契约断言后stage3-unit-final.log 9项通过；stage3-analyze.log对相关7项无问题。保留现有界面与提交/身份约束。

## 2026-10-29 维护阶段4：呈现方式与读取入口
检测按钮从4个可任意组合的布尔开关改为实际使用的MonitorControlStyle，动作流程/布局不变。搜索功能与官方指南目录移到campus_search_index.dart，个人结果导航复用同一身份边界，删除无效图标条件。GradeRecord构造时解析学分、绩点和数值成绩并固定原始快照；计算使用typed fields，保留本科字母分数、研究生、合格制、N/A与荣誉绩点规则，缓存格式不变。
final-tests.log全套815项通过/2项既有跳过（最后补充的清理页回归随后单独验证）；final-analyze.log无问题，stage4-grade-tests.log 20项通过，final-captures.log生产组件11项通过。已实看浅色首页及窄屏深色长内容；idle-light/idle-dark与改动前SHA256分别相同，证明样式参数整理保持这两种画面逐字节一致。未执行真实签到/联网成绩查询，未操作日常窗口或重建安装包。

## 2026-10-29 沿途修复：清缓存覆盖协助账号内存
显式清理远端缓存改为invalidateRemoteCourseMemoryFromWidget，覆盖各账号的活动列表、目录、历史与先验；登出仍沿用原主号失效范围，不删磁盘。移除仅用于转发invalidate/clearSeen的一次性包装，两个入口直接表达各自清理范围。新增SettingsDataPage实际点击/确认回归，验证教务磁盘删除及协助活动Provider重新读取；首次测试遗漏Toast计时器清理，已按现有AppToast.dismiss收尾，未修改产品代码规避测试。
clear-flow-verified.log 11项通过；冻结源码后delivery-tests.log完整816项通过/2项既有跳过，delivery-analyze.log无问题，delivery-ci-tests.log交付21项通过，CHANGELOG结构检查通过。所有四个维护阶段完成。全量教务行DTO迁移、其余页面间循环依赖与本地规范公开化不在本轮迁移范围，后续在对应功能触及时处理；未新增框架/依赖或生成代码修改。
- 最终Android Release构建成功81.1MB（android-release.log），仍0.3.0+6，证书SHA256与既有包一致。ADB当前无设备，因此没有安装或清理真机数据；未push/发布。安装包保留dist/xmu-rollcall-0.3.0-android.apk供后续覆盖安装。

## 2026-10-29 课表类型化阶段1
AcademicCourseRow作为教务课次的内部类型，academic_parsing保留网络/缓存入口的外部转换；AcademicSchedule、关联、今日课程、地点与搜索使用明确字段。原JSON字段名保持兼容，周次写回规范化掩码（保留实际周次），原空BJDM关联键course/null保持。新增旧缓存读取、输入快照、隐私字段排除、读写往返、错误周次在缓存入口处理的回归；测试夹具直接使用生产解析器，没有复制业务算法。
stage1-verified-tests.log 71项通过，stage1-analyze.log对lib/test检查无问题；包括真实课表样本、单双周、多教室、账号缓存与桌面/Android组件。当前未声称真机或线上接口验收，最终阶段再做完整回归与图像对照。


## 2026-10-29 依赖维护阶段2
认证默认Provider只创建AuthController，跨模块生命周期动作由main的ProviderScope使用app/auth_session.dart接线；协助分享移除目录Provider反向读取，保留先落盘后发布的同一目录。生产接线回归发现原回调读取自身Provider触发Riverpod断言且错误被吞掉，改为检查当前控制器登录身份，保留异步身份边界。stage2-verified-tests.log相关39项通过，stage2-analyze.log对lib/test无问题；新增失效会话完成同步回归后stage2-wiring-final.log 3项通过。无布局或协议改动。


## 2026-10-29 依赖维护阶段3：页面组合与地图配置

协助名单页独立于导入/导出弹窗；课程作业页接收详情构建回调，详情页负责组合导航；地图常量单独存放，签到位置预览直接读取配置。保持全部布局参数。拆分初次检查暴露签到预览依赖选点页重导出的常量，已改显式导入；新导航测试使用应用自己的返回控件，补齐提交状态边界替身后最终回归通过。

- stage3-final-tests.log相关35项通过，含详情→课程列表→另一条详情→返回与课程上下文补齐、协助名单/导入和各尺寸地图交互。
- final-tests.log完整821项通过、2项既有跳过；delivery-analyze.log全库无问题，ci-tests.log交付21项通过，CHANGELOG结构有效。
- import-graph.txt对221个Dart文件及条件导入/导出执行Tarjan扫描，循环分量为0。未增加依赖或通用路由框架。
- final-captures.log生产组件11项通过；实看浅色首页和窄屏深色长内容。idle-light/idle-dark与改动前PNG逐字节相同，SHA256分别为9bdbdec408cd12e7d6bbda4d15e2d55447d2ded9bc983b07776303e59d743425、ffac8814d8a20968f4c81ce9e26529059888c7efad34582cd236950675c5211f。桌面由既有工作区/课表/设置多尺寸组件测试验证，未声称全页面真机验收。
- Android Release编译成功（android-release.log，81.1MB，仍0.3.0+6），APK固定证书SHA256与既有值7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5一致。保留既有Kotlin插件迁移提示，本轮未改依赖；未安装真机、执行真实签到、push或发布。


## 2026-10-29 二轮全项目审查阶段1

项目盘点覆盖221个Dart文件、Android原生入口、Windows runner及交付脚本；按数据/生命周期热点定向检查，不把文件长度或可再抽象列为缺陷。目录在途复用已由catalog-repro.log复现：切到账号2仍得到owner-one。目录增加与Provider有效期一致的请求修订号、重建释放旧在途引用，旧请求不可发布/落盘；延迟教务同步同样检查有效期。

stage1-tests.log相关49项通过，stage1-lifetime-tests.log两项生产Provider回归通过（实际会话切换和同账号invalidate），stage1-analyze.log对lib/test无问题。未变更样式或协议。下一阶段处理显式协助课表读取全局地点数据的范围错误。


## 2026-10-29 二轮全项目审查阶段2

显式账号的地点数据贯穿课表提示、详情地图、管理/选点与保存；不修改全局选择或停止该账号之外的检测。新增按用户读取的Provider，当前身份复用原地点控制器，保留现有默认入口与测试覆盖；全局切号后显式控制器重载，避免再次看到旧地点。现有列表分组、间距、地图参数全部保留。

stage2-verified-tests.log相关68项通过，stage2-explicit.log真实课表→地点管理→地图选点→保存通过，stage2-scope-final.log额外验证全局切换期间编辑和返回重读；stage2-final-analyze.log对lib/test无问题。初次测试使用带A区的楼宇名称查找独立行，实际界面按楼宇聚合，改用无分区的测试楼完成同一范围回归；未更改UI适配测试。


## 2026-10-29 二轮全项目审查阶段3及范围结论

P1历史缓存失效由history-before.log真实回归复现：同账号删去课程历史并invalidate后，挂起的请求写回CourseRollcallsSnapshot。加载/迁移/刷新/逐条发布现统一使用Provider有效期，替代只比较用户ID的判断；旧成功和失败响应均停止落盘及发布，保留现有候选/限流/逐课发布。stage3-tests.log相关48项通过；最终完整套件另含成功与失败两条失效回归。

本轮覆盖的模块及处理：

| 范围 | 重点与结论 |
| --- | --- |
| 认证/会话/协助 | 检查安全存储、Cookie替换/请求撤销、主号与导入身份路由；修复课程目录切号复用，未修改协议和稳定deviceId |
| 课程/历史/作业/成绩 | 检查缓存键、失效、在途合并、增量与失败保留；修复目录及历史有效期，作业/成绩已有修订号和身份边界继续保留 |
| 地点/地图/课表呈现 | 修复显式账号误用全局地点；同一账号当前/显式入口复用控制器，手动安排与手动雷达也传递正在操作的身份 |
| 检测/自动应答/Android后台 | 检查任务当前性、提交前重读位置、终止与有限重试、独立会话及SharedPreferences重新加载；未发现本轮可复现的新缺陷，不改默认确认/频率 |
| 网络/日志/更新 | 检查安全方法退避、取消/限流、日志脱敏、下载大小/SHA256、分片清理、Android签名及构建号检查；未发现需扩展策略的具体证据 |
| 平台/交付 | 盘点5个Kotlin入口、12个Windows runner文件、14个交付/辅助脚本；定向检查平台通道/更新/通知入口与CI产物校验，协议适配和原生改造未扩张 |

不因49k行源码或单文件体积继续拆层；保留现有布局/导航、依赖、CI流程及前次已消除的导入环。真实校园接口、安卓后台长驻/通知/安装和Windows通知激活仍须设备/环境验收，本轮测试不替代这些验收。没有声称已证明所有代码无缺陷。


最终证据：final-tests.log完整827项通过/2项既有跳过，final-analyze.log全库无问题；ci-tests.log 21项通过，CHANGELOG校验通过。import-graph.txt对221个Dart文件（含条件import/export）扫描循环0。captures.log生产控件11项通过；实看浅色首页与深色窄屏长内容，pixel-comparison.txt确认idle-light/idle-dark与改动前逐字节一致。桌面工作区、课表、地图、设置和返回行为由原有多尺寸组件回归验证，本轮未改布局参数。

android-release.log编译成功81.2MB（本地验证仍0.3.0+6），apk-signature.log核对固定证书SHA256与既有7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5一致。未安装真机或执行真实签到、未push/发布。全部已复现问题均已处理；未通过猜测继续扩张技术债清理。


## 2026-10-29 教务访问阶段1

客户端创建和主号/协助身份解析移到academic_access；课表和成绩从同一工厂得到独立客户端，并共用一个RateLimiter。AcademicIdentity独立定义，直接构造的同步器复用同一主号凭据解析函数；业务有效期由各自Provider/同步器保留。stage1-verified-tests.log相关30项通过，包括真实HTTP适配器/队列的跨业务阻塞与释放、身份凭据分离/撤销及已有课表/成绩协议回归。未新增依赖或改UI/数据格式；最终分析结果在stage1-final-analyze.log。


## 2026-10-29 教务访问阶段2

旧academic_client拆为公共AcademicSession、AcademicTimetableReader、AcademicGradeReader和AcademicSync；共享外部解析函数移到academic/。成绩专用Referer/Origin/XHR头留在GradeReader，Session按业务传入的应用ID建立会话，构造时仅装一次CookieManager；成功读取统一保存原键同格式安全快照，finally关闭本次HTTP。移除旧混合文件和转发兼容层，生产和协议测试均改显式依赖。

stage2-final-tests.log相关46项通过；新增成绩快照→新会话恢复及请求头不泄漏、错误成绩不覆盖旧快照。原成绩上下文断言现通过完整生产GradeReader/HTTP适配器执行，未为测试保留专用生产方法；测试辅助readGrades只调用真实Reader。stage2-final-analyze.log对lib/test无问题。初次拆分的测试构造/清理和导入迁移编译错误已修正，最终结果无失败。UI、账号数据/缓存格式和计算规则未改。


## 2026-10-29 教务访问阶段3：完整交付验证

- final-tests.log完整831项通过、2项既有跳过；final-analyze.log全库无问题，ci-tests.log交付21项通过，CHANGELOG结构有效。
- import-graph.txt扫描226个Dart文件（含条件导入/导出）循环0；AcademicSession的传递依赖不再包含课表/成绩业务文件。
- captures.log生产控件11项通过，实看浅色首页与窄屏深色长内容；pixel-comparison.txt确认idle-light/idle-dark与改动前PNG逐字节相同。桌面现有工作区/课表/设置/地图多尺寸回归包含在完整套件中；未修改任何布局源文件。
- android-release.log编译成功81.2MB（本地验证仍0.3.0+6），apk-signature.log固定签名SHA256为7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5，与既有包一致。既有Kotlin插件迁移提示未扩展为依赖升级。
- 本轮未读取真实账号凭据/查询校园接口，未重新安装手机、未push或发布。教学/成绩缓存、SecureStore键、默认提交确认与畅课会话机制未改；今后新教务数据的接入约定已写入本地docs/ARCHITECTURE.md“教务数据扩展入口”。
## 2026-10-30 三类签到开发预览

### 等宽按钮、直接补充签到与用户文案

- Android任务卡操作统一96宽、紧凑高度及原触控区，覆盖两字/四字和完成/结束状态；停止检测改为Fluent实心方块。历史/设置入口采用44宽触控盒、向右对齐，图标右缘与检测按钮右缘一致；移除按中文文案判断检测范围的旧展示分支，直接使用范围状态。
- 缺码不再打开二级输码页，复用应用输入对话框，展示课程、输入框和取消/签到；点击签到即本次明确提交，复用原数字提交函数与限流/去重，取消不发请求，跨弹窗账号/活动变化不提交。成功将手填码和完成状态同步已有列表。
- 缺点直接进入地图选点页，复用MapPickPanel，保留当前位置和已保存地点入口；未显式选点禁用签到，不把默认地图中心当用户选择；选点后底部签到直接复用原雷达提交/坐标校验/账号守卫/成功记忆。保留地图选点视角，只有切换系统定位或已保存地点才重建到明确的新点。正常用户页面不再经过原确认卡和额外确认弹窗，非Android维持原提交流程。
- 已保存地点选择器沿当前Navigator及明确userId运行，避免预览弹窗脱离隔离ProviderContainer或写入另一账号；回归断言弹窗与首页使用同一预览容器。成功仅更新已存在的活动Provider，避免为更新完成状态重新创建列表并额外抓取。
- 首页只保留今日无课/暂无课表/课外暂停，具体时间留在「今日检测时间」；签到设置和扫码页使用自动检测、签到方式、何时签到、为谁签到等用户文案，不展示异常对象。任务卡更新时间使用实际抓取时间并转换本地时间，不能被首页检测提示替代。
- 94项聚焦回归通过（build/rollcall-dialog-picker-final-tests.log），覆盖弹窗确认/取消/账号变化、选点前后按钮状态及实际本地模拟提交、人数、二维码、定位生命周期、检测策略与桌面旧流程。最终选点弹窗作用域8项复核通过（build/rollcall-dialog-picker-scope-final-tests.log）；补充时间与文案隔离回归后11项反馈回归通过（build/rollcall-dialog-picker-timestamp-final-tests.log）。完整lib/test静态检查和最后相关文件检查均无问题（build/rollcall-dialog-picker-package-analyze.log、build/rollcall-dialog-picker-timestamp-analyze.log）。
- 查看390×844的ready.png、number-dialog.png和radar-picker.png：按钮同宽、图标右对齐、输入弹窗与地图底部动作正确。测试拦截地图网络瓦片，仅验证地图控件和选点/提交，不能作为在线底图或真机逐页验收。最终Android Debug构建成功（build/rollcall-dialog-picker-phone-final.log），签名一致，对427b338f覆盖安装成功，保留0.3.0+6和账号数据；无真实签到、推送或发布。

### 输入字号、补充动作与检测状态原位切换

- 数字左侧改为Fluent「#」图标，与22号数字同尺寸；地点和「二维码」文字改18号，图标同18号并随文字缩放。去掉「扫描课堂」前缀。缺码只显示「无法获取签到码」，按钮「手动输入」；缺位置按钮「选择位置」，可靠点仍按此前授权直接签到。按钮与定位展示共享同一解析Future，解析中暂不可提交，点击时仍重新读取并复核。
- Android运行中的倒计时移入原左侧状态行（含等宽数字「检测中 xx s」及真实的等待/重试/处理中状态），原右侧OutlinedButton以相同尺寸/样式从「开始检测」变为「停止检测」。状态行不再移除，动作区的垂直偏移不随running变化，避免开始后上跳；原停止控制器、后台检测及刷新策略不变，未增加网络轮询。
- 39项相关回归通过（build/rollcall-status-inputs-tests.log），含启动前后按钮top/left和状态行top一致、倒计时100→9宽度一致、刷新期间停止按钮保留、缺输入动作及直接提交。最终图标后预览3项重跑通过（build/rollcall-status-inputs-preview-final.log），新增图标字号与文字字号一致断言。全lib/test静态检查无问题；最终图标相关3文件复核无问题（build/rollcall-status-inputs-focused-analyze.log）。
- 实际查看build/rollcall-home-preview/started.png及missing.png：左侧倒计时、原位停止、放大输入、缺码/缺点按钮正确。隔离截图不是手机逐页视觉验收。最终Android Debug构建成功（build/rollcall-status-inputs-android-final.log），签名一致，对427b338f执行adb install -r成功，保留0.3.0+6与账号数据；没有真实签到、推送或发布。

### 卡片输入图标化与紧凑按钮

- 去掉Android卡片「签到码」标题和坐标行，数字/地点/二维码提示左侧统一18px Fluent图标；数字仍通过原_copyCode点击复制，移除Android数字右侧重复复制小图标。定位解析和提交验证仍保留完整坐标，仅精简显示，非Android外观不变。
- 按钮可见最小尺寸从88×44降至72×36，内边距14/8并保持padded触控区域；输入和按钮改为垂直居中。二维码待签文案「扫码」，数字/定位仍为「签到」，完成仍灰色禁用「已签到」。
- 32项布局/复制/提交/完成反馈/手机首页回归通过（build/rollcall-card-compact-tests.log），新增实际Clipboard.setData捕获1234验证；覆盖坐标/标题不显示、二维码入口、12种场景、320宽大字与浅深色。flutter analyze --no-pub lib test无问题（build/rollcall-card-compact-analyze.log）。实际查看build/rollcall-home-preview/ready.png和completed.png隔离截图，不代称真机逐页验收。
- Android Debug构建成功（build/rollcall-card-compact-android.log），证书一致，对427b338f执行adb install -r成功；保留0.3.0+6及账号数据。未执行真实签到，没有推送或发布。

### Android签到卡四角布局

- 按用户指定重排正式Android任务卡：左上课程与老师、右上人数与更新时间、左下数字码/定位/扫码提示、右下签到按钮。去除顶行待签/完成标签、类型标签及更多菜单；未签按钮文案「签到」，完成后保留输入信息并显示默认灰色禁用「已签到」，结束为禁用「已结束」。中性细边框、16圆角/内边距、19号课程名与44高主按钮，减少重复信息。
- 单独Android呈现方法复用原_mobileSubmit、定位解析和AttendanceCountRow；可靠输入直接提交、缺输入补充、完成去重、人数暂停和最终一次人数读取均不变。非Android触控及桌面保留原卡片及按钮文案。
- 布局/首页12场景/快速提交32项通过（build/rollcall-card-layout-tests.log），含四角位置断言、无状态/类型/更多菜单，以及320宽/1.3倍文字/长课程和教师名/浅深色无溢出。补充人数与二维码流程40项通过；一个Windows窄屏测试曾误跟随Android按钮改名，恢复其原有「去签到」断言后定向重跑通过（build/rollcall-card-layout-windows-regression.log），对应产品外观未变。最终flutter analyze --no-pub lib test无问题（build/rollcall-card-layout-analyze.log）。
- 实际查看build/rollcall-home-preview/ready.png、completed.png及card-narrow-light.png/card-narrow-dark.png。窄屏补充回放通过（build/rollcall-card-layout-narrow-render.log），截图先滚到卡片顶部确保长标题可见。均为隔离Flutter渲染，不代称真机逐页视觉验收。
- Android Debug构建成功（build/rollcall-card-layout-android.log），签名核对一致，对427b338f执行adb install -r成功，0.3.0+6并保留账号数据。没有代用户提交真实签到，没有推送或发布。

### 完整首页与12种方式/状态组合

- 原入口改名「签到首页」。直接挂载正式MobileRollcallHome、PageScaffold/AppContentColumn、RollcallAccountMenu和AppMobileNav，保留页头水彩、日期/账号、检测控件、今日课程、任务排列、下拉反馈和底部导航。场景控制在首页外的工具栏，撤掉独立卡片列表及卡间模拟按钮；二级签到仍在隔离Navigator中。
- 12种预设：三类待签且信息齐全、三类缺码缺点、数字已签/定位和扫码待签、全部已签、待签/已签/结束混合、单数字/单定位/单二维码、空列表、刷新中、检测中、刷新失败。选择或重放清空预览列表并回顶，再通过真实首页AppPullToRefresh加载；默认活动时间与示例课表一致，缺点场景的课表地点同样未知，不伪装成可自动匹配地点。
- MonitorController新增默认开启的bootstrap参数；预览子类显式关闭原生监听、持久偏好加载和后台恢复，仅模拟检测起停及手动刷新。正式调用保持默认行为，预览不迁移monitor_legacy_owner或接管手机现有检测。凭据、名单、课表和历史仍在独立ProviderContainer，所有签到HTTP使用无网络回退的本地adapter。
- 30项聚焦回归通过（build/rollcall-home-preview-final-tests.log）：12种组合、完整首页挂载、检测起停、真实数字/定位直接提交、缺输入补充、二维码本地提交，以及原手机首页/快速签到/检测设置/人数暂停。首次测试发现结束卡本来有两处「已结束」文案，修正测试为验证存在后重跑通过。查看build/rollcall-home-preview中的390×844隔离截图，含信息齐全、部分完成、全部完成、空态、缺输入及刷新失败；这是隔离渲染，不冒充真机逐页验收。全lib/test静态检查仅报7处新测试的单行if格式提示，补齐花括号后定向flutter analyze复核无问题（build/rollcall-home-preview-analyze-test-final.log）；生产源码无剩余诊断。
- Android Debug构建成功（build/rollcall-home-preview-android.log），比对原签名一致，对427b338f执行adb install -r成功；0.3.0+6，保留账号数据。没有代用户打开真实签到或提交，没有推送或发布。

### 数字码、定位与直接提交修正

- 上版复用了真实任务卡，但Android卡片漏显数字码和可靠定位，雷达样例也没有课程ID及可靠点。现正式Android任务卡展示数字码、可用点名称和坐标；从原点击流程抽出位置解析供展示/提交共用，点击仍重新读取，队列发送前继续验证身份、活动和点位。位置偏好、个人点、拒绝记录及补充页返回后重新读取显示；不改非Android外观。
- 预览默认配好1234与学武楼A区内置坐标；数字/雷达真实按钮直接走本地HTTP模拟提交。开关关闭时缺码/缺点再进入原补充页，撤掉上版额外的手填页入口。模拟点归预览账号，位置为明确课程配置，不给真实账号增加授权。
- 67项相关回归通过（build/rollcall-preview-inputs-final-tests.log），包括点位展示、可靠输入直接提交、缺输入补充、拒绝点/活动时间/身份与点位变化守卫、人数暂停以及二维码身份流程。最终字体修正后单项预览回放再次通过（build/rollcall-preview-inputs-render.log），实际查看390宽长截图build/rollcall-preview/three-types.png，数字码与定位可见。最终flutter analyze --no-pub lib test无问题（build/rollcall-preview-inputs-final-analyze.log）。
- 最终Android Debug构建成功（build/rollcall-preview-inputs-android-final.log），证书与原包一致，设备427b338f执行adb install -r成功；版本0.3.0+6，保留数据。未操作真实签到，也未代用户打开页面；隔离截图不能代称真机逐页验收，没有推送或发布。

- 在原「我的 → 数据与诊断 → 开发预览」增加「三类签到」，不新增应用。初始为空，刷新出现数字/雷达/二维码真实任务卡，可进入既有补充页、模拟完成、恢复待签和重置；二维码提供复制模拟内容按钮。
- 页面内独立 ProviderContainer 和 Navigator 保持二级页的模拟作用域。凭据只在内存；SessionClientRegistry 的所有客户端使用本地 Dio adapter，名单、历史及雷达偏好与真实账号分离，不迁移用户旧偏好。模拟适配器没有网络回退。
- 最终相关回归20项通过（build/rollcall-preview-tests-final.log），包括真实数字提交、雷达补充页、二维码粘贴提交/临提交复核、完成状态、重置，以及原快速签到/完成反馈回归。检查旧雷达偏好哨兵未被迁移或删除。flutter analyze --no-pub lib test最终无问题（build/rollcall-preview-analyze-focused.log）。早期测试的滚动定位、真实时钟限流和Toast计时收尾问题已修正后重跑；额外直接运行dart analyze时遇到分析服务关闭时删除本机perf文件失败，标准Flutter静态检查正常结束。
- 实际查看390宽隔离渲染build/rollcall-preview/three-types.png；卡片与当前Android组件一致，可滚动查看全部类型。这是隔离视觉证据，不代表真机逐页验收。
- Android Debug构建成功（build/rollcall-preview-android-debug-final.log）；保留0.3.0+6，apksigner比较与手机原包证书一致，对427b338f执行adb install -r成功，保留账号数据。Debug构建用于显示既有开发预览入口；没有代用户打开页面或执行真实课堂提交，没有推送或发布。


## 2026-10-30 完整课间与签到流程复查

- 课间移除10分钟上限，按实际小节结束至下一小节开始生成完整窗口；课前、课后仍各10分钟。合并教务课次沿用课表节次及共享校级作息恢复内部边界，不新增用户设置。
- 修复同一运行中旧活动在后续课次再次进入处理的问题：活动ID固定首次观察课次，后续日期过滤旧ID，成功只记原课次。
- 检查课表缓存/保守关联/真实日期、范围排除、成功记录、完整探查、启动恢复、仅提醒、自动提交的调用路径。提交沿用身份和活动复核、排队前点位检查、按活动去重、请求限流与退避；没有扩大自动提交授权。
- 新增5项回归，聚焦43项通过（build/watch-focused-tests.log）。全量879项通过、2项既有跳过（build/watch-review-full-tests.log）；最后将教务夹具改为真实20261学期及第8/10周，相关10项再次通过（build/watch-review-calendar-tests.log）。flutter analyze --no-pub无问题（build/watch-review-analyze.log）。
- 设置截图回归8项通过（build/watch-review-captures.log），实际查看.tools/monitor-typography/monitor-settings-960-light-off.png、monitor-settings-960-dark-course-watch.png及monitor-settings-320-dark-off.png：课间显示“按课表时间”，说明换行正常、无控件溢出。
- 仅修改源码和文档；未重新构建/安装桌面开发版，未操控用户日常窗口，未执行真实课堂签到、开机重登或休眠唤醒验收，未更改本机启动项，未push/发布。docs沿用本地忽略规则。


## 2026-10-30 设置入口与胶囊开关修订

- 将启动后继续值守、开机启动及托盘说明从签到设置移到桌面设置“运行与启动”，桌面窄布局同样提供；移动端不新增启动项。复用原主账号/课表值守条件、偏好键和WindowsStartup，仅显式点击系统开关才写入；测试使用假系统边界，没有修改本机启动项。
- 公共AppSwitch改为固定18px圆点、44×28胶囊及44px点击高度，240ms缓入缓出平移并渐变轨道色，取消指针悬停/按压光圈。保留Tab/空格/回车、拖动、RTL、禁用语义和系统减少动画；键盘焦点仍可见。父组件重建不会重启动画。
- 聚焦34项通过（build/startup-switch-focused-final.log），包括开关实际中间帧、悬停像素一致性、输入/无障碍、启动偏好分别保存及页面入口迁移。初轮两处旧页面测试因新增分组后通知组在懒加载范围外而失败，改为按实际滚动访问后通过，没有修改生产列表来迎合测试。
- 全量885项通过、2项既有跳过（build/startup-switch-full-tests.log）；flutter analyze --no-pub无问题（build/startup-switch-final-analyze.log），git diff --check通过。
- 已实际查看build/switch-ui/off.png、120ms.png、on.png，确认中间位置存在且圆点不膨胀；已查看.tools/settings-polish/960-light-startup.png和960-dark-startup.png，启动项位于设置的外观与窗口后、通知与维护前。相关原窄屏/大字体设置回归亦通过。
- 本轮仅源码及隔离渲染验证，未重建/安装桌面开发版、未操作用户日常窗口，未做原生运行帧率/开机登录或真实签到验收；未push/发布。docs按项目既有忽略约定本地维护。


## 2026-10-30 启动项顺序与当前开发实例热重载

- 按用户纠正，运行与启动先列开机启动，再列启动后继续值守；加入真实组件纵坐标断言防止顺序回退。相关21项回归通过（build/startup-order-tests.log），flutter analyze --no-pub无问题（build/startup-order-analyze.log）。
- 用户明确要求更新正在运行的开发实例。核对xmu_rollcall.exe来自当前工作区Debug目录，通过其已运行Flutter Tools注册的reloadSources服务完成增量编译/热重载，返回Success（build/startup-order-hot-reload.log）；没有重启应用或启动第二个实例。
- 读取运行中VM的startup_settings.dart脚本确认开机启动位于恢复值守前；当前Widget摘要树无ErrorWidget。没有代用户切换页面、签到或改动开机启动设置。此次热重载包含前轮已提交的公共开关动效和启动设置入口迁移。


## 2026-10-30 桌面检测状态行与正交组合

- 开始/停止控件只负责启动/暂停；下方原更新时间行统一显示运行、下一秒数/真实课表窗口、无安排、今日完成、重试及自动处理提示。停止忽略旧等待/失败标记，有待签活动优先于无课/完成。普通范围与检测频率在值守开启后仍显示，范围文案明确普通检测与值守窗口的区别；切换范围不显示短暂读取提示。
- CourseWatchWindow由实际参与课次生成今日有安排/今日全部成功；引擎发布同一规划及处理消息，UI不另算课表、不新增网络定时器。状态显示真实区间起点，不把无课时次日00:00的本地再规划时间误作网络检测。完整状态、触发与设置矩阵维护于本地docs/spec/MONITOR_STATUS_MATRIX.md。
- 修复默认成功一次策略可被同批多个活动绕过；每活动处理前复核该课次是否完成。服务端确认手动/其他端已完成，也只记原课次并更新后续规划；完整探查保留后续活动。回归断言完整/非完整×直接提交/服务端已完成四种真实repository调用次数，以及当日下一门课/下周课程不被误屏蔽。
- 全量907项通过、2项既有跳过（build/monitor-status-full-tests.log）；flutter analyze --no-pub无问题（build/monitor-status-analyze-verified.log）。实际缓存与协议/Provider回归、Android原单批任务、入页缓存/任务拥有刷新约束均保留。
- 浅深色9种呈现、逐秒倒计时、暂停回开始及范围开关无闪烁的渲染回归通过；实际查看build/desktop-ui-review/monitor-status-countdown-light.png、monitor-status-no-class-today-light.png、monitor-status-complete-dark.png。最终去掉隔离MaterialApp调试角标后重新生成截图；最后23项状态/生命周期回归通过（build/monitor-status-final-checks.log）。
- 首次热重载被VM拒绝，具体报告为MonitorState的const字段布局发生变化；将新增字段移至原字段末尾，保持现有实例布局。未改业务逻辑或分析配置规避错误，兼容顺序后定向分析通过（build/monitor-status-live-compat-analyze.log）。切换身份的中性提示与错误颜色分别呈现，相关两文件最终分析无问题（build/monitor-status-color-analyze.log）。
- 最终通过当前实例Flutter Tools热重载成功（build/monitor-status-live-reload-final.log），运行中Widget树有1个MonitorStatusLine、0个ErrorWidget；没有重启应用。只读核对时该任务已暂停，保留暂停状态，没有代用户开启检测/值守或实际提交。未修改本机启动项、未push/发布；真实课堂和原生长时间验收仍未进行。
- 临时热重载脚本改放系统临时目录，删除本任务此前放在build的自有调试脚本；未修改分析排除规则，避免临时工具被当作生产Dart扫描。


## 2026-10-30 值守独立、手动确认与比例等待修订

- 按用户确认同课同时间仅一个活动，撤销canProcess及其控制器接线/同批双活动组合测试。保留活动去重、课次成功记忆与onAlreadyAnswered，不因缩减防御而删除实际身份/提交边界。
- 值守发现及活动复核不再读取普通范围偏好；普通范围变化不唤醒值守。引擎原值守规划、可靠课堂处理窗口及全局限流继续有效，没有添加每秒网络请求。未运行任务时的入页策略未改：全天模式30秒门槛、按课表模式有效缓存恢复，无固定后台定时刷新。
- 桌面顶部刷新、列表下拉和重试共用原手动请求，结果成功/失败显示5秒，随后恢复运行状态；期间普通值守更新不覆盖反馈，手动成功也不沿用后台失败色。离开Tab/切换身份清除反馈，旧身份响应不写新界面。新增组件回归推进4秒/1秒并切换自动处理/停止，验证反馈期限、下拉入口及失败结果。
- 移除待办“更多X项”、阶段卡片下方长课间说明；状态文字不使用中间点分隔。比例/人数说明改为未达设定条件不提交，移除等待人数5分钟切轮逻辑；65分钟未达门槛回归没有取码/提交，达到后才提交。保留请求响应过慢时重新复核的原约束，不把此前等待人数时间计入该响应时限。
- 全量906项通过、2项既有跳过（build/watch-refinements-full-tests.log）；104项聚焦通过（build/watch-refinements-focused.log）。最后统一列表刷新/重试入口及文案后52项UI回归通过（build/watch-refinements-final-ui-tests.log）；flutter analyze --no-pub无问题（build/watch-refinements-verified-analyze.log）。早轮两处if格式提示已修正，没有修改分析配置。
- 实际查看.tools/desktop-workspace/rollcall-1120-light-1.0-dpr1.0.png及.tools/monitor-typography/monitor-settings-960-light-course-watch.png，确认右栏只留右上查看全部，值守卡片无多余说明，普通范围/间隔仍可见。
- 当前开发实例热重载Success，Widget树0个ErrorWidget、1个MonitorStatusLine（build/watch-refinements-live-reload.log）。没有重启应用、没有替用户开启任务或执行真实签到，没有修改本机启动项、push或发布；docs继续按本地忽略约定维护。


## 2026-10-30 当前学期课程与教务课表来源

- 只读检查开发版日志与本地缓存：协助目录34门（跨2023—2026年），同账号教务课表3门/7行；旧日志的history.ensureFresh确有旧课程候选。根因是平台ongoing结果包含旧课程、目录长期复用且教务关联/规划保留了平台及补充时间。
- 当前目录先按明确学期过滤再关联；值守/检测/历史与作业课后时机使用教务时间，保留未排课课程的业务身份与旧编辑器元数据。未删除目录、签到历史、地点、值守成功记录或账号凭据。
- 本机临时只读回归直接解析当前协助目录与教务缓存，断言34→3、3门均关联、无额外教务虚拟课程；无缓存写入。该探针已移除，用户缓存未作为测试夹具入库。
- build/course-source-final-tests.log：全量909通过/2既有跳过。新增历史隔离回归随后在build/course-source-history-scope.log通过（3项），确认旧记录磁盘保留且不展示，不发送目录请求。
- build/course-source-final-analyze.log：flutter analyze通过。聚焦回归涵盖值守排程、教务窗口、身份隔离、历史候选、作业和旧编辑器。
- 已实看build/course-watch-scope/light.png与dark.png：部分选中为实心横线、圆角复选框，时间两侧留白。起停值守文字矩形相等断言通过。无中点分隔，普通检测/值守区分脉冲/盾牌图标。
- 本轮为源码及Flutter隔离渲染验证；未重启/替换当前Windows开发实例，未执行Android真机、真实签到或多端线上验收。


## 2026-10-30 值守课程双列与未运行状态

- 值守课程正文上限1040px，宽度至少728px时双列独立纵排，16px列间距和12px卡片间距；窄屏单列。未引入布局依赖或固定卡片高度。四门不同安排长度的生产卡片回归验证两列顶部对齐、后卡分别紧跟本列前卡，筛选排除/部分选中及全不选恢复仍可持久化。
- 仅选择值守模式不代表任务运行；设置中显示“未运行”。停止/未开始时状态行采用普通范围说明或更新时间，不用旧lastPollAt/discoveryWindow覆盖为“值守已暂停”。实际运行才按引擎计划显示等待与下一窗口；未变更网络入口、任务计时器或限流。
- build/watch-columns-final-tests.log：64项通过，覆盖两列/单列浅深色、实际缓存恢复与手动刷新、两种模式下运行任务拥有刷新及停止后恢复原普通入页策略、五秒手动反馈、状态及身份/二维码回归。
- build/watch-columns-settings-tests.log：8项设置回归通过；build/watch-columns-analyze.log：flutter analyze无问题。此次为界面及状态投影改动，未重复全库回归。
- 已实看build/course-watch-columns下960-light、960-dark、384-light、384-dark共4张隔离渲染截图。两列不强制等高，窄屏可读，实心横线及柔和悬停保留。未执行Android真机或真实签到验收。

- 已热重载当前Windows开发实例：Reloaded 3 of 3287 libraries；通过运行时Script源确认双列布局与未运行普通反馈已载入。保留登录、本地数据及当前页面，无热重启；未宣称用户交互验收完成。


## 2026-10-30 页面渲染与重复计算审查

本轮覆盖签到/检测、历史、作业、保留Tab、课表、校园摘要、GPA、地图与移动导航的源码热路径；只对已复现的重复工作做聚焦修改，未引入通用缓存框架、附加网络定时器或批量RepaintBoundary。

| 隔离场景 | 修改前 | 修改后 | 证据 |
| --- | --- | --- | --- |
| 追加20条日志 | 检测按钮20次、状态行20次重建，普通区间检查20次 | 三项均0次 | render-work-before.log / render-work-after.log |
| 等待下一课5秒 | 状态行重建5次、无关普通区间检查5次 | 两项均0次 | 同上 |
| 隐藏按钮5秒 | 普通区间检查5次 | 0次 | 同上 |
| 200条历史切换状态筛选 | 时间字段访问10,691次 | 17次 | history-work-before.log / history-work-after.log |
| 作业无数据变化的失焦/恢复 | 整页重建3次 | 0次 | homework-render-before.log / homework-render-after.log |
| 5个保留Tab、60次窗口resize | IndexedStack对照300次布局 | 当前可见60次、隐藏0次 | homework-render-after.log |

日志路径均在build/，未入库；新增render_work_test.dart通过Flutter的debugOnRebuildDirtyWidget记录实际生产组件重建，在模型getter/普通范围边界记录计算次数，不复制业务算法。历史计数维持先按原筛选范围去重的规则，仅跳过无需展示排序的日期比较；完整汇总随源列表改变更新，在页面释放时自动释放。作业数据仍由原Provider发布，前后台和Tab刷新门槛保持。

### 已落实

- MonitorQuickControl只订阅起停所需字段，Android状态样式额外订阅倒计时所需字段；隐藏或已运行的桌面按钮不重复扫描普通检测范围。
- MonitorStatusLine不订阅日志等无关变更，仅在文字实际改变时处理本地秒钟重建，保留真实倒计时、窗口边界、手动五秒反馈及身份状态。
- 历史的两处计数汇总关闭排序，完整排序由当前数据快照的自动释放Provider复用；课程筛选计数从逐课程扫描改为一次聚合。原课程/日期/状态/类型组合规则与占位行展示保持。
- 作业页删除检查结束的无条件setState和仅更改生命周期控制标记的setState。既有Provider与可见性控制继续负责发布数据/启动检查。

### 后续候选及证据边界

- 地图CampusMap的相机Builder内仍进行mapBuildingGroups和TextPainter测量。应测量拖动/缩放时CPU与raster帧耗时，再决定如何按地点集合、字号/字体及缩放档位复用，不凭此代码形态认定严重卡顿。
- 可见课表的timetableColumns内部与网格LayoutBuilder中分别调用timetableStacks；本周课程也会在重建时重新筛选。后续可先对同一源快照的分组次数做计数，区分数据分组与窗口几何计算。隐藏Tab已有冻结机制，不重写保留壳。
- Android导航有两块局部BackdropFilter；深色校园画有ColorFiltered/ShaderMask。它们属于GPU测量候选，未做Android真机profile，未删除视觉效果。
- 校园摘要每分钟按日期重新形成教务分组，GPA只在数据/交互/重建时计算；本轮没有证据说明它们属于首要瓶颈，不增加跨页面全局缓存。
- 各项计数均为隔离回归的工作量，不能换算成FPS、CPU百分比或包体/内存降幅。当前Debug实例不作为发布性能基准；没有声称动效已达到指定帧率。

### 验证

- build/render-audit-full-tests.log：全量918通过、2项既有跳过；build/render-audit-final-analyze.log：flutter analyze无问题。
- build/render-audit-captures.log：13项截图/交互检查通过；历史截图补载与实际桌面一致的预览字体后，build/render-audit-history-capture.log的11项通过。已实看浅色检测倒计时和深色历史筛选截图，未更改样式参数。
- 未运行真实签到或Android真机profile，未量测正式版原生帧耗时、峰值内存及包体变化。

- 本轮已热重载当前Windows开发实例，Reloaded 5 of 3287 libraries；运行时Script源验证历史快照复用和状态文字比较已载入。未重启应用、未清缓存。


## 2026-10-30 Android优化、值守类型数量与两端刷新策略

### 本轮变化

- Android签到首页将认证身份、登录状态和任务running按字段订阅，日志变化不再牵动整个首页；Android mastheadStatus在等待课表、处理固定活动时跳过不变文本的每秒重建。既有真实秒数、起停、手动五秒反馈和Android单批任务保持。
- 值守课程顶部读取当前target账号的CourseRollcallsStore；按课程/活动ID去重，统计数字、雷达、二维码及未知类型。未取历史显示“尚无历史缓存”，已查为空显示“暂无签到记录”，truncated显示“部分”。只二维码的样本仍保留默认勾选；用户可依据历史自己关闭。页面与热重载重读均只读本地，不触发历史拉取。
- 作业待办缓存由30分钟调整为5分钟，与可见页面的5分钟检查周期保持同一常量；未提交/未知状态5分钟，已提交待批改30分钟、已关闭2小时、已出分24小时，跨截止及显式刷新沿用原补查。
- 复现并修复提交状态失败后切Tab立即重试：失败时间按owner与HomeworkStatusKey在会话中保留5分钟，旧缓存仍先显；新一次手动刷新可绕过，成功清除；取消或失效身份不记录失败。没有将错误、响应正文或凭据存入该门槛。
- 历史页每分钟检查候选，隐藏/非当前路由/后台不自动请求；恢复前台帧后检查。真实CourseHistoryNotifier继续负责课中有效期、新活动、收尾、未知课首次探查、在途合并与15秒请求间隔；稳定课外历史不会每分钟重查。初始目录失败由原错误页呈现，自动检查不抛出无人处理的Future。
- 校园摘要及角标复用未排课学生课程的作业磁盘缓存；当前学期目录先投影再读取，旧课程不混入。每课作业页的课后变更信号改复用readAcademicCatalog，教务缺失不回退畅课时间。

### 证据与验证

- render_work_test.dart覆盖Windows和Android样式的日志20次更新、等待5秒、隐藏5秒：按钮/状态重建及无关普通范围检查均为0。指标为组件计数，非真机FPS。
- history_freshness_visibility_test.dart使用真实历史规划/存储/Provider，仅替换网络仓库：两端均验证课中一次更新、隐藏/后台无额外请求、恢复前台更新、一次课后收尾及稳定历史后续0请求；另验证目录失败保留错误UI且自动检查无未捕获异常。
- 作业回归验证2分钟待办复用、6分钟发现新任务、并发合并与随后的重复检查不再请求；6分钟未提交会更新，已提交待批改继续缓存；失败后重挂载不重试，明确手动刷新可重试。另测每课作业不误用平台安排。
- 类型数量4种宽度/主题组合验证数字1/雷达1/二维码2、重复去重、异账号数字9不混入、成功空/未查/部分/仅二维码区别。已实看build/course-watch-columns/960-light.png及384-dark.png，卡片顶部信息可读，无中点分隔。
- build/platform-freshness-final-tests.log：全量928通过、2项既有跳过；随后build/freshness-academic-regression.log的5项含新增教务入口回归通过。build/platform-freshness-last-history-tests.log的3项通过。分析结果见build/platform-freshness-final-analyze.log。
- flutter devices快照无连接Android设备。本轮完成Android组件及共享数据逻辑回归，未安装Android包、未作真机帧率或真实签到验收。

- 已热重载当前Windows开发实例：Reloaded 10 of 3287 libraries；运行时源码确认值守类型数量、历史可见刷新和移动首页精确订阅已载入，保留当前账号与本地数据。


## 2026-10-30 值守关闭确认与托盘文案

- 原弹窗只接收busy，统一写检测，值守等待课表时也误称正在轮询。现由DesktopShellBinder提供同一当前任务的courseWatch标记，关闭弹窗传入对应显示名称；普通关闭保持中性，托盘只在运行值守时标为暂停值守。
- 运行时确认仍不记忆选择，未运行仍可记忆；最小化和退出返回动作、原防重复处理与退出停止任务流程均未改。
- build/close-mode-final-tests.log：14项通过，含两种模式及运行/未运行的弹窗显示、两种动作及remember值，原生托盘菜单的4种组合，以及原关闭偏好/窗口/通知回归。
- build/close-mode-analyze.log全库flutter analyze无问题；build/close-mode-final-analyze.log对4个变更源/测试无问题。已实看build/close-dialog/watch.png，值守标题、正文与按钮匹配且无溢出。没有实际执行退出或暂停用户任务。

- 已热重载当前开发实例（Reloaded 22 of 3287 libraries），运行时源码确认新关闭文案已载入；未重启或停止值守。已打开弹窗若保留旧参数，关闭再打开使用当前任务类型。


## 2026-10-30 托盘绿点与悬停状态

- 托盘复用当前MonitorState，值守与普通检测running显示右上角绿点，等待课表、处理签到及失败重试保持；启动准备和停止后使用普通图标。悬停用换行和中文冒号说明课表值守/自动检测及当前阶段，无中点分隔。
- 原图标保持，Dart脚本按16至256像素生成九档ICO及PNG静态徽标；已实际查看active PNG，右上角绿色圆形与白色边界清晰。没有增加动画、定时器或请求；仅订阅可见状态，缓存原生图标/提示，重复状态不调用通道。
- build/tray-status-tests-final.log：16项通过，包含真实MonitorState的两种任务/等待/处理/失败/启动/停止状态，原生通道图标和提示的切换与重复更新抑制，以及关闭弹窗、偏好和托盘菜单回归。
- 当前Windows开发实例热重载成功，Reloaded 22 of 3288 libraries；通过VM运行时源码确认desktop_shell与desktop_tray_status新实现已载入。新资源已同步当前实例的flutter_assets，无重启、清缓存或暂停用户值守。未实际操作暂停/退出，原生悬停效果待用户查看；Android无桌面托盘，本轮不改其前台服务。

- build/tray-status-analyze-focused.log：flutter analyze对5个变更Dart源/测试无问题。全库检查耗时较长已中断，采用本次变更的聚焦检查；非全量回归。ICO目录验证包含16/20/24/32/40/48/64/128/256九种尺寸。


## 2026-10-30 电脑端签到状态预览与通知核对

- 删除运行与启动的托盘/休眠说明，保留原起停与启动偏好。桌面诊断入口明确命名“电脑端签到与状态”，新增desktop展示分支，复用真实RollcallListPage及桌面卡片，Android继续原MobileRollcallHome。场景与封闭模拟传输共用原实现，打开/切换/重放电脑场景直接加载；12种场景含三类签到待签、缺资料、已签、过期、加载及失败。
- 已实看build/rollcall-home-preview/desktop-ready.png与desktop-completed.png：1104宽的三类桌面卡片完整展示，已签到按钮清晰，无移动底栏和溢出。组件测试真实数字卡片确认提交经过预览HTTP适配器，返回成功并显示已签到；保留已有移动端提交/隔离回归，无真实学校提交。
- build/preview-notify-tests-final.log：23项通过，覆盖预览、启动设置、前后台通知路由、静音结果、原生Windows通知内容及失败传播。build/preview-notify-analyze.log：4项变更Dart文件flutter analyze无问题。非全量回归，无Android真机验收。
- 当前开发实例Reloaded 8 of 3288 libraries；未重启、停止任务或清除缓存。
- 通知代码核对：MonitorEngine先发现通知，成功交付才按活动ID记入本次任务去重；AutomaticRollcallAnswer提交结果回调进入本地历史及DesktopNotifications，前台浮层、后台静音系统结果，发现/结果点击进入签到列表。当前机制保留，不增加轮询或重复提醒。发现与结果属于两个事件，因此快速自动签成功仍可能出现先发现、后成功两条通知；实际系统送达需用户在通知设置中确认。


## 2026-10-30 桌面签到卡参考对齐、60秒默认与安卓位置核对

final result: passed

- 依据用户本轮完整参考及补充的卡片裁图，对齐范围是卡片，保留现有导航/摘要布局。参考为单张数字卡，渲染样本为三类卡片，用不同演示课程与真实可用数据，未伪造教室或老师。明确按上半课程信息+右侧建筑、下半实时信息+提交操作分区。资产沿用既有campus_mist，不新增位图和渲染定时器。
- 同一图像工具返回中实看用户裁图与build/rollcall-home-preview/desktop-ready.png，并检查数字信息区、建筑位置和课程文字。标题30、数字码56及统一180×52操作按钮；轻边框/阴影、低饱和背景，建筑完全裁剪在上半课程信息区。图像、类型字体、时间空格、按钮字体与未签/已签状态可读；去除大块饱和头部色带和已签的大空卡片。未恢复参考中的中点分隔和“更多X项”。
- 另实看desktop-dark.png、desktop-large-text.png（640宽/150%）及desktop-completed.png：暗色装饰不抢文字，大字号按钮分行且无溢出，完成态使用简洁状态行。不同参考和渲染课程名有意保留，不要求演示业务数据逐字相同。桌面卡片截图已显式预载ResizeImage资源，避免组件测试在磁盘图片完成解码前截图导致缺建筑；此前截图资产缺失不代表正式运行使用了另一套素材。
- 安卓radar-picker.png实看为当前正式位置页布局；测试沿真实卡片进入RollcallAnswerPage、MapPickPanel并提交，已保存地点沿LocationPickerContent且同一隔离预览容器。组件测试屏蔽地图网络瓦片，空白底图不能作为真机地图加载结论。本轮无安卓UI替换及真机验收。
- build/card-refresh-tests-verified.log：37项相关回归通过，含60秒初始/持久化回退及48–72秒抖动、原旧间隔迁移、三类签到/提交、移动位置选择及桌面位置流程。build/card-refresh-analyze-final.log对6项变更Dart文件flutter analyze无问题；不是全库回归。

- 已热重载当前Windows开发实例，Reloaded 39 of 3288 libraries；未重启、清缓存、暂停任务或覆盖已有账号检测间隔。


## 2026-10-30 桌面卡片与安卓内容对齐

final result: passed

- 按用户本轮文字修正，上半课程名和下一行老师，不显示类型/教室课时/更多菜单；保留建筑。底部直接提取并复用安卓现有_taskMethod与_taskActionButton，按方式信息、竖线、人数、操作排列；窄屏/大字号按钮换行。完成行也使用课程名/老师。移除无调用的旧桌面数字专用行和重复按钮，净减少代码。
- 用户点击分发复用安卓已有逻辑：数字有码直接提交、缺码手动输入框，雷达有已保存位置复用_oneClickRadar及其位置/身份复核，缺位置仍进入选择；二维码进入原扫码页。没有增加自动提交触发器、改变后台任务或网络周期。对话框本身仍叫输入签到码，按钮叫手动输入。
- 实看build/rollcall-home-preview/desktop-ready.png及desktop-large-text.png：三种方式图标/文字、竖线与人数可读，老师统一位置，右上无操作菜单和类型；640宽/150%保留完整数字与操作。预览里的可用位置来自已有隔离样本，不伪造实际账号位置。
- build/desktop-parity-tests-verified.log：17项通过，包括桌面数字提交、已有位置直接雷达提交、缺码手动输入后成功，原移动完整预览、位置选择和桌面地点流程。build/desktop-parity-analyze-final.log对生产文件与测试静态检查无问题。未全库回归或安卓真机验收。
- 当前开发实例热重载成功，Reloaded 15 of 3288 libraries，未重启或停止当前任务。


## 2026-10-30 人数提示锚点与暂停悬停

- 原紧凑Tooltip包住人数和暂停按钮，并受父级Expanded紧约束影响。现由Align放松子约束，Tooltip只围绕人数图标/文本，按钮置于提示外。人数提示textAlign居中，原提示内容及倒计时保持。
- 两种人数布局共用暂停按钮：悬停/按压背景透明，图标在悬停/焦点时变为主题色，键盘焦点有轻微圆角背景，原按钮尺寸和暂停语义保持。
- build/count-hover-tests-verified.log：7项通过，新增真实鼠标悬停检查300像素父容器中Tooltip锚点宽小于150，渲染提示文本中心与锚点相差不超过1像素，鼠标转入暂停按钮并验证点击可切换继续；原刷新、暂停/恢复、后台、账号切换及自动人数门槛回归通过。
- 已实看build/count-hover/tooltip.png、pause-hover.png，人数提示水平居中，按钮无背景光圈。build/count-hover-analyze-final.log对生产文件与测试静态检查无问题。当前Windows开发实例热重载成功；无Android真机或全量回归。


## 2026-10-30 两端方式提示文字与垂直对齐

- 缺码提示原先Android为18/正文灰、桌面为13/正文灰，位置及二维码为18/正文色。现三个摘要使用同一_taskMethodTextStyle：18、w400、1.4、even leading、正文色；数字有值的分支原字号/字体/字重/字距完全保留。
- build/method-hints-tests.log：7项通过。新增两端真实预览组合检查三种TextStyle相等、18/w400，三种方式的图标中心与文字中心差不超过0.5像素；原数字复制、模拟提交和缺资料跳转回归保留。build/method-hints-analyze.log对生产和测试2项静态检查无问题。
- 实看build/rollcall-home-preview/android-hints.png与desktop-hints.png，三处文字大小/样式一致，图标垂直居中。为检查第三张卡片已滚动，截图第一张卡片上缘被裁剪属于滚动视口。无Android真机验收。


## 签到后保留完整卡片

- 根据本轮用户纠正撤销桌面已签到的紧凑摘要分支，待签/已签复用同一卡片、背景及底部摘要；成功按钮改为主题成功色且禁用，两端使用同一按钮样式。桌面人数completed与Android一致，收尾一次后停止刷新和暂停操作。
- build/completed-card-tests.log：14项通过。真实数字点击提交后断言卡片尺寸不变、1234仍显示、完整人数组件保留且completed为true；三类全部已签场景断言三个已签到按钮、数字码和二维码文本保留。原安卓模拟提交、三类场景、人数刷新/完成/暂停回归通过。
- build/completed-card-analyze.log对2项变更文件检查无问题。实际查看build/rollcall-home-preview/desktop-completed.png，三类卡片保留完整课程/老师/背景与底部信息，成功按钮位置一致，不再变为一行摘要；未进行Android真机验收。


## 2026-10-31 辅助账号GPA长时间加载排查

- 只读当前应用日志及SharedPreferences中的成绩缓存元数据，没有输出完整存储/凭据/课程成绩明细，没有清除用户缓存。辅助账号本轮00:11:18.931开始读取，00:12:18.067近两学期成绩查询结束，约59.1秒；其中研究生课表应用跳转00:11:20.683至00:12:08.990的academic.http.result记录elapsedMs=48306。此计时覆盖限流排队与HTTP，不据此断言纯服务器耗时。
- 这次访问了近两学期查询端点，代码条件表明已有v2缓存用于增量；最终该账号磁盘缓存69条，v2。旧缓存的准确at已被本次结果覆盖，旧日志无cache事件，不能还原原缓存过期时长。未发现缓存串号或丢失证据。
- 代码证据：原GradeNotifier在v2缓存超过一天时先await _fetch，只有网络失败才返回缓存，造成已有成绩仍整页loading。现在新鲜缓存仍直接返回；旧v2缓存先发布，下一事件循环后台刷新，保持账号生命周期校验、旧v1迁移和在途合并；失败保留缓存且更新warning。新增安全缓存命中日志以区分以后miss/fresh/stale。
- build/gpa-cache-tests-final.log：27项通过，包含主/协助账号过期缓存先返回、网络仍挂起时可读、成功更新落盘、失败保留与warning、fresh缓存隔离、账号切换阻止旧请求写入、旧v1迁移、空研究生成绩替换、真实教务协议适配器及GPA布局。build/gpa-cache-analyze-verified.log检查变更生产/测试2项无问题。非全量回归，无Android真机验收。

- 当前Windows开发实例热重载成功，Reloaded 11 of 3288 libraries；未清除/改写用户成绩缓存或重启应用。


## 2026-10-31 GPA按期末和假期更新

- 用户进一步明确“中段已有数据不应自动访问”。缓存优先保留，并给后台更新增加本地出分窗口判断：秋春第16周起、夏季学期/暑期允许自动更新；前15周及未知锚点仅缓存，手动更新/首次无缓存查询保留。24小时是出分窗口内的检查频率，不再作为全年自动更新理由。
- 只读当前账号SemesterPreferences及AcademicScheduleStore(useUserStart:false)，缺同学期课表时沿用academicMondays。未触发课表同步或教务请求，不引入第二套校历/凭据。旧版可读成绩同样先显示，分类升级推迟至窗口或手动更新。
- build/grade-season-tests-final.log：30项通过。两种账号40天旧缓存于10月31日打开后身份解析0次、成绩读取0次，手动刷新能读取；第15/16周边界、寒假、暑期及未知锚点判断；期末旧缓存先显示及后台成功/失败、旧分类迁移、原账号隔离/切换、增量协议及GPA组件回归均通过。
- build/grade-season-analyze-final.log：变更生产/测试2项静态检查无问题。没有清理用户缓存或修改已有成绩；非全量回归，未作Android真机验收。

- 当前Windows开发实例已热重载：Reloaded 11 of 3288 libraries。


## 2026-10-31 实际校历、考试日期与首周来源

- 移除gradeReleaseWindow的固定16周/夏季直接放行。使用同一成绩缓存内的账号考试日期（次日起14天）或academicTerms确认的学期结束/假期末；未知学年默认18/17/3仅显示，不授权联网。可读旧缓存优先、手动刷新和限流保持。
- 检查2022–2027校方历年网页并复核2026–2027 PDF，精确周数覆盖18/19、17/18、3/4/5周；维护入口仅academic_calendar.dart，自动派生周一表/周数。年度更新通常一次，临时调整例外。首周不再优先使用畅课课程startDate，用户设置仍最高优先，未知年度仅可信教务周次可回推，week=1不猜测。
- 本科只读考试安排附于既有grade fetch中，同一学期/会话查询；GradeSnapshot按owner+uid保存最小日期，错误账号/学期/日期或不完整返回不采纳，查询失败继续保留成绩和原元数据。研究生没有已验证考试端点，不冒充支持；无考试事实仍有确认的校历/手动路径。没有主动拉取真实账号考试数据或新增课表探测。
- build/calendar-exams-tests-verified.log：91项回归通过，覆盖校历周数和边界、手动/缓存/账号生命周期、考试查询HTTP适配器与身份拒绝、旧数据兼容、首周来源、课表投影及GPA/学期界面。最终将考试观察期限定为次日后，build/calendar-exams-last-tests.log再对日期/账号/协议23项复核通过。build/calendar-exams-analyze-final.log全库无问题，最终getter与身份关联改动由build/calendar-exams-analyze-verified.log聚焦复核无问题。
- build/calendar-settings-visual-final.log四项通过；实际查看.tools/semester-ui/settings-384.png，中文字体加载后首周设置/手动来源/本学期18周/当前周次清晰无溢出。初次未加载字体的截图未作为通过证据。无Android真机验收。
- 当前Windows开发实例已成功热重载（Reloaded 79 of 3289 libraries），包含新数据模型、策略与周数显示；最终次日边界随后再次热重载。没有停止任务、清缓存或改写用户成绩数据。


## 2026-10-31 畅课开学锚点来源补记

- 用户记忆与源码相符：rollcall_repository请求start_date并解析到CatalogCourse.startDate，teachingMondayFromCourses按目标学期过滤、将当天/之后第一个周一投票聚合，最高票并列或无日期返回未知。旧cdc49d3版AcademicTimetableReader优先调用该推导。
- 更正上轮来源解释：anchorFromUser=false只能排除手动兜底，不能证明旧缓存一定来自内置校历。旧缓存没有更细来源标记。
- 说明及日期示例写入docs/research/57-tronclass-semester-start.md，56号调研记录添加互链和更正。当前c9d7a49运行优先级本轮未改，教学周锚点不等于考试/出分日期。
- 纯Markdown更新，核对函数、旧调用、日期例子与diff；未运行Flutter检查或修改真实缓存。
## 2026-10-31 本学期考试安排与教务数据更新契约

- 校园工具及校园搜索新增“考试安排”，仅当前学期本科已排/未安排两列表；显示三种状态、时间、地点、座位及上次核对时间。已考试依据结束时间，空日期保留为未安排，不猜线上或实际参加状态。
- ExamNotifier按owner/target/term缓存先显，平时7天、校历最后两周24小时、临考48小时内6小时；仅打开/可见恢复触发，分钟时钟只更新本地分组。手动15秒、自动失败30分钟退避；两个列表全部成功才替换，完整空列表有效。首次/跨学期与手动请求共用在途任务，切号/会话失效不发布旧响应。
- 原成绩日期查询复用同一个已排解析入口，修复空日期导致整份考试日期事实不可用；GPA在本地读同身份较新的考试快照判断出分窗口，较新空集合撤销旧日期，不给研究生套本科事实。
- 读取用户指定考试记录只提取协议字段，未使用其中Cookie请求学校，未复制真实学号、课程或会话进仓库。参考只读D:/Projects/References/xmu_assistant，固定bbcedf701f8b66200a5897767e0d14c7c6cef5fe；不沿用历史学期探测或空教室推断线上。
- build/exams-final-tests.log：76项相关回归通过（协议、存储/Provider、成绩规则、考试/GPA/工具/搜索布局）。最终同源请求头复核build/exams-headers-tests.log为27项通过；新增跨学期缓存缺失与手动请求合并后，build/exams-flight-tests.log为8项通过。build/exams-headers-analyze.log全库无问题；最终Provider/测试由build/exams-flight-analyze.log复核无问题。
- build/exam-ui-tests.log生成四种截图，实际查看build/exam-ui-review下phone/desktop-light/dark.png：390×844与1100×850、中文真实字体，课程换行、考场/座位、分组和滚动无溢出；未将截图当作真机验收。未热重载用户开发实例、安装、推送或发布；真实本科本学期尚未发布的考试及Android真机仍待验收。
- 共用原则写入本地AGENTS.md，详细频率/边界写入docs/features/academic-data-refresh.md，同步规格、验收、路线、架构与功能台账；按既有.gitignore仅保存在本地，不强制加入公开提交。知识检索命中Engineering的“应用性能、缓存与低磁盘读写”，采用缓存归属/在途合并/失败不作空成功的约束，具体业务参数由项目维护；未回写共享知识库。

## 2026-10-31 禁用点号分隔与考试页面视觉整理

- 用户明确要求前端不以点号分隔信息，写入本地AGENTS.md：用独立字段、间距、换行和徽标表达层级；正常句末标点、小数及用户/教务原始名称中的字符不在此限制内。该本地规则沿用仓库忽略约定。
- 考试页拆分学年、学期、三组数量和核对时间；日期使用日历块，课程、时段、考场独立布局，座位/考试方式/进行中状态复用AppStatusBadge。正在考试边框强调、已考试弱化，分组数量单独徽标，不把点号替成另一串分隔符。工具首页改横向紧凑入口，手机单列、宽屏两列并保留原点击/悬停路径。
- build/exams-polish-final-tests.log：考试页与工具页四种端/主题组合、校园搜索导航共5项通过，原缓存可读/时间/地点/座位断言保留，增加无点号拼接检查。刷新、会话、存储和网络代码未修改。
- 实际查看build/exam-ui-review下考试页和tools前缀的全部8张截图：390×844手机与1100×850桌面浅深色，中文字体、长课程名、考场和座位均正常，内容可滚动。截图只代表Flutter布局检查，未做Android真机/原生窗口验收，未安装、热重载或发布。
- build/exams-polish-final-analyze.log：flutter analyze全库无问题。源码检索确认本轮考试及工具页面不再含中点/圆点分隔。同步本地规格、功能状态与数据更新契约；公共效果进入根CHANGELOG.md。

## 2026-10-31 考试卡片信息顺序与左右对齐

- 按用户附图反馈移除“正在考试”徽标与对应强调边框；右侧从上到下显示课程名、地点、时间，座位/开闭卷标签紧随底部时间，不足宽度自然换行。左侧日期块与右侧内容垂直居中，三行内容的高度更接近；未安排与已考试呈现保留。三状态时间判定和刷新流程不变。
- build/exam-card-order-tests.log：手机/桌面浅深色4项界面回归通过，断言不再显示正在考试，时间/地点/座位及原缓存信息仍可读。
- 实际查看build/exam-ui-review下phone-light/dark和desktop-light/dark四张最新截图，确认课程、地点、底部时间与标签顺序，左右高度协调，长课程名和窄屏标签可换行，无溢出。未安装、热重载或做真机验收。
- build/exam-card-order-analyze.log：flutter analyze全库无问题。同步本地规格、功能台账与考试状态说明，根CHANGELOG.md更新为最终卡片布局。

## 2026-10-31 课程名单行省略与考试时间图标

- 用户要求课程名保持单行、超宽末尾省略，说明其常用名为ellipsis/尾部省略，写入本地AGENTS.md作为列表/卡片课程名的默认规则，详情可完整展示，正常省略号不属于分隔符。
- 考试卡片复用AppTruncatedText，只有实际截断时显示全文Tooltip，桌面悬停和触控长按沿用项目现有交互。时间前加AppIcons.clock，15px规格及6px间距与地点图标一致；时间和图标作为一组，后随座位及开闭卷标签，窄屏自然换行。
- build/exam-ellipsis-tests.log：四种考试/工具布局与既有截断提示回归共5项通过；长课程名在手机截断有提示、桌面足够宽时无提示，短名称不重复提示，时间/地点/座位和无点号分隔断言保持。
- 检查build/exam-ui-review下最新phone/desktop-light/dark四张截图，确认中文尾部省略、时钟与定位图标及底部标签布局。未热重载、安装或进行真机验收。
- build/exam-ellipsis-analyze.log：flutter analyze全库无问题。同步本地规格、功能台账、AGENTS.md与根CHANGELOG.md，业务刷新/状态/协议均未变更。

## 2026-10-31 新考试工具入口在热重载后缺失

- 用户反馈工具页没有考试安排。对当前项目Debug实例通过VM evaluate只读检查campusTools的ID，实际仅gpa；源码却含exams和gpa，确认顶层final已初始化值在热重载中保留，之前只核对reload Success不足以证明新入口已经出现。
- 将同一列表改为getter保留调用接口，重新通过现有FlutterTools reloadSources服务热重载成功；再次读取运行时ID为exams,gpa。未热重启、关闭进程、重置账号或缓存。
- build/tool-registry-tests.log相关界面/导航5项通过，build/tool-registry-analyze.log聚焦Flutter静态检查无问题。真实运行时入口复核与自动布局回归分别记录。

## 2026-10-31 考试安排首次读取失败分析

- 只读当前Windows前台日志：2026-10-31 02:26:40及02:26:56（UTC+8）studentWdksapApp入口最终HTTP200，随后gsapp/sys/wdkbapp/wdkcb/initXsxx.do返回302，两次都没有执行cxxsksap/cxyxkwapkwdkc。页面之后显示的是30分钟自动失败退避，不能以此当首次失败原因。
- 依据用户考试抓包确认同应用POST cxxsjbxx.do的datas.cxxsjbxx.rows结构及XH字段；修正为考试应用自身身份接口，验证成功码、唯一学生/totalSize和所选身份。未使用抓包Cookie或复制真实身份数据。
- HTTP适配器加入旧GS接口返回302、考试身份接口正确返回的组合，回归确保不再跨GS上下文且错误学生仍被拒绝；build/exam-identity-tests.log协议/分页/缓存/账号/手动退避等19项通过。
- build/exam-identity-analyze.log全库Flutter静态检查无问题。当前Windows Debug通过FlutterTools热重载Success；未主动重发真实考试查询，修复后的真实返回需手动更新复核，旧失败退避没有清除。

## 2026-10-31 考试重试与刷新共享进度

- 根因：ExamNotifier.refresh在无缓存的错误态重试时只更新updating字段、不发布加载状态；AppRefreshButton又只观察自身点击，导致重试请求开始后旧错误页无变化且右上角不联动。
- 无缓存重试发布AsyncLoading，页面显示读取进度和明确文字；有缓存继续发布数据及正在核对状态。AppRefreshButton新增可选外部busy输入，考试页从同一Provider状态驱动旋转/禁用，任一入口发起的请求都能联动，结束后恢复；失败/15秒节流即时返回错误页。既有调用默认值保留自身点击语义。
- build/exam-retry-final-tests.log：考试错误页/头部入口、失败→节流→成功、正常四种布局、Provider账号/在途/失败退避及下拉控件共17项通过；build/exam-retry-progress-tests.log另对两入口进度复核。使用真实Provider与现有HTTP适配器阻塞/返回503，未复制业务逻辑。
- 实际查看build/exam-retry-review/loading.png和throttled.png，读取中正文提示/旋转头部与明确错误、可重试入口均正常；自动截图不代表真机验收。
- 扩大共享控件检查时desktop_workspace_test的4个签到切Tab计时断言失败，loads预期1实际2。用HEAD原AppRefreshButton及无外部busy调用作对照，首个同样失败（build/retry-baseline-desktop.log）；已恢复本次实现，未改签到计时或放宽断言，不把这些测试记为通过。
- 全库静态扫描仅发现截图辅助函数的单行if格式提示，已修正；build/exam-retry-verified-analyze.log对4个变更文件复核无问题。尝试热重载时旧开发服务拒绝连接，进程清单确认当前没有本项目Flutter run/Windows Debug进程，因此本轮未能热重载，也未另行启动应用。已有未跟踪tools/location_picker不属本任务，保留。

## 2026-11-06 银白五模块设计核对

final result: passed

仅指下述本轮界面实施范围；此前独立验收记录保留在本文件前文，历史备份在本地docs/history。

## 视觉依据与范围

唯一来源：`build/design-exploration-2026-11-06/suite-v3/five-module-overview.png`。用户选择图一实施，并明确签到内容布局暂时不变。第二张签到放大图不参与选型。

本轮是已有Flutter产品的五个根模块适配，不是复刻概念图的虚构数据或将小图文字等比放大。生成图各模块比例不同；保留现有可读字号、真实筛选/设置、手机行为和签到几何属于明确约束。

## 证据

- 原图1448×1086。各窗口裁剪分别为签到606×420、作业351×420、课表417×420、工具461×425、设置470×425。
- 实现截图：`.tools/desktop-workspace/`内`rollcall`、`作业`、`工具`、`设置`的`1120-light-1.0-dpr1.0.png`；有课程的本周为`.tools/academic-ui/week-960.png`（960×800）。Flutter逻辑像素、DPR1，无浏览器CSS视口。
- 同输入并排比较：`.tools/silver-white-qa/{attendance,homework,schedule,tools,settings}-comparison.png`。两侧保留原始长宽比，只为总览等比缩放，不以不同概念窗口密度作像素相等判断。
- 局部原尺寸检查：同目录`attendance-detail.png`、`tools-detail.png`、`settings-detail.png`，核对字级、边缘、阴影与行内控件。完整截图另实看1120/1.3字号、1440深色/DPR2、320手机设置和320大字号深色课表。
- 状态证据：`app_select`、`selected_hover`、`returned_focus`、`control_surface_matrix`、`chrome_state_contract`、`truncated_tooltip`及页面回归执行真实鼠标/键盘/滚动事件；全套1279通过、2跳过。测试日志`build/silver-white-full-tests.log`。

## 比较与修正

1. [P2，已修] 选中菜单叠加键盘焦点后蓝字对比不足。选中文字/元数据改正文色，蓝色勾选与底色保留；生产控件实际合成色回归通过。
2. [P2，已修] 全局蓝色使地图选中标签的白色焦点覆盖层降低对比。焦点覆盖使用主题正文色，保留焦点、选中及悬停/按下组合，4.5:1文字阈值未放宽。
3. [P2，已修] 签到顶面透明黑到浅灰的渐变出现灰带。改相同色相的透明起点；复拍确认恢复白色到轻灰的过渡，未移动布局。
4. [P2，已修] 设置plain选择器静止时灰色底块较重。静止透明、悬停/按下/打开/键盘反馈保留；浅深色真实事件与像素检查通过，复拍确认融合白色分组面。
5. 工具早期截图约6px实心托底来自默认组件测试关闭阴影模糊，非原生缓存缺陷。桌面捕获接入既有允许阴影的测试绑定后重新比较，软影正常；未停用缓存或改绘制实现。

## 五项核对

- **字体**：保留平台中文字体与既有fallback，正文14、控件13、辅助12；导航和标题有明确字重差。未引入展示字体或SF字体资源。概念图字体和放大倍率不当作平台排版数值。
- **空间**：签到主卡/右栏/底部历史位置不变；作业连续行和稳定状态列；工具四项双列小符号、研究生紧凑通栏；设置组间距大于组内间距。大字号不裁掉选项，手机保留可滚动区域。
- **颜色**：珍珠白/雾灰连续外壳/白色正文，蓝色用于操作和选择；2166DB相较概念蓝加深用于文字对比。深色沿单独角色值，菜单与地图的实际组合态已修正。
- **图像**：继续使用现有校园水彩资产，无新增伪图或错楼照片。服务图标使用已有AppIcons同族Cupertino符号，代替旧大底座；未将整张效果图栅格化成界面。更精细的专用服务图标属于P3后续打磨。
- **内容**：保留真实身份、全部筛选、网站/启动/退出等设置和权限；图中占位日期、人数、学校身份、缺失操作不进入业务规则。新增本周日期按真实周计算，学期不误显示某周日期。

## 边界

无待处理P0/P1/P2界面问题。系统读屏、Android/iOS真机、真人对美感的最终评价和原生Profile性能未由这些截图/组件测试证明。Debug运行结果另记实施记录，不将其当作性能验收。

## 2026-11-06 银白界面交互完善

final result: passed

范围：本聊天U19“修改作业不要占满行”和继续完善交互，沿DESIGN当前图一方向；签到内容布局保留。结果只涵盖以下操作链，不代表用户已认可最终美感或全站真机验收。

| 步骤 | 实际操作与结果 | 证据 |
| --- | --- | --- |
| 1 | 工具五项同规格，修改作业半宽，进入子页仍可返回 | build/desktop-ui-review/gray-directory-shell-false.png、同目录dark截图；campus_tools_directory |
| 2 | 设置导航hover加深尾箭头、press/键盘强调；取消不执行，整行背景/尺寸不变 | build/interaction-ui/settings-{idle,hover,pressed,keyboard}-false-false.png及浅深/减少动效组合；hover_surface |
| 3 | 长菜单首次打开选中35/60完整可见；方向键到43仍可见，背后页面offset不动 | build/desktop-ui-review/long-select-{current,keyboard}-false.png及true；app_select |
| 4 | 菜单沿触发边短展开，Esc/切页立即关闭；同帧重复激活仅一次回调 | select-opening-anchor.png；desktop_menu_interaction；原生箭头与无选项描边保留 |
| 5 | 作业深处换筛选从首项开始；桌面列表已绑定页面控制器 | homework-deep-before-filter.png、homework-filter-first-result.png；80项长列表回归 |
| 6 | 进入真实作业详情、点击返回，回到原滚动位置；中间帧文字不重叠 | homework-detail-{entering,ready,returning,restored-position}.png；teaching_homework |
| 7 | 触屏叠课44目标可点，标题可读，教师/地点对应所选课程；横滚可到周五 | .tools/academic-stacks/touch-single-double-{before,after}.png、touch-minimum-height.png；320×420及320×240 |
| 8 | 960/1920与RTL短位移，快速反向连续；减少动效无过渡等待，原输入保留 | app_page_routes六项实际点击回归；returned_focus相关回归 |

五项画面核对：字体沿平台中文与现有字级；布局仅用户指定工具宽度与有证据的叠课命中区取舍；共享配色不再更换；校园水彩/同族符号不变；常驻文案不新增功能枚举，截断提示使用既有时序。主要取舍见docs/design/INTERACTION-REFINEMENT-2026-11-06.md。

[P2，已修] 桌面整页淡入在60ms中间帧透出背后作业列表，造成两页文字重影。桌面内容改不透明，保留固定背景与16逻辑像素方向位移；手机沿原表现。原始960×720截图、同一60ms状态的局部并排比较已实看：.tools/interaction-review/detail-entering-comparison.png和detail-returning-comparison.png，原尺寸裁剪，不拉伸；修正后无待处理P0/P1/P2。

本轮静态检查通过；完整回归1297通过、2跳过，最终桌面不透明绘制修正后另52项页面/返回/菜单回归通过，最终单文件分析无问题。日志分别为build/interaction-final-full-tests.log、interaction-opaque-page-recheck.log、interaction-opaque-page-analyze.log。Windows Debug热重载70/3763库成功（3316ms），未重启用户状态。

边界：组件渲染与实际事件已核；未重新测原生Profile性能、系统读屏或Android/iOS真机。不以测试代替用户对体验和美感的评价。
