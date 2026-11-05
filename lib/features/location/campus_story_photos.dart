import 'teaching_catalog.dart';

/// Official photographs are loaded on demand; rights remain with their sources.
class CampusStoryPhoto {
  const CampusStoryPhoto({
    required this.url,
    required this.caption,
    required this.sourceUrl,
    required this.credit,
  });
  final String url, caption, sourceUrl, credit;
}

// Every mapping is checked against the original caption. Never use a group's
// image as an unlabelled stand-in for a member building without its own photo.
const campusStoryPhotos = <String, CampusStoryPhoto>{
  "group:sm-jiageng": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=TLlltbMzffUzvsojRCPLNnkUmnfU4WwfU4laozfRL4NPn7L0gihFp2hmCIa0M1yYnkhRLShkoRvDL4LinmWkL8l4LzMkU8LDnlCiL87aLzWFMzTkU8UYoRAFLz-ZMzN8gjfJQ4Oeo4xJQ564LShXptQ0g47sM470MRvDL4CPgtA8pUXcc&tid=1771&nid=476361&e=.png",
    caption: "嘉庚楼群全景",
    sourceUrl: "https://news.xmu.edu.cn/info/1771/476361.htm",
    credit: "厦门大学新闻网",
  ),
  "group:sm-qunxian": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=6nl-_YLmCiMR-4UFm7PL4MkLNl4nzr9kL47PUm9aL7U8ozU0gihFp2hmCIa0oShVM1ysM1y8Um-4LRU4nzU8nRGPM4U4ozWfn7L8MlC8MRfFLzT2ozviM4fFM7UboR7Jqjfjo4OeoDbT6sLPgDTJQty0LzG8MYy8Lz9DoSbw62A8c&tid=1047&nid=41869&e=.jpg",
    caption: "群贤楼",
    sourceUrl: "https://news.xmu.edu.cn/info/1047/41869.htm",
    credit: "厦门大学新闻网",
  ),
  "group:sm-jiannan": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=uU8-UZMRCbUm6RUn4NZUzVkM4-DozNSZLl-bo7UZUmrVMNU0gihFp2hmCIa0UYhfoSybokh2LlC8UmLZLRAVLmARLRC4L8rVM4Qfn7Q7nmVFU4L4MmLaM4VFMm6fnl-Jqjfjo4OeoDbT6sLPgDTJQty0Lz9PLSy8oR7DMm7Jqdznx&tid=1811&nid=481661&e=.jpg",
    caption: "建南大会堂",
    sourceUrl: "https://news.xmu.edu.cn/info/1811/481661.htm",
    credit: "厦门大学新闻网",
  ),
  "building:user-f8a43b10fd564815978224509c69b0d9": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=6nl-_YLmCiMR-4UFm7PL4MkLNl4nzr9kL47PUm9aL7U8ozU0gihFp2hmCIa0oShVM1ysM1y8Um-4LRU4nzU8nRGPM4U4ozWfn7L8MlC8MRfFLzT2ozviM4fFM7UboR7Jqjfjo4OeoDbT6sLPgDTJQty0LzG8MYy8Lz9DoSbw62A8c&tid=1047&nid=41869&e=.jpg",
    caption: "群贤楼",
    sourceUrl: "https://news.xmu.edu.cn/info/1047/41869.htm",
    credit: "厦门大学新闻网",
  ),
  "building:sm-nangying": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=6LRA_kM46fLzr2nFRnfnRlDnzrRnl79ao7UaM4QfUmQknm-0gihFp2hmCIa0M1y8n1y4LSyiL4TkLNlYM4UaUlUYU4-aLm94nzC8o7M2MNQFnN7sMRfkMznFoz-8ol-Jqjfjo4OeoDbT6sLPgDTJQty0LzG8MYy8Lz9DoSbw62A8c&tid=1047&nid=41869&e=.jpg",
    caption: "囊萤楼",
    sourceUrl: "https://news.xmu.edu.cn/info/1047/41869.htm",
    credit: "厦门大学新闻网",
  ),
  "building:sm-yingxue": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=6UmC_4M874L7lPMFzCDo7lsollZoRA9fn7lbo7LinmW2nz-0gihFp2hmCIa0MYyiLShfnSh7MmCaU4T2oRLsMR-iM7Q2MmfVnzTVL7U4LmWFLR62nR-DUzfFMzLYMlUJqjfjo4OeoDbT6sLPgDTJQty0LzG8MYy8Lz9DoSbw62A8c&tid=1047&nid=41869&e=.jpg",
    caption: "映雪楼",
    sourceUrl: "https://news.xmu.edu.cn/info/1047/41869.htm",
    credit: "厦门大学新闻网",
  ),
  "building:sm-jiannan": CampusStoryPhoto(
    url:
        "https://news.xmu.edu.cn/virtual_attach_file.vsb?afc=uU8-UZMRCbUm6RUn4NZUzVkM4-DozNSZLl-bo7UZUmrVMNU0gihFp2hmCIa0UYhfoSybokh2LlC8UmLZLRAVLmARLRC4L8rVM4Qfn7Q7nmVFU4L4MmLaM4VFMm6fnl-Jqjfjo4OeoDbT6sLPgDTJQty0Lz9PLSy8oR7DMm7Jqdznx&tid=1811&nid=481661&e=.jpg",
    caption: "建南大会堂",
    sourceUrl: "https://news.xmu.edu.cn/info/1811/481661.htm",
    credit: "厦门大学新闻网",
  ),
  "building:xa-pool": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nzLCbLlCsLNCsnQR62UmVVnz78U4Vq2n7LDU8QVnmCio7U0gihFp2hmCIa0LYybLkyDU1y4M4vaM4GinlLanl7PoRVVL7WkUNnRL4rfMzWFoz7ZUmQkMmMFolMkM47Jqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "佘明培游泳馆",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-dewang": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LlVCRMz78nRL8UQ8VRn7U8MmL4Lz9qbLzlsM8W2M878MNU0gihFp2hmCIa0LShkM1y4okyiM4AfLRNbL4UYMmlDUNQRM4AVM4G8LRL4LRWFM7LaLm9bL7WFLmGbLlnkgtXaQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.jpg",
    caption: "德旺图书馆",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-zhou": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5ozUCPLmNZUzv8MQzTRL4QfnN-8U4fqkLRCaU47PL4W2oz-0gihFp2hmCIa0okhfUYhVMSy4nRL4ozrkLlUPo7-PoR-DMmNbnzQfnRG8nzWFLRUsM4MRLmrFLz7Po7-8gjfJQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.png",
    caption: "周隆泉楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/1.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-ellipse": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5M4nCRU4LPLzCDUQmvZUlUbUlnfnRrq7ollZU49bLR-iL7C0gihFp2hmCIa0oShRMYyZL1y4M4vPLl7aM7VkM4UYoz7YnlLiM474oz67nzWFL4vsU4LsUzMFozCiLlUJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "椭圆楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/1.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-molecular": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LmCCaUmAVL462nQNCbnmnkLRG4oRCq8M49ZU4ARnmLZnRC0gihFp2hmCIa0Lkh7USy4M1yDM4r2LNLZnzfRLmvaMlV2U4GaoRN4M4VRo7nFnz9DMNCbLlMFo7Q7MmlJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "分子影像大楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/1.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:user-27aac214fc4744e1af094ea519314484": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5UlQC7UmN8L87YUQ4viLN-sMz9inlLqaUmV2MzLiU8C8M7U0gihFp2hmCIa0MSyZLShRokybn7r2nNL8MzL4M4L4L4f2nzV2U8LiM4vaUmnFL7UDMRliUzQFLzARo7M2gjfJQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.png",
    caption: "爱秋体育馆",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:sm-library": CampusStoryPhoto(
    url:
        "https://library.xmu.edu.cn/virtual_attach_file.vsb?afc=9LRfA2MR62LzGiU1mMkLmL4nlL4Lm-msUmfkMlLbLNWVozC0gihFp2hmCIa0Lkh2oSyaLYy8Ul78M8LZMRlsMNlsLNQ7MzfVnzvDM8Uanz6FUmLYLz6VUmQFL4CaU87Jqjfjo4OeoDPXCjWAvjNYLR-4gDTJQty0LzG8MSyPMRl8L4CiMSbw62N8c&oid=1968931208&tid=1045&nid=14543655&e=.jpg",
    caption: "思明校区图书馆总馆正门",
    sourceUrl: "https://library.xmu.edu.cn/gybg/smxqtsg/jj.htm",
    credit: "厦门大学图书馆",
  ),
  "building:sm-scienceart": CampusStoryPhoto(
    url:
        "https://jjc.xmu.edu.cn/virtual_attach_file.vsb?afc=tLRCjsUzUYM4MRMw7CioRfknzLbUz7XaMzMRnznkL87PUml0gihFp2hmCIa0MYy8oSy4M1hVLml4nmVfnmTknzWRLlQ2LmvDnR7PoR78LRAFozWkU87snzQFLl7iMl-Jqjfjo4OeoDX/CYhXptQ0g47aLm70LzlioSbw62/8c&oid=2134240691&tid=1021&nid=1559&e=.jpg",
    caption: "科学艺术中心（恩明楼）",
    sourceUrl: "https://jjc.xmu.edu.cn/info/1021/1559.htm",
    credit: "厦门大学基建处",
  ),
  "building:user-91194729b68a4278bbbdd992af84e37b": CampusStoryPhoto(
    url:
        "https://www.xmu.edu.cn/virtual_attach_file.vsb?afc=5U4vCbU4vYUNlbMQ4r2M77PnmLaMl-qbnz9bM8nfLmrRLzU0gihFp2hmCIa0LYy8USyZnSy8oRCDLzCbLzW2L8rkM7-PM4r7MRUZn7UZnmrFLmQ7UmUYMmWFM8CDnmUJqjfjo4OeosAx6ShXptQ0gY84gY84gtA8pUpcc&e=.jpg",
    caption: "建文楼",
    sourceUrl: "https://www.xmu.edu.cn/sdgl/xyfg.htm",
    credit: "厦门大学",
  ),
  "building:sm-econ": CampusStoryPhoto(
    url:
        "https://www.xmu.edu.cn/virtual_attach_file.vsb?afc=5nmQCRnRUinNlPUQzN8Lmf7LRCYMmCqDL4LDMzVfnN7ZUlU0gihFp2hmCIa0MSh2U1hVUSysUmGiL4vZL8M2Lm-aoRlsMlMRLNM7U8UZo7QFMzCDMllbM7VFMmC4nm9Jqjfjo4OeosAx6ShXptQ0gY84gY84gtA8pUpcc&e=.jpg",
    caption: "经济楼",
    sourceUrl: "https://www.xmu.edu.cn/sdgl/xyfg.htm",
    credit: "厦门大学",
  ),
  "building:sm-keli": CampusStoryPhoto(
    url:
        "https://www.xmu.edu.cn/virtual_attach_file.vsb?afc=5LzvCsL4GPL7UYLQm7PMNVRnznVnlWqkUNUYU8Lbo7W7U4l0gihFp2hmCIa0MShVLYyDM1hfUmC8Umv8U4L4MzMfMzlboRM2Lz9PMlUboRrFnzn2L8CDL4nFMNUsLzlJqjfjo4OeosAx6ShXptQ0gY84gY84gtA8pUpcc&e=.jpg",
    caption: "克立楼",
    sourceUrl: "https://www.xmu.edu.cn/sdgl/xyfg.htm",
    credit: "厦门大学",
  ),
  "building:user-5f6287add59340049c7c4fafc02f0e90": CampusStoryPhoto(
    url:
        "https://zzxq.xmu.edu.cn/Uploads/image/20130903/20130903032757_85325.jpg",
    caption: "理工大楼",
    sourceUrl: "https://zzxq.xmu.edu.cn/xqgk/xyfg/4.htm",
    credit: "厦门大学漳州校区",
  ),
  "building:user-02c50b4030ab40b8833d39e702bd39b4": CampusStoryPhoto(
    url:
        "https://zzxq.xmu.edu.cn/Uploads/image/20140912/20140912095927_86397.jpg",
    caption: "人文大楼",
    sourceUrl: "https://zzxq.xmu.edu.cn/xqgk/xyfg/4.htm",
    credit: "厦门大学漳州校区",
  ),
  "group:zz-main": CampusStoryPhoto(
    url:
        "https://zzxq.xmu.edu.cn/Uploads/image/20130903/20130903033149_82108.jpg",
    caption: "漳州校区主楼全景",
    sourceUrl: "https://zzxq.xmu.edu.cn/xqgk/xyfg/4.htm",
    credit: "厦门大学漳州校区",
  ),
  "building:user-2628b10cd98541b88b887a1450d1f7ca": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nmUCaol7ZLm7PUQ4-DMNU4U8CsLmAqknzlaLlV7M7nfM4L0gihFp2hmCIa0nSyDMkhfnkyDL49ZM8lDozN4LmW7LzlZMzvPLmGYLmn7UzQFUNCiL4LYnNnFozlPnlLJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "国际学术交流中心",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-huang": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nmGCiM7n7MmCsLQmvsnmLiM8MkUzrq2MRC4nmffMlQRnl70gihFp2hmCIa0L1yYnkh7okhVMNM7nR9aU8nVMl74nm62MNUPUlQkn7Mko7rFozUaLm9ZL8QFnRA7MmvJv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "黄朝阳楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-zeng": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nRUCanlUDnzC8oQ77Dnm-aMmQkUz-qPolC4ozvDU4QkLmC0gihFp2hmCIa0LkhkUSy4nSy8nzGaM8L8o7r2M7W2M8MRU4V2nlnRU8liM8nFMRNsM4f7LzVFLl-ZUm98gtXaQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.jpg",
    caption: "曾宪梓楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-zhuangjin": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LmLCPU8lsLzMfUQzARnlVVM4V2nlMq2nRU4LzA7olWkLlC0gihFp2hmCIa0nkyiLYyboSyPnzUaM7QRMR9DoR-aLNr2oRLanRviLlUYMRTFnlCDU8LsMlWFnRUbLmUJv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "庄瑾楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-xiping": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LR-CbU4WfMRWfnQRCiM7LsnN7DUz-qanmnVnmrVMmv4n7-0gihFp2hmCIa0LYyDnkyinkh7MmUaUNQfUlU8MNLDLNW2MlWfUNMkLRvZnmWFo7rkMR-bozfFMmnfMRCJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "希平楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-jinquan": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5L7WCVo7lsMz7boQlnfnlnkUmTkM4Aq2MR98UmrRn7l8M8C0gihFp2hmCIa0U1hRL1yDokyZL4GaLmC4Mm9bnz-anRVRUmUsMmLsM7r7Lz6FUmNDUmG8nzQFL4vbUmCJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "金泉楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "building:xa-kunluan": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5MzUCaolV2MzARLQ7WRU4nknNr2L4Tq7U4AVLRVRM4liU870gihFp2hmCIa0LSy8U1hkoShVnzl4nRTRnNW7Ll7sL8rRoRlDL4AVozn7ozMFLzr2MlC4oz6FLz-DnRvagjfJQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.png",
    caption: "坤銮楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-medical": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5ozvCDLzTVMRLsLQzTRLmffnmLYLzGqYo77soRGZU87DMlL0gihFp2hmCIa0U1y8okyiokybozUiL87ZnmTkUN7ZMl-PnNM2M4GZnlrVU8QFnzV2oRrkn7QFozGYM4-Jv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "医学院院楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-energy-college": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5M49CaMRviLNl4UQ4rVozNaLzrVM8QqRoz-bMzCDo7U8M7L0gihFp2hmCIa0LkysUSyiokhfL7W7oR9sM8C4ozL8UN7ZnzUYMmQRoz7DMzTFUNn2UlQ7nm6FM8WRnzlJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "能源学院院楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-west": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5UzCCZLmQRM7UboQRGDL8l4MmT2MNrq2L8Csoln7UN74n7l0gihFp2hmCIa0nSysUYy8oSy8MRU4Lz7YMmrfLRNaLRCanmTRn7V7UmvPUmrFL7CiMR-8M4VFU8QRU4UJv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "信息学院院楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-life": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nmGCiM7n7MmCsLQmvsnmLiM8MkUzrq2MRC4nmffMlQRnl70gihFp2hmCIa0L1yYnkh7okhVMNM7nR9aU8nVMl74nm62MNUPUlQkn7Mko7rFozUaLm9ZL8QFnRA7MmvJv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "生命科学学院黄朝阳楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-marine": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LR-CbU4WfMRWfnQRCiM7LsnN7DUz-qanmnVnmrVMmv4n7-0gihFp2hmCIa0LYyDnkyinkh7MmUaUNQfUlU8MNLDLNW2MlWfUNMkLRvZnmWFo7rkMR-bozfFMmnfMRCJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "海洋与地球学院希平楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-environment": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5L7WCVo7lsMz7boQlnfnlnkUmTkM4Aq2MR98UmrRn7l8M8C0gihFp2hmCIa0U1hRL1yDokyZL4GaLmC4Mm9bnz-anRVRUmUsMmLsM7r7Lz6FUmNDUmG8nzQFL4vbUmCJqjfjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.jpg",
    caption: "环境与生态学院金泉楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:xa-sph": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5nRUCanlUDnzC8oQ77Dnm-aMmQkUz-qPolC4ozvDU4QkLmC0gihFp2hmCIa0LkhkUSy4nSy8nzGaM8L8o7r2M7W2M8MRU4V2nlnRU8liM8nFMRNsM4f7LzVFLl-ZUm98gtXaQ4Oeo4xZC5APgDTJQty0gzL0gzLJqdpnx&oid=1701703785&e=.jpg",
    caption: "公共卫生学院曾宪梓楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
  "group:area-9985b581a302421681fa4b2c59e48622": CampusStoryPhoto(
    url:
        "https://xaxq.xmu.edu.cn/virtual_attach_file.vsb?afc=5LmLCPU8lsLzMfUQzARnlVVM4V2nlMq2nRU4LzA7olWkLlC0gihFp2hmCIa0nkyiLYyboSyPnzUaM7QRMR9DoR-aLNr2oRLanRviLlUYMRTFnlCDU8LsMlWFnRUbLmUJv2bjo4OeosAA_d70qIbtpYyxLYyxLYbw62p8c&oid=1701703785&e=.png",
    caption: "药学院庄瑾楼",
    sourceUrl: "https://xaxq.xmu.edu.cn/xqgk/xqfg/2.htm",
    credit: "厦门大学翔安校区",
  ),
};

CampusStoryPhoto? campusStoryPhotoFor({
  TeachingBuilding? building,
  TeachingGroup? group,
}) => building != null
    ? campusStoryPhotos['building:${building.id}']
    : campusStoryPhotos['group:${group?.id}'];
