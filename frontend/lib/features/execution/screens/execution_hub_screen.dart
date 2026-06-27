import 'package:flutter/material.dart';
import 'execution_jobs_screen.dart';
import 'installers_list_screen.dart';
import 'site_updates_screen.dart';
import 'client_signoff_screen.dart';
import '../../../shared/widgets/module_tile.dart';

class ExecutionHubScreen extends StatelessWidget {
  final bool isAdmin;

  const ExecutionHubScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
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
            color: const Color(0xFF0061a4),
            onTap: () => pushScreen(
              context,
              ExecutionJobsScreen(myTasksOnly: !isAdmin),
            ),
          ),
          ModuleTile(
            title: 'Installers',
            icon: Icons.engineering,
            color: const Color(0xFF006e1c),
            onTap: () => pushScreen(context, const InstallersListScreen()),
          ),
          ModuleTile(
            title: 'Site Updates',
            icon: Icons.photo_camera,
            color: const Color(0xFF904d00),
            onTap: () => pushScreen(context, const SiteUpdatesScreen()),
          ),
          ModuleTile(
            title: 'Client Sign-off',
            icon: Icons.draw,
            color: const Color(0xFF5e4300),
            onTap: () => pushScreen(context, const ClientSignoffScreen()),
          ),
        ],
      ),
    );
  }
}
