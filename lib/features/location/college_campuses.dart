import 'campus_places.dart';

/// Conservative fallback for student college names, checked 2026-10-28.
/// Actual classroom locations always take priority; unknown colleges stay unset.
/// Sources: https://admissions.xmu.edu.cn/cn/Majors/CN_BA.htm
/// https://admissions.xmu.edu.cn/cn/info/1125/2972.htm
/// https://zzxq.xmu.edu.cn/xqgk/xqjs.htm
Campus? campusForCollege(String name) {
  final college = name.replaceAll(RegExp(r'\s+'), '').replaceFirst('厦门大学', '');
  const xiangan = {
    '信息学院',
    '电子科学与技术学院',
    '航空航天学院',
    '航天航空学院',
    '能源学院',
    '海洋与地球学院',
    '环境与生态学院',
    '生命科学学院',
    '医学院',
    '公共卫生学院',
    '药学院',
    '国际中文教育学院',
    '海外教育学院',
    '国际中文教育学院/海外教育学院',
  };
  const siming = {
    '人文学院',
    '中国语言文学系',
    '电影学院',
    '新闻传播学院',
    '外文学院',
    '艺术学院',
    '经济学院',
    '管理学院',
    '法学院',
    '公共事务学院',
    '国际关系学院',
    '社会与人类学院',
    '数学科学学院',
    '物理科学与技术学院',
    '化学化工学院',
    '材料学院',
    '建筑与土木工程学院',
  };
  if (xiangan.contains(college)) return Campus.xiangan;
  if (siming.contains(college)) return Campus.siming;
  if (const {'国际学院', '创意与创新学院'}.contains(college)) {
    return Campus.zhangzhou;
  }
  return null;
}
