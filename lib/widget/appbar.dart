import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LostFoundAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? tabController;
  final VoidCallback? onRefresh;
  final bool showTabs;

  const LostFoundAppBar({
    super.key,
    this.tabController,
    this.onRefresh,
    this.showTabs = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: FutureBuilder<String?>(
        future: AuthService.getUserName(),
        builder: (context, snapshot) {
          // No need for !mounted check in StatelessWidget + FutureBuilder
          final name = snapshot.data ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lost & Found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
              Text(
                'Welcome, $name',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
      ],
      bottom: showTabs && tabController != null
          ? TabBar(
              controller: tabController,
              tabs: const [
                Tab(text: 'Lost Items', icon: Icon(Icons.search_off)),
                Tab(text: 'Found Items', icon: Icon(Icons.check_circle)),
              ],
            )
          : null,
      elevation: 2, 
    );
  }
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showTabs ? 48 : 0));
}