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
};

CampusStoryPhoto? campusStoryPhotoFor({
  TeachingBuilding? building,
  TeachingGroup? group,
}) => building != null
    ? campusStoryPhotos['building:${building.id}']
    : campusStoryPhotos['group:${group?.id}'];
