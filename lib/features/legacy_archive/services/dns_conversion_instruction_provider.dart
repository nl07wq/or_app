class DnsConversionInstructionProvider {
  const DnsConversionInstructionProvider();

  String build() =>
      '''
Convert the DNS Archive pasted after this prompt into Operation Reboot DNS Normalized Schema Version 1.

SOURCE CONTRACT
The next user message contains the DNS Archive. This prompt is not source data. Analyze only the DNS Archive pasted after this prompt.
The source may contain one or multiple concatenated DNS-YYYY-MM-DD records. Separate records at those boundaries and never mix values from different dates.
Extract only explicit values. Do not infer or complete missing facts. Preserve approximate values with isEstimated true, ranges with minimum and maximum, unknown values as null, conversion warnings in warnings, and minimal unconvertible fragments in unmappedFragments.
Do not generate source package IDs, source record IDs, formal record IDs, or digests; the app creates identity after validation.

RESPONSE CONTRACT
Return exactly one JSON object. Return JSON only. Do not return Markdown, code fences, comments, headings, explanations, or multiple JSON values.
Do not add unknown fields. Do not use numeric strings. Preserve explicit zero separately from null.
Use format "operation-reboot-dns-normalized", envelopeVersion 1, schemaVersion "1.0", and sourceType "dnsArchive".
Each record must contain exactly operationDate, parseStatus, data, warnings, and unmappedFragments. parseStatus must be parsed, parsedWithWarnings, or blocked. A blocked record may use null operationDate; every other record requires the DNS boundary date.
data must contain exactly body, nutrition, hydration, activity, work, and operation. A section may be null. Numeric facts must be either {"value": number, "isEstimated": boolean} or {"minimum": number, "maximum": number, "isEstimated": boolean}.

Return this exact field structure:
{
  "format": "operation-reboot-dns-normalized",
  "envelopeVersion": 1,
  "schemaVersion": "1.0",
  "sourceType": "dnsArchive",
  "generatedAt": "<UTC_TIMESTAMP>",
  "records": [
    {
      "operationDate": "<YYYY-MM-DD_OR_NULL>",
      "parseStatus": "parsed",
      "data": {
        "body": null,
        "nutrition": null,
        "hydration": null,
        "activity": null,
        "work": null,
        "operation": null
      },
      "warnings": [],
      "unmappedFragments": []
    }
  ]
}
'''
          .trim();
}
