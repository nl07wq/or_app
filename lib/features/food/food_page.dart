import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

import 'food_catalog_page.dart';
import 'food_recipe_page.dart';

import 'widgets/food_history_button.dart';
import 'widgets/food_manual_card.dart';
import 'widgets/food_mixed_summary_card.dart';
import 'widgets/food_sync_card.dart';

class FoodPage extends StatelessWidget {
  const FoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FOOD')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  'Operation Reboot Reportから\n'
                  '本日の食事記録を同期します。',
            ),

            AppSpacing.gapMD,

            const FoodSyncCard(),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.edit_note, title: 'MANUAL ENTRY'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '食品を検索または手入力して\n'
                  '食事を記録します。',
            ),

            AppSpacing.gapMD,

            const FoodManualCard(),

            AppSpacing.gapMD,

            const FoodMixedSummaryCard(),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '過去の食事履歴を\n'
                  '確認・編集できます。',
            ),

            AppSpacing.gapMD,

            const FoodHistoryButton(),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.restaurant_menu,
              title: 'FOOD DATABASE',
            ),
            AppSpacing.gapMD,
            OperationCard(
              child: OperationButton(
                icon: Icons.restaurant_menu,
                text: 'FOOD DATABASE',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodCatalogPage()),
                ),
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.menu_book,
              title: 'RECIPE DATABASE',
            ),
            AppSpacing.gapMD,
            OperationCard(
              child: OperationButton(
                icon: Icons.menu_book,
                text: 'RECIPE DATABASE',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodRecipePage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
