import 'teaching_catalog.dart';

part 'campus_story_research.dart';

/// Paraphrased campus profiles and source catalogue, checked 2026-11-03.
/// Kept separate from location matching and personal course preferences.
class CampusStory {
  const CampusStory(
    this.text,
    this.url, {
    this.sections = const [],
    this.references = const [],
  });
  final List<({String title, String text})> sections;
  final List<String> references;
  Iterable<String> get sourceUrls => [url, ...references];
  String get summary => '${text.split('。').first}。';
  final String text, url;
}

const _x2014 = 'https://news.xmu.edu.cn/info/1002/3560.htm';
const _west = 'https://informatics.xmu.edu.cn/info/1103/12447.htm';
const _qunxian = 'https://news.xmu.edu.cn/info/1047/41869.htm';
const _jiannan = 'https://news.xmu.edu.cn/info/1811/481661.htm';
const _named2008 = 'https://news.xmu.edu.cn/info/1003/26408.htm';

const _jiageng = 'https://news.xmu.edu.cn/info/1771/476361.htm';

const campusBuildingStories = <String, CampusStory>{
  'sm-jiageng1': CampusStory(
    '嘉庚一号楼，冠名保欣丽英楼，属于芙蓉湖畔嘉庚楼群的四座从楼。',
    _jiageng,
    sections: [(title: '沿革与命名', text: '由黄保欣、吴丽英伉俪捐资兴建，楼名纪念捐建者伉俪。')],
  ),
  'sm-jiageng2': CampusStory(
    '嘉庚二号楼，又名成枫楼，是嘉庚楼群的从楼。',
    _jiageng,
    sections: [(title: '沿革与命名', text: '由吴定基、李织霞伉俪捐建，以李织霞父亲李成枫之名命名。')],
  ),
  'user-5a9e6bff313a4a80b793e5495f886543': CampusStory(
    '嘉庚三号楼，又名颂恩楼，是思明嘉庚楼群的中心主楼。',
    _jiageng,
    sections: [
      (
        title: '沿革与命名',
        text: '由丁政曾、蔡悦诗伉俪捐建。“颂恩”表达对母校培育之恩的感念。主楼为21层，以传统塔楼造型组织现代高层建筑。',
      ),
    ],
  ),
  'sm-jiageng4': CampusStory(
    '嘉庚四号楼，又名祖营楼，是嘉庚楼群的从楼。',
    _jiageng,
    sections: [(title: '沿革与命名', text: '由洪文炳捐建，以其父亲洪祖营之名命名。')],
  ),
  'sm-jiageng5': CampusStory(
    '嘉庚五号楼，冠名钟铭选楼，是嘉庚楼群的从楼。',
    _jiageng,
    sections: [(title: '沿革与命名', text: '由钟江海、钟明辉、钟琼林兄弟捐建，以其父名字命名。')],
  ),
  'sm-scienceart': CampusStory(
    '科学艺术中心又名恩明楼，是芙蓉湖畔的演出、展览与学术交流场所。',
    'https://jjc.xmu.edu.cn/info/1021/1559.htm',
    sections: [
      (
        title: '沿革与命名',
        text: '2005年开工，2010年8月完成工程并投入使用。中心设大型放映及会议厅、音乐厅、展厅和会议室；建筑声学由吴硕贤院士指导设计。',
      ),
    ],
  ),
  'sm-library': CampusStory(
    '思明校区图书馆总馆于1987年建成，是学校文献服务与业务中心。',
    'https://library.xmu.edu.cn/gybg/smxqtsg/jj.htm',
    sections: [
      (
        title: '沿革与命名',
        text:
            '图书馆官方简介记载2001年、2008年两度改扩建。馆内提供借阅、阅览、文献咨询与古籍特藏等服务。此处记录现馆舍的变化，馆舍建成与图书馆机构成立属于不同历史节点。',
      ),
    ],
  ),
  'sm-keli': CampusStory(
    '克立楼由校友黄克立捐资建造，以其姓名命名。',
    'https://ese.xmu.edu.cn/px/info/1231/1474.htm',
    sections: [
      (
        title: '沿革与命名',
        text: '校方资料将其介绍为兼具会议与住宿功能的交流场所。冠名体现了学校对校友支持教育的纪念；现有资料未确认本楼竣工年份。',
      ),
    ],
  ),
  'xa-pool': CampusStory(
    '佘明培游泳馆是翔安校区的体育设施，延续了校友家庭捐资兴学的情谊。',
    'https://alumni.xmu.edu.cn/xyzh2023/info/1019/1669.htm',
    sections: [
      (
        title: '沿革与命名',
        text: '2012年校庆之际，佘施淑好女士捐建采用太阳能的现代化游泳馆。它与思明的明培体育馆分处不同校区，不应混作同一建筑。',
      ),
    ],
  ),
  'xa-zeng': CampusStory(
    '曾宪梓楼是翔安校区公共卫生学院的楼宇。',
    'https://baowei.xmu.edu.cn/info/1004/1485.htm',
    sections: [
      (
        title: '沿革与命名',
        text: '学校保卫部门曾在该楼及传染病诊断试剂与疫苗研究平台开展实验室消防分类指导试点。楼宇建成及冠名日期尚待进一步核实。',
      ),
    ],
  ),

  'sm-zhuang': CampusStory(
    '南强二教学楼建于1988年。2011年校庆期间，1947届政治学系校友庄汉水捐资250万元，教学楼由此冠名，延续了他支持母校教育的情谊。',
    'https://xcb.xmu.edu.cn/info/1051/12411.htm',
  ),
  'user-c303722948674456928f943a601e0f76': CampusStory(
    '建南楼群1951至1954年营建期间的生物馆。楼名取自捐建者李光前长子李成义之名。',
    _jiannan,
  ),
  'sm-nanan': CampusStory(
    '建南楼群原来的化学馆，建于1951至1954年间。楼名取意于捐建者李光前的祖籍福建南安。',
    _jiannan,
  ),
  'sm-jiannan': CampusStory(
    '1951至1954年间建成的建南楼群主楼。这里承载集会与演出；与集美的福南大会堂之名相呼应，寄寓闽南教育的共同理想。',
    _jiannan,
  ),
  'sm-nanguang': CampusStory(
    '建南楼群原来的物理馆，建于1951至1954年间。楼名与捐建者李光前及其祖籍南安相联系。',
    _jiannan,
  ),
  'sm-chengzhi': CampusStory(
    '建南楼群原来的图书馆，建于1951至1954年间。楼名取自李光前次子李成智之名，见证了厦大学子的阅读岁月。',
    _jiannan,
  ),
  'sm-hyteaching': CampusStory(
    '2008年校庆时，学校宣布将一批楼宇以名师命名，以弘扬校友陈为敏的捐赠善举。萨本栋教学楼由此以办学先贤之名留存校园记忆。',
    _named2008,
  ),
  'sm-hyadmin': CampusStory(
    '2008年校庆宣布命名的四座楼之一，以林觉世先生之名纪念厦大办学历史中的先贤，也延续校友捐资兴学的传统。',
    _named2008,
  ),
  'sm-lujiaxi': CampusStory(
    '2008年校庆宣布命名的四座楼之一，以化学家卢嘉锡之名纪念厦大名师，承载化学学科的教学科研。',
    _named2008,
  ),
  'xa-ellipse': CampusStory(
    '这里是厦大传染病诊断试剂与疫苗研究的重要科研空间。校方2022年的报道记录了团队在椭圆楼持续攻关、推动科研成果走向应用的日常。',
    'https://std.xmu.edu.cn/info/2501/46791.htm',
  ),
  'xa-wenxuan': CampusStory(
    '翔安主楼群4号楼，设听力、计算机及理化实验教学空间。由校友张曦捐建，2014年元旦举行落成典礼。',
    _x2014,
  ),
  'xa-xiping': CampusStory('由柯希平捐建，2014年元旦举行落成典礼，是海洋与地球学院开展教学科研的重要楼宇。', _x2014),
  'xa-huang': CampusStory('由校友黄朝阳捐建，2014年元旦举行落成典礼，为生命科学学院提供教学科研空间。', _x2014),
  'xa-zhuangjin': CampusStory('由校友庄凌捐建，2014年元旦举行落成典礼，承载药学教学与科研实验。', _x2014),
  'user-61662be4bd3e494cbcca0b212ccb56e8': CampusStory(
    '2021年信息学院新院楼命名征集中产生的名字。“正”寄托堂正做人、正直办事的期望，楼宇承担行政办公功能。',
    _west,
  ),
  'xa-west2': CampusStory(
    '2021年信息学院新院楼命名公示中的公共教学楼。“学信”把求知、信息与诚信联系在一起，寄望学子在此成长。',
    _west,
  ),
  'xa-west4': CampusStory(
    '2021年信息学院命名公示中的实验教学楼。“启”寓意由实验开启科学探索，也寄托开创学院未来的愿望。',
    _west,
  ),
  'xa-west5': CampusStory(
    '2021年信息学院命名公示中的科研团队用楼。“智”兼具智慧与智能之意，呼应信息学科的探索方向。',
    _west,
  ),
  'xa-west6': CampusStory('2021年信息学院命名公示中的科研团队用楼。“睿”寄托科研与育人共同增长智慧的期待。', _west),
  'xa-jinquan': CampusStory(
    '2017年6月8日，环境与生态学院大楼举行命名揭牌仪式，以捐赠者郑金泉之名命名，承载校企合作与环境生态研究。',
    'https://news.xmu.edu.cn/info/1006/4084.htm',
  ),
  ..._campusResearchBuildingStories,
};

