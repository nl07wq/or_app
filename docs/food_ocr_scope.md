# Food OCR scope

## Nutrition Label Scanner

The user-facing scanner is limited to nutrition labels. It recognizes known
nutrition-label vocabulary and layout relationships, then reviews only these
primary fields before applying them to a draft:

- nutrition basis
- calories
- protein
- fat
- carbohydrate

The known-label dictionary also distinguishes sugar, fiber, and salt so their
values are not inferred as primary PFC fields. Numeric recognition is limited
to a known label's valid nearby number and unit; isolated numbers are not
assigned to fields. Supported layout responsibilities remain separated as
vertical lists, two-column tables, header/value rows, boxed or wrapped labels,
and labels above values.

Live scan, high-accuracy scan, camera photo, and photo-library input all use the
same nutrition recognition and review boundary. Tesseract remains the production
default. Paddle remains an internal query-selected PoC and diagnostic path.

## Package OCR

**Status: SEMI-PERMANENT PEND**

Package OCR is absent from normal user-facing routes. Its parser, candidate
types, test support, and PoC implementation are retained rather than deleted.
Package quantity remains manual input or catalog-prefilled data and is separate
from nutrition basis.

Reason: the current browser OCR approach is not sufficiently reliable for
product-front semantic extraction across logos, decorative text, backgrounds,
vertical text, flavor names, catch copy, and company names.

Reopen only when at least one materially new premise is approved:

1. An image-understanding AI such as the ChatGPT API is formally adopted.
2. An external Vision API policy is formally approved.
3. A materially stronger browser OCR architecture makes package semantic
   extraction practical.
4. The expected Operation Reboot value clearly exceeds its implementation and
   distribution cost.

Regex additions, crop changes, and OCR-threshold tuning alone are not reopen
conditions.
