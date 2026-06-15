import 'package:flutter/material.dart';

class UsageHeader extends StatelessWidget {
  const UsageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.help_outline_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'まいカゴの使い方',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '簡単に使える買い物リスト管理アプリ',
            style: Theme.of(
              context,
            )
                .textTheme
                .bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
