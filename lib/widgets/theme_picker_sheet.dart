import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ThemePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiaryOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Choose Theme',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _option(
              context,
              icon: Icons.brightness_auto_outlined,
              title: 'System Default',
              subtitle: 'Follow your device\'s setting',
              selected: themeProvider.isSystem,
              onTap: () async {
                await themeProvider.setSystem();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            _option(
              context,
              icon: Icons.light_mode_outlined,
              title: 'Light',
              subtitle: 'Always use the light theme',
              selected: themeProvider.isLight,
              onTap: () async {
                await themeProvider.setLight();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            _option(
              context,
              icon: Icons.dark_mode_outlined,
              title: 'Dark',
              subtitle: 'Always use the dark theme',
              selected: themeProvider.isDark,
              onTap: () async {
                await themeProvider.setDark();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final brand = AppColors.brandOf(context);
    final secondary = AppColors.textSecondaryOf(context);
    final tertiary = AppColors.textTertiaryOf(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: selected ? brand : tertiary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? brand : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: secondary),
      ),
      trailing: selected ? Icon(Icons.check_circle, color: brand) : null,
      onTap: onTap,
    );
  }
}
