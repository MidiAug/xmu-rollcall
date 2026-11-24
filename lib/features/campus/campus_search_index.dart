import 'campus_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/exams/exam_page.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/location/campus_atlas_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';

class CampusSearchEntry {
  const CampusSearchEntry(
    this.title,
    this.description,
    this.keywords,
    this.icon, {
    this.page,
    this.url,
    this.help = '',
  });
  final String title, description, keywords, help;
  final IconData icon;
  final WidgetBuilder? page;
  final String? url;
}

bool campusSearchMatches(String query, String content) {
  String clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s，。？！?、（）()]'), '');
  final q = clean(
    query,
  ).replaceAll(RegExp('怎么算|怎么用|怎么|如何|在哪|打开|查询|使用|我要|帮我|设置|说明|帮助'), '');
  return q.isEmpty || clean(content).contains(q);
}

List<CampusSearchEntry> campusSearchFeatures(int? scope) => [
  CampusSearchEntry(
    '学年校历',
    '学期安排与教学周',
    '校历 学年 秋季 春季 小学期 短学期 教学周',
    AppIcons.calendar,
    page: (_) => const CampusCalendarPage(),
    help: '按已维护的学年与学期查看月历和教学周，具体安排以学校公布校历为准。',
  ),

  CampusSearchEntry(
    '校园地图',
    '三个校区的楼群、楼宇与分区',
    '地图 校园 楼群 楼宇 分区 思明 翔安 漳州',
    AppIcons.map,
    page: (_) => const CampusAtlasPage(),
    help: '按校区和目录浏览已维护的地点，支持楼名、别名搜索和分区定位；这里仅浏览，不修改个人地点。',
  ),
  CampusSearchEntry(
    '考试安排',
    '本学期未安排、未考试和已考试',
    '期末 考试 考场 考试安排 座位',
    AppIcons.calendar,
    page: (_) => const ExamPage(),
    help: '查看当前账号的本学期本科考试，先显示本地数据并按日期判断是否核对教务。可手动更新；已考试只表示安排时间已过。',
  ),
  CampusSearchEntry(
    'GPA 计算器',
    '成绩、学年与学期绩点',
    '绩点怎么算 成绩学分 GPA计算器',
    AppIcons.calculator,
    page: (_) => const GpaPage(),
    help: '打开后读取当前账号的成绩。选择总绩点、学年或学期范围，并按需勾选课程。没有已发布成绩时会显示空态，计算规则可在页面底部查看。',
  ),
  CampusSearchEntry(
    '本学期课表',
    '查看课程时间与上课地点',
    '课程 课表 学期 开学时间',
    AppIcons.calendar,
    page: (_) => CoursesPage(assistUserId: scope),
    help: '在课表中切换本周和学期视图。点击课程查看时间、教师与教室；已定位的教室可继续查看地图。',
  ),
  CampusSearchEntry(
    '地点管理',
    '绑定、校正课程的上课位置',
    '地点 定位不准 地图 教室 校区',
    AppIcons.location,
    page: (_) => const SavedLocationsPage(),
    help: '选择待定位或待校正的课表地点，在地图上标记位置并保存。地点名称沿用课表，绑定按当前账号保存。',
  ),
  CampusSearchEntry(
    '自动检测设置',
    '设置检测范围与签到规则',
    '自动签到 签到 自动检测 位置签到',
    AppIcons.detect,
    page: (_) => const MonitorSettingsPage(),
    help: '先检查检测时段和当前账号的规则，再返回签到页启动检测。检测运行时可从顶区停止。自动签到规则需要另行配置，普通签到仍有确认步骤。',
  ),
  CampusSearchEntry(
    '作业',
    '查看进行中作业与作业详情',
    '作业 附件 截止时间',
    AppIcons.homework,
    page: (_) => const HomeworkHubPage(),
    help: '进入作业页切换进行中或已截止。点击具体作业查看说明、附件与提交状态。当前客户端不提供作业提交。',
  ),
  CampusSearchEntry(
    '签到记录',
    '查看当前账号的签到历史',
    '签到历史 签到记录 未签到',
    AppIcons.history,
    page: (_) => const HistoryPage(),
    help: '记录页提供课程、日期和签到状态筛选。下课不代表签到成功，请以平台记录中的状态为准。',
  ),
  CampusSearchEntry(
    '后台提醒',
    '检查锁屏提醒与通知权限',
    '通知 收不到提醒 后台提醒',
    AppIcons.notification,
    page: (_) => const NotificationSettingsPage(),
    help: '按页面提示检查通知与后台运行相关设置。不同安卓系统的入口不同，实际授权状态以系统显示为准。',
  ),
  CampusSearchEntry(
    '协助同学',
    '管理导入的协助身份',
    '切换账号 协助同学 身份 导入',
    AppIcons.assist,
    page: (_) => const SettingsAssistPage(),
    help: '在此导入或管理协助身份，再从签到页姓名入口切换。课程、作业和地点始终按当前账号读取。',
  ),
];

const campusSearchGuides = [
  CampusSearchEntry(
    '校园网与密码',
    '厦大信息与网络中心  官方指南',
    '校园网 WiFi XMUNET VPN 密码 统一认证',
    AppIcons.info,
    url: 'https://inc.xmu.edu.cn/info/1431/9562.htm',
  ),
  CampusSearchEntry(
    '校园卡服务',
    '厦大信息与网络中心  官方入口',
    '校园卡 充值 补卡 数字校园卡',
    AppIcons.info,
    url: 'https://inc.xmu.edu.cn/fwzn2/xyk.htm',
  ),
  CampusSearchEntry(
    '信息学院新生手册',
    '本科 / 研究生分册  适用范围见原文',
    '新生 学校 办事 研究生 本科 生活 交通',
    AppIcons.document,
    url: 'https://informatics.xmu.edu.cn/welcome/index.html',
  ),
  CampusSearchEntry(
    '学校信息门户',
    '前往厦大官方服务入口办理',
    '办事 证明 门户 服务大厅',
    AppIcons.tools,
    url: 'https://i.xmu.edu.cn/',
  ),
];
