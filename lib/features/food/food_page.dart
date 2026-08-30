import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/food_history_button.dart';
import 'widgets/food_manual_card.dart';
import 'widgets/food_sync_card.dart';
import 'food_catalog_page.dart';

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

            OperationDescription(text: 'ChatGPTから\n食事記録を取り込みます。'),

            AppSpacing.gapMD,

            const FoodSyncCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.edit_note, title: 'MANUAL ENTRY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '食品を検索または手入力して\n'
                  '食事を記録します。',
            ),

            AppSpacing.gapMD,

            const FoodManualCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            OperationDescription(
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

            AppSpacing.gapSM,

            const OperationDescription(
              text: '食品・商品情報と栄養データを登録し、\n食事記録で再利用できます。',
            ),

            AppSpacing.gapMD,

            OperationCard(
              child: OperationButton(
                icon: Icons.storage_outlined,
                text: 'OPEN FOOD DATABASE',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodCatalogPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
