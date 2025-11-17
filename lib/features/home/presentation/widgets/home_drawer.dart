import 'package:flutter/material.dart';
import 'package:relay/core/constant/app_constants.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.onCreateCollection,
    required this.onCreateEnvironment,
  });

  final VoidCallback onCreateCollection;
  final VoidCallback onCreateEnvironment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quick actions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Create New Collection'),
              subtitle: const Text('Group and share related requests'),
              onTap: () {
                Navigator.of(context).pop();
                onCreateCollection();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Create New Environment'),
              subtitle: const Text('Store URLs, secrets, and configs'),
              onTap: () {
                Navigator.of(context).pop();
                onCreateEnvironment();
              },
            ),
          ],
        ),
      ),
    );
  }
}

