---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - gdml-parser
  - auxiliary-tags
  - gdml-schema-extension
  - geometry-construction
---

# g4-example-persistency-gdml-g03


The escape hatch beyond `<auxiliary>` tags: how to extend the GDML schema with custom, XSD-validated element types. The toy extension adds a `<color>` entity (RGBA visualization color) under a new `<extension>` section, backed by a companion `SimpleExtension.xsd`. The C++ side subclasses `G4GDMLReadStructure` to parse the new element when the parser delegates it. The tradeoff vs. aux tags: structured data with real schema validation vs. a free-form string bag — heavier, but the right choice when aux tags become unmanageable or you need typed fields with units.

## Key concepts demonstrated

- `gdml-schema-extension` — replace the `<gdml>` root with a custom root whose XSD lives next to the file; the parser picks up custom elements via the extension hook
- `gdml-parser` — `G4GDMLReadStructure` / `G4GDMLWriteStructure` subclassing; the extension object must be installed on the parser *before* `Read()` or unknown elements are silently skipped
- `auxiliary-tags` — G03 is the structured alternative to aux tags; use aux tags for simple flags, schema extensions for anything with sub-fields or required units
- `xsd-validation` — `xsi:noNamespaceSchemaLocation` pointing at a local XSD enables `xmllint --schema` one-liner in CI for pre-run GDML validation
