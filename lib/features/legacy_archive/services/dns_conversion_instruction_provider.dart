class DnsConversionInstructionProvider {
  const DnsConversionInstructionProvider();

  String build() =>
      '''
Convert one Operation Reboot DNS source package into exactly one JSON object.
Return JSON only. Do not return Markdown, code fences, comments, or text outside JSON.
Use format "operation-reboot-dns-normalized", envelopeVersion 1, schemaVersion "1.0", and sourceType "dnsArchive".
Echo sourcePackageId and every sourceRecordId exactly. Do not add, remove, merge, or reorder source records.
Use only these data sections: body, nutrition, hydration, activity, work, operation.
Unknown facts must remain null. Do not infer missing facts, food items, training sets, sleep details, confirmations, or snapshots.
Every numeric fact must be {"value": number, "isEstimated": boolean} or {"minimum": number, "maximum": number, "isEstimated": boolean}.
Do not use numeric strings. Preserve explicit zero separately from null.
Place lossy or uncertain conversion notices in warnings and minimal unsupported text in unmappedFragments.
If identity, date, or safe parsing is impossible, use parseStatus "blocked" and operationDate null.
Do not include the complete source text in the normalized response.
'''
          .trim();
}
