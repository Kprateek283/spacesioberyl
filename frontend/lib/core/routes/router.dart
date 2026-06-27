import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../features/crm/screens/crm_lead_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthWrapper(),
        routes: [
          GoRoute(
            path: 'crm/lead/:id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'];
              final id = int.tryParse(idStr ?? '');
              if (id == null) return const Scaffold(body: Center(child: Text('Invalid Lead ID')));
              
              // We pass a dummy map since the original screen likely expects lead data or fetches it.
              // We'll let CrmLeadDetailScreen handle fetching if it needs to, or provide a basic stub
              return CrmLeadDetailScreen(lead: {'id': id, 'client_name': 'Loading...'});
            },
          ),
        ],
      ),
    ],
  );
});
