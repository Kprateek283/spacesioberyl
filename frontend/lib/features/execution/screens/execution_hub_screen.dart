import 'package:flutter/material.dart';
import 'execution_jobs_screen.dart';
import 'installers_list_screen.dart';
import 'site_updates_screen.dart';
import 'client_signoff_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/module_tile.dart';
import '../../iam/screens/profile_screen.dart';

class ExecutionHubScreen extends StatelessWidget {
  final bool isAdmin;

  const ExecutionHubScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => pushScreen(context, const ProfileScreen()),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(24),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          ModuleTile(
            title: isAdmin ? 'All Jobs' : 'My Jobs',
            icon: Icons.construction,
            color: AppColors.primary,
            onTap: () => pushScreen(
              context,
              ExecutionJobsScreen(myTasksOnly: !isAdmin),
            ),
          ),
          ModuleTile(
            title: 'Installers',
            icon: Icons.engineering,
            color: AppColors.secondary,
            onTap: () => pushScreen(context, const InstallersListScreen()),
          ),
          ModuleTile(
            title: 'Site Updates',
            icon: Icons.photo_camera,
            color: AppColors.tertiary,
            onTap: () => pushScreen(context, const SiteUpdatesScreen()),
          ),
          ModuleTile(
            title: 'Client Sign-off',
            icon: Icons.draw,
            color: AppColors.primary,
            onTap: () => pushScreen(context, const ClientSignoffScreen()),
          ),
        ],
      ),
    );
  }
}
