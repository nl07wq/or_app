import '../models/report_sync_envelope.dart';
import 'dart:convert';
import 'report_sync_payload_registry.dart';

abstract interface class ReportSyncInstructionProvider {
  ReportSyncExchangeType get exchangeType;
  String buildInstruction();
}

class StandardReportSyncInstructionProvider
    implements ReportSyncInstructionProvider {
  @override
  final ReportSyncExchangeType exchangeType;
  final ReportSyncPayloadSchema schema;
  const StandardReportSyncInstructionProvider(this.exchangeType, this.schema);

  @override
  String buildInstruction() =>
      '''
You are preparing an Operation Reboot REPORT SYNC response for ${exchangeType.stableId}.
Return exactly one JSON object. Do not return Markdown, code fences, comments, or natural-language text outside JSON.
Use format "operation-reboot-report-sync", envelopeVersion 1, schemaVersion "1.0", and direction "response".
Echo exchangeType, requestId, requestDigest, and operationDate exactly from the request. For Daily Debrief also echo confirmationDigest exactly.
Do not add unknown fields or sections. Do not convert numbers to strings. Preserve null separately from numeric zero.
Do not convert null to an empty string. Use only stable IDs defined by the schema.
Do not invent facts, infer missing facts, or generate unsupported values. Use only the supplied request facts.
The packageDigest must be lowercase SHA-256 over canonical JSON of the envelope excluding packageDigest itself.
The response payload must follow this exact exchange schema example (placeholder values are illustrative only and are not real facts):
${const JsonEncoder.withIndent('  ').convert(schema.minimalResponseExample)}
'''
          .trim();
}

class ReportSyncInstructionProviderRegistry {
  final Map<ReportSyncExchangeType, ReportSyncInstructionProvider> _providers;
  ReportSyncInstructionProviderRegistry(
    Iterable<ReportSyncInstructionProvider> providers,
  ) : _providers = {
        for (final provider in providers) provider.exchangeType: provider,
      } {
    if (_providers.length != ReportSyncExchangeType.values.length) {
      throw StateError('All REPORT SYNC instruction providers are required.');
    }
  }
  factory ReportSyncInstructionProviderRegistry.standard() =>
      ReportSyncInstructionProviderRegistry([
        for (final type in ReportSyncExchangeType.values)
          StandardReportSyncInstructionProvider(
            type,
            ReportSyncPayloadRegistry.standard().forType(type),
          ),
      ]);
  ReportSyncInstructionProvider forType(ReportSyncExchangeType type) =>
      _providers[type]!;
}
