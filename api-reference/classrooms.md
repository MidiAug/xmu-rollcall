# 厦大教室

2026-11-25 依据用户提供的已解密抓包及学校当前公开前端脚本实现。原始响应、票据、身份及预约编号仅留本机忽略目录，不进入仓库。

## 认证及作用域

GET https://eclass.xmu.edu.cn/cas/login 进入 IDS；复用现有账号的 IDS 会话或密码，由共享 IdsAuth 提交。限同源及 ids.xmu.edu.cn 的 HTTPS 跳转；从学校回调提取 access_token，Bearer 只发送给教室域名。以 /api/currentUser 的 code 核对所选学号，不借主账号替代协助身份。令牌仅在内存，不写日志或普通缓存。本研两个账号均已通过生产客户端只读验证。

## 业务

- /api/basic/campus、/api/basic/buildings 使用 active=1 的 filters，按 created_at 降序；目录整批读取，不逐教室补同一信息。roomIntroduction 按 room.id 去重，详情仅点击后读 roomIntroductionDetail。
- 座位：rooms/cards 分页20条；booking-configs、date-status、time-range-status、seat-status 提供规则与状态；booking-orders POST 使用 room_id、seat_id、booking_date、book_type、book_time_list。个人记录 my_record=1；取消用 booking-orders/{id}/cancel。
- 研讨室：function-rooms 分页；v2/book_rule 规则；function-rooms/{id} 以日期时间核对剩余人数；customization/addBook 传 room_id、start_date、start_time、end_time、purpose、people_num、allow_many。当前表单实现 time_period 的团队预约。记录 room-book-records 与座位记录按来源及 ID 合并；取消 DELETE book-records/{id}，reason 放请求体。非空研讨室记录仍缺真实样本。
- 自习：selfStudyRoom/guide 必须带 building_id、date；状态1可自习、2已预约，其余未开放，expire 表示已结束。无楼栋的请求会500，客户端不采用该路径。
- 楼层：modelingCampusBuilding 提供适用楼栋，building-schedules-pad-with-self-study 返回整批楼层。当前实现原生列表，不渲染原站3D场景；无占用记录不等于可自习许可。
- customization/lecture 分页；lostfound/lost 为公开招领列表；xmu/feedback/my 为本人反馈。新反馈采用学校类别/类型目录及教室目录，提交 campus_id、building_id、room_id、category_id、type、phone、content，先确认。
- 扫码目前支持学校域名中带教室 UUID 的链接识别与原生详情。没有实现现场签到、NFC或任意二维码外跳。

## 验证边界

本人本研 CAS、目录、教室和讲座查询已验证。自习、楼层、预约规则与座位状态协议依据真实抓包及只读核对；研讨室列表部分请求曾超时，手动重试成功，失败保留页面已读内容并允许更新。所有真实预约、取消及反馈写入未执行，仅在 HTTP 边界与组件中验证，不宣称真机端到端通过。失物发布/认领、附件上传、现场签到尚未接入。

目录摘要按 ownerId/userId 隔离，5分钟核对、手动15秒门槛；失败保留缓存和成功时间。切换账号关闭旧页面并阻止旧请求发布；清理远端数据包含 classrooms_v1_。