const campusGroupStories = <String, CampusStory>{
  'sm-law': CampusStory(
    '法学院片区集中分布法学教学与研究空间。',
    'https://jjc.xmu.edu.cn/info/1019/53751.htm',
    sections: [
      (
        title: '建设与更新',
        text:
            '基建处2011年公开资料介绍了法学院扩建计划，规划建筑面积26500平方米，项目建议书已获批。这里记录的是规划节点，实际竣工与各栋楼的沿革尚需分别核实。',
      ),
    ],
  ),
  'sm-art': CampusStory(
    '艺术学院片区以艺术教学与创作为主要背景。',
    'https://news.xmu.edu.cn/info/1023/32039.htm',
    sections: [
      (
        title: '院舍沿革',
        text:
            '校方转载的院庆报道记载，艺术学院大楼于1990年落成，学院此前成立于1983年。现目录将大楼及其楼段作为建筑综合体维护，不推断各楼段均为同年独立建成的单楼。',
      ),
    ],
  ),
  'sm-haiyun': CampusStory(
    '海韵园中的萨本栋、林觉世等楼名纪念厦大办学先贤。',
    'https://news.xmu.edu.cn/info/1003/26408.htm',
    sections: [
      (
        title: '命名背景',
        text:
            '2008年校庆，学校宣布将一批楼宇以名师命名，纪念萨本栋、林觉世、卢嘉锡、曾呈奎等先贤，并弘扬校友陈为敏的捐赠善举。此处只说明相关命名背景，不把命名年份作为园内所有建筑的竣工时间。',
      ),
    ],
  ),
  'sm-chemistry': CampusStory(
    '化学化工学院片区延续厦大建校以来的化学教育传统。',
    'https://chem.xmu.edu.cn/info/1149/1023.htm',
    sections: [
      (
        title: '学科背景',
        text:
            '化学学科自1921年开始招生，1924年成立化学系。学院校史记载了卢嘉锡等学者推动学科建设的经历；这些学术沿革与现有化学楼、卢嘉锡楼等楼宇的营建历史分别记录。',
      ),
    ],
  ),
  'sm-economics': CampusStory(
    '经济学院片区包括经济楼等教学科研空间。',
    'https://soe.xmu.edu.cn/xygk/xyjj.htm',
    sections: [
      (
        title: '学科沿革',
        text:
            '经济学科发端于1921年的商学部。1981年获批成立经济学院，1982年举行成立大会。学院成立、庆典与经济楼改造属于不同事件，不能彼此替代。',
      ),
    ],
  ),
  'sm-foreign': CampusStory(
    '外文学院片区承载语言、文学与跨文化教育。',
    'https://cflc.xmu.edu.cn/info/1191/8664.htm',
    sections: [
      (
        title: '学科沿革',
        text:
            '外文学科在厦大建校之初发端，1923年筹建外文系，次年获批成立。林语堂、周辨明等学者曾任教于此。机构历史用来理解片区背景，不用作现有南光等楼宇的营建证据。',
      ),
    ],
  ),

  'sm-material': CampusStory(
    '材料学院片区承载材料科学与工程的教学科研。',
    'https://cm.xmu.edu.cn/xygk/xyfc.htm',
    sections: [
      (
        title: '学科背景',
        text:
            '材料学科起源于1960年的高分子专门化方向，1986年设材料化学专业，2007年成立材料学院。这些是学科与机构节点，不是片区每座楼的建成年份。',
      ),
    ],
  ),
  'xa-medical': CampusStory(
    '医学院片区包括成义楼、成智楼等楼宇。',
    'https://med.xmu.edu.cn/xy/xyfzjj/xyjsfzjjxmylb.htm',
    sections: [
      (
        title: '空间与使用',
        text: '医学院公开的建设项目把成义楼广场及两楼后侧空间作为环境改善对象。片区中的单楼沿革分别核实，不沿用思明同名建筑历史。',
      ),
    ],
  ),
  'xa-sph': CampusStory(
    '公共卫生学院片区包含曾宪梓楼等教学科研空间。',
    'https://baowei.xmu.edu.cn/info/1004/1485.htm',
    sections: [
      (
        title: '教学科研背景',
        text: '校方保卫部门曾在曾宪梓楼及传染病诊断试剂与疫苗研究平台试行实验室消防分类指导，反映该片区的实验教学与科研属性。',
      ),
    ],
  ),
  'xa-aero': CampusStory(
    '航空航天学院片区服务空天领域的教学与科研。',
    'https://aerospace.xmu.edu.cn/info/1353/15883.htm',
    sections: [
      (
        title: '学科背景',
        text:
            '学校航空教育可追溯至20世纪40年代的机电工程学系、航空工程学系。学院介绍包括嘉庚一号火箭、南强一号验证机等研究实践；学科起源不等于现有大楼建成年代。',
      ),
    ],
  ),
  'zz-bio': CampusStory(
    '漳州生化楼群设有生物技术等实验教学空间。',
    'https://lifelab.xmu.edu.cn/syjx/swjsscsx/kcjs.htm',
    sections: [
      (
        title: '实验教学',
        text: '实验教学中心资料记载，生化大楼一楼及三楼承担生物技术实训，包括菌种、细胞培养与仪器实验。课程资料仅用于说明已确认的空间用途。',
      ),
    ],
  ),
  'xa-energy-college': CampusStory(
    '能源学院片区与和木楼的捐建历史相关。',
    'https://news.xmu.edu.cn/info/1002/3560.htm',
    sections: [
      (
        title: '捐建与用途',
        text:
            '2014年元旦，和木楼举行落成典礼，由丁和木、丁世忠父子捐建，面向能源教学、科研及办公。本目录沿用能源1、2、3号楼等名称，报道未逐一对应编号，不将和木楼史料直接分配到某个编号单楼。',
      ),
    ],
  ),
  'sm-education': CampusStory(
    '教育研究院片区见证厦大高等教育研究的学术传统。',
    'https://library.xmu.edu.cn/gybg/yxzls/jyyjy.htm',
    sections: [
      (
        title: '学科背景',
        text:
            '潘懋元推动建立高等教育研究机构，形成研究生培养与教育研究基地。机构与学科的沿革在此作为背景，不作为片区内潘懋元楼等馆舍的竣工或冠名证据。',
      ),
    ],
  ),
  'sm-journalism': CampusStory(
    '新闻传播学院片区承载新闻与传播教育。',
    'https://news.xmu.edu.cn/info/1003/27571.htm',
    sections: [
      (
        title: '学科沿革',
        text:
            '厦大1922年开办新闻教育，1983年复办新闻学科，2007年成立新闻传播学院。这些节点属于学科和学院发展，不代表现有院楼的建成年代。',
      ),
    ],
  ),

  'xa-energy': CampusStory(
    '嘉庚创新实验室于2019年授牌成立。作为重要研发基地，能源材料楼群在同年9月完成主体工程，以“一主四从”的嘉庚风格布局服务能源材料研究。',
    'https://news.xmu.edu.cn/info/1002/1636.htm',
  ),
  'sm-jiageng': CampusStory(
    '思明嘉庚楼群于1998年6月开工、2001年4月竣工。以颂恩楼为主楼，连廊与大台阶把建筑和芙蓉湖前的广场联系起来，延续并发展了嘉庚建筑风格。',
    'https://news.xmu.edu.cn/info/1047/41865.htm',
    sections: [
      (
        title: '营建沿革',
        text:
            '1997年由黄仁牵头的校内设计团队开展设计，1998年6月开工，2001年4月竣工。建设目标是联系不同时期的校舍，形成面向芙蓉湖的校园中心。',
      ),
      (
        title: '建筑与空间',
        text:
            '五楼采用一主四从布局，颂恩楼21层，四座从楼6层。红瓦坡顶、连廊、大台阶与嘉庚广场共同构成整体，既延续传统屋顶意象，也容纳现代教学和办公空间。',
      ),
    ],
  ),
  'sm-qunxian': CampusStory(
    '1921年5月9日奠基、1922年陆续落成，是厦大第一批校舍。陈嘉庚选择国耻纪念日开工，寄托教育兴国、发奋求学的志向。',
    _qunxian,
    sections: [
      (
        title: '营建沿革',
        text: '1921年5月9日奠基，1922年首批五座校舍落成。陈嘉庚选择国耻纪念日开工，以教育兴国的愿望勉励师生。',
      ),
      (
        title: '建筑与布局',
        text:
            '五楼坐北朝南、一字展开，由连廊串联。中央群贤楼为绿色琉璃瓦屋顶、花岗岩墙身，两端囊萤与映雪楼呈红瓦白墙，形成中西合璧的早期校园形象。',
      ),
    ],
  ),
  'sm-jiannan': CampusStory(
    '1951至1954年建成，由李光前捐资筹建，主楼大会堂与四座从楼共同面向上弦场，形成厦大标志性的滨海建筑景观。',
    _jiannan,
    sections: [
      (
        title: '营建与命名',
        text:
            '1951至1954年间由李光前捐资筹建。南安、南光联系其祖籍与姓名，成义、成智分别取其两位儿子之名；建南与集美的福南大会堂相呼应。',
      ),
      (
        title: '布局与历史用途',
        text:
            '建南大会堂居中，西侧南安、成义原为化学馆、生物馆，东侧南光、成智原为物理馆、图书馆。五楼面向上弦场，教学、阅读与公共集会共同构成校园生活。',
      ),
    ],
  ),
  'sm-furong': CampusStory(
    '芙蓉楼群建于20世纪50年代，与群贤、建南楼群共同构成厦大早期嘉庚风格建筑的重要代表，2006年列入全国重点文物保护单位。',
    'https://zchqc.xmu.edu.cn/info/1251/9131.htm',
  ),
  'xa-main': CampusStory(
    '翔安嘉庚楼群延续“一主四从”的布局：图书馆居中，两侧教学与实验楼通过连廊相接，将传统屋顶与现代校园空间结合。',
    'https://arch.xmu.edu.cn/info/1013/13313.htm',
    sections: [
      (
        title: '校区建设背景',
        text:
            '翔安校区2011年4月6日奠基，2012年9月迎来首批师生。主楼群延续一主四从与一高四低的形制，以中央图书馆和两侧教学实验空间组织校园核心。',
      ),
      (
        title: '建筑与公共空间',
        text: '楼群呈弧线展开，通过连廊连接；传统坡屋顶与现代教学设施并置。这里的楼群营建背景与各楼落成、图书馆投入使用和冠名节点分别记录。',
      ),
    ],
  ),
  'xa-west': CampusStory(
    '信息学院2021年面向师生校友征集新院楼名称，把正直、求学、探索与智慧融入楼名，形成与信息学科相呼应的校园文化。',
    _west,
    sections: [
      (
        title: '命名过程',
        text:
            '信息学院于2020年11月发起征集，2021年4月公示名称。正信、学信、嘉信、启信、智信、睿信分别联系正直、学习、嘉庚精神、探索和智慧。',
      ),
      (
        title: '空间用途与名称',
        text:
            '公示分别列出行政办公、公共教学、科研团队、实验教学等用途。3号楼当时公示名为嘉信楼；当前地图目录使用益海嘉里楼名称，另有学院使用记录；历史公示与现名的对应沿革仍待核实。',
      ),
    ],
    references: ['https://informatics.xmu.edu.cn/info/1102/16631.htm'],
  ),
  'xa-marine': CampusStory(
    '2014年元旦，希平楼与周隆泉楼举行落成典礼。来自企业家和校友的捐赠，为海洋学科的教学与科研平台建设提供了支持。',
    _x2014,
  ),
  'xa-life': CampusStory(
    '黄朝阳楼在2014年元旦举行落成典礼，由黄朝阳校友捐建，是翔安校区生命科学教学科研建设的一部分。',
    _x2014,
  ),
  'area-9985b581a302421681fa4b2c59e48622': CampusStory(
    '这里的庄瑾楼由庄凌校友捐建，并于2014年元旦举行落成典礼，为药学师生提供教学与实验空间。',
    _x2014,
  ),
  'xa-environment': CampusStory(
    '环境与生态学院大楼于2017年6月8日正式命名为金泉楼，纪念捐赠者郑金泉支持教育的心意。',
    'https://news.xmu.edu.cn/info/1006/4084.htm',
  ),
  'xa-shared-engineering': CampusStory(
    '2021年校庆前夕，新工科研发大楼举行落成活动。共享实验、交叉研究与创新实践是这处校园空间的建设理念。',
    'https://news.xmu.edu.cn/info/1003/39399.htm',
  ),
  'xa-animal': CampusStory(
    '实验动物中心于2012年成立，由生命科学学院和医学院原有平台整合组建，为全校教学科研提供实验动物与技术服务。这里维护有一期与二期设施。',
    'https://lac.xmu.edu.cn/jggk/zxjj.htm',
  ),
  'zz-main': CampusStory(
    '漳州主楼群四座从楼于2003年竣工，中央主楼于2005年1月建成。“一主四从”的中西合璧布局，使隔海相望的新老校园在建筑语言上遥相呼应。',
    'https://jjc.xmu.edu.cn/info/1021/1554.htm',
    sections: [
      (
        title: '营建节点',
        text:
            '四座五层从楼2002年7月开工，2003年8月竣工投入使用。中央主楼2002年11月开工，2005年1月建成，地上12层、地下1层。',
      ),
      (
        title: '布局与功能',
        text:
            '主楼群位于校门主轴，采用一主四从的格局。基建处介绍其承担公共教学实验、图书信息、学术会议与行政管理等功能，不将整组功能推定为每栋楼的全部用途。',
      ),
    ],
  ),
};

