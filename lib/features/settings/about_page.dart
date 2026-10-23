import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/app_update_section.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.updateService, this.updateController});
  final UpdateService? updateService;
  final AppUpdateController? updateController;
  static const repository = 'https://github.com/MidiAug/xmu-rollcall';

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final _package = PackageInfo.fromPlatform();

  Future<void> _openRepository() async {
    try {
      if (!await launchUrl(
        Uri.parse(AboutPage.repository),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('无法打开链接');
      }
    } catch (_) {
      if (mounted) AppToast.show(context, '无法打开仓库地址，请复制后在浏览器中打开', error: true);
    }
  }

  Future<void> _copyRepository() async {
    await Clipboard.setData(const ClipboardData(text: AboutPage.repository));
    if (mounted) AppToast.show(context, '已复制仓库地址');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '关于',
      body: AppContentColumn(
        maxWidth: 600,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppDensity.isTouch(context) ? 24 : 60,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
            const Center(child: BrandMark(size: 56)),
            const SizedBox(height: 14),
            Text(
              '厦大签到',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 6),
            FutureBuilder<PackageInfo>(
              future: _package,
              builder: (context, info) => Text(
                info.hasData
                    ? '版本 ${info.data!.version}'
                    : info.hasError
                    ? '版本信息暂不可用'
                    : '正在读取版本',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '为厦大畅课准备的轻量客户端。\n课堂签到、作业与课表，集中在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.8, color: p.muted),
            ),
            const SizedBox(height: 32),
            if (widget.updateController != null)
              AppUpdateSection(controller: widget.updateController)
            else if (widget.updateService != null)
              AppUpdateSection(package: _package, service: widget.updateService)
            else
              Consumer(
                builder: (context, ref, _) => AppUpdateSection(
                  controller: ref.watch(appUpdateControllerProvider),
                ),
              ),
            SettingsSection(
              header: '开源项目',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.code_rounded),
                  title: 'GitHub 仓库',
                  subtitle: 'MidiAug/xmu-rollcall',
                  onTap: _openRepository,
                  trailing: IconButton(
                    tooltip: '复制仓库地址',
                    onPressed: _copyRepository,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                    ),
                    icon: Icon(Icons.copy_rounded, size: 17, color: p.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
