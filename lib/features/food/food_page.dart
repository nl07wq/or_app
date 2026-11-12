import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/food_history_button.dart';
import 'widgets/food_feature_chrome.dart';
import 'widgets/food_manual_card.dart';
import 'widgets/food_sync_card.dart';
import 'widgets/food_vfd_back_button.dart';
import 'food_catalog_page.dart';
import '../themes/base_camp/base_camp_facility_entry_page.dart';
import '../themes/base_camp/base_camp_presentation.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  @override
  Widget build(BuildContext context) {
    if (BaseCampPresentation.maybeOf(context)?.screen == BaseCampScreen.food) {
      return _buildBaseCampEntry(context);
    }
    return FoodFeatureScaffold(
      appBar: foodFeatureAppBar(
        title: 'FOOD',
        leading: Navigator.canPop(context) ? const FoodVfdBackButton() : null,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              transparentSurface: true,
              child: OperationButton(
                icon: Icons.storage_outlined,
                text: 'OPEN FOOD DATABASE',
                frostedGradient: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodCatalogPage()),
                ),
              ),
            ),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

            AppSpacing.gapSM,

            const OperationDescription(text: 'ChatGPTから\n食事記録を取り込みます。'),

            AppSpacing.gapMD,

            const FoodSyncCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseCampEntry(BuildContext context) => BaseCampFacilityEntryPage(
    title: 'FOOD',
    imageAsset: baseCampFoodEntryAsset,
    actions: [
      const BaseCampFacilityEntryAction(
        description: '食品を検索または手入力して、食事を記録します。',
        child: FoodManualCard(),
      ),
      const BaseCampFacilityEntryAction(
        description: '保存済みの食事履歴を確認・編集します。',
        child: FoodHistoryButton(),
      ),
      BaseCampFacilityEntryAction(
        description: '食品・商品情報と栄養データを登録して再利用します。',
        child: OperationButton(
          icon: Icons.storage_outlined,
          text: 'FOOD DATABASE',
          frostedGradient: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoodCatalogPage()),
          ),
        ),
      ),
      const BaseCampFacilityEntryAction(
        description: 'ChatGPTから食事記録を取り込みます。',
        child: FoodSyncCard(),
      ),
    ],
  );
}