CampusStory? campusStoryFor({
  TeachingBuilding? building,
  TeachingGroup? group,
}) {
  if (building == null) return campusGroupStories[group?.id];
  final own = campusBuildingStories[building.id];
  if (own != null) return own;
  final context = campusGroupStories[building.groupId];
  if (context == null) return null;
  // A group's dates are not evidence for every member building's completion.
  return CampusStory(
    '所在片区的故事：${context.text}',
    context.url,
    sections: context.sections,
    references: context.references,
  );
}

/// Source URLs are retained for maintenance, never launched from the atlas.
const campusStorySources = <String, String>{
  'https://cflc.xmu.edu.cn/info/1191/8664.htm': '外文学院《学院简介》',
  'https://soe.xmu.edu.cn/xygk/xyjj.htm': '经济学院《学院简介》',
  'https://chem.xmu.edu.cn/info/1149/1023.htm':
      '化学化工学院《化学系与物理化学研究所（1921—1991）》',
  'https://news.xmu.edu.cn/info/1023/32039.htm': '厦门大学新闻网转载《35岁厦大艺术学院才气逼人》',
  'https://jjc.xmu.edu.cn/info/1019/53751.htm': '基建处《法学院扩建初步介绍》',
  'https://news.xmu.edu.cn/info/1002/3560.htm': '厦门大学新闻网《翔安校区一批新楼落成》',
  'https://informatics.xmu.edu.cn/info/1103/12447.htm': '信息学院《新院楼名称公示》',
  'https://news.xmu.edu.cn/info/1047/41869.htm': '厦门大学新闻网《群贤楼群》',
  'https://news.xmu.edu.cn/info/1811/481661.htm': '厦门大学新闻网《建南楼群（上篇）》',
  'https://news.xmu.edu.cn/info/1003/26408.htm': '厦门大学新闻网有关名师楼宇命名的校庆报道',
  'https://news.xmu.edu.cn/info/1771/476361.htm': '厦门大学新闻网《思明校区嘉庚楼群》',
  'https://xcb.xmu.edu.cn/info/1051/12411.htm': '党委宣传部关于庄汉水楼冠名的报道',
  'https://law.xmu.edu.cn/info/1050/22411.htm': '法学院关于法学发展论坛的报道',
  'https://soe.xmu.edu.cn/info/6411/507124.htm': '经济学院关于经济楼改造的记录',
  'https://std.xmu.edu.cn/info/2501/46791.htm': '科技处关于椭圆楼科研团队的报道',
  'https://news.xmu.edu.cn/info/1023/33434.htm': '厦门大学新闻网《德旺图书馆揭牌》',
  'https://news.xmu.edu.cn/info/1006/4084.htm': '厦门大学新闻网《金泉楼命名揭牌》',
  'https://news.xmu.edu.cn/info/1003/39399.htm': '厦门大学新闻网《新工科研发大楼落成》',
  'https://news.xmu.edu.cn/info/1002/1636.htm': '厦门大学新闻网《嘉庚创新实验室》报道',
  'https://news.xmu.edu.cn/info/1047/41865.htm': '厦门大学新闻网《嘉庚楼群》',
  'https://zchqc.xmu.edu.cn/info/1251/9131.htm': '资产与后勤事务管理处《嘉庚风格建筑群概况》',
  'https://arch.xmu.edu.cn/info/1013/13313.htm': '建筑与土木工程学院《翔安校区嘉庚楼群》',
  'https://lac.xmu.edu.cn/jggk/zxjj.htm': '实验动物中心《中心简介》',
  'https://jjc.xmu.edu.cn/info/1021/1554.htm': '基建处《漳州校区主楼群》',
  'https://jjc.xmu.edu.cn/info/1021/1559.htm': '基建处《校本部科学艺术中心（恩明楼）》',
  'https://library.xmu.edu.cn/gybg/smxqtsg/jj.htm': '厦门大学图书馆《思明校区总馆简介》',
  'https://tyjxb.xmu.edu.cn/info/1050/1515.htm': '体育教学部《明培体育馆》',
  'https://ese.xmu.edu.cn/px/info/1231/1474.htm': '电子科学与技术学院《克立楼》',
  'https://alumni.xmu.edu.cn/xyzh2023/info/1019/1669.htm':
      '校友总会《佘施淑好：育慈善之种，修福慧双馨》',
  'https://lifelab.xmu.edu.cn/syjx/swjsscsx/kcjs.htm':
      '生命科学实验教学中心《生物技术生产实习课程介绍》',
  'https://baowei.xmu.edu.cn/info/1004/1485.htm': '保卫部《翔安校区创建特殊区域消防分类指导体系》',
  'https://med.xmu.edu.cn/xy/xyfzjj/xyjsfzjjxmylb.htm': '医学院《学院建设发展基金项目一览表》',
  'https://cm.xmu.edu.cn/xygk/xyfc.htm': '材料学院《学院简介》',
  'https://aerospace.xmu.edu.cn/info/1353/15883.htm': '航空航天学院《学院简介》',
  'https://library.xmu.edu.cn/gybg/yxzls/jyyjy.htm': '图书馆《教育研究院资料室简介》',
  'https://news.xmu.edu.cn/info/1003/27571.htm': '厦门大学新闻网《我校新闻传播学院正式成立》',
  ..._campusResearchSources,
};
