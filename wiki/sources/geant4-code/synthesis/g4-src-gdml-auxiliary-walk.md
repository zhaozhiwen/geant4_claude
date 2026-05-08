---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/persistency/gdml/include/G4GDMLAuxStructType.hh:36-46
  - source/persistency/gdml/include/G4GDMLParser.hh:124-127
  - source/persistency/gdml/include/G4GDMLParser.icc:181-190
  - source/persistency/gdml/src/G4GDMLRead.cc:297-376
  - source/persistency/gdml/src/G4GDMLReadStructure.cc:763-815,1119-1131
  - source/persistency/gdml/src/G4GDMLParser.cc:94-104
related: []
---

# g4-src-gdml-auxiliary-walk

The GDML `<auxiliary>` tag is the primary mechanism for attaching user-defined metadata—sensitive detector flags, region names, optical surface properties—to logical volumes at geometry-description time. Header-only reading tells you `G4GDMLAuxStructType` exists and that `GetVolumeAuxiliaryInformation` returns it; it does not reveal the struct's tree structure, whether parents propagate to daughters, what happens on an empty lookup, or where the aux data is stored between `Read()` and `ConstructSDandField()`. All of those details live in the source.

## What the source actually does

### The data types

`G4GDMLAuxStructType` is a plain struct (not a class) defined at
`source/persistency/gdml/include/G4GDMLAuxStructType.hh:36-44`:

```cpp
struct G4GDMLAuxStructType
{
  G4String type;    // matches the GDML attribute "auxtype"
  G4String value;   // matches "auxvalue"
  G4String unit;    // matches "auxunit" (may be empty)
  std::vector<G4GDMLAuxStructType>* auxList;  // nested <auxiliary> children, or nullptr
};

using G4GDMLAuxListType = std::vector<G4GDMLAuxStructType>;
```

`G4GDMLAuxListType` is a `using` alias for `std::vector<G4GDMLAuxStructType>`
(`G4GDMLAuxStructType.hh:44`). There is no class, no virtual dispatch, no
reference counting.

### Parsing: `G4GDMLRead::AuxiliaryRead`

Every `<auxiliary>` element in the GDML structure section is parsed in
`source/persistency/gdml/src/G4GDMLRead.cc:297-376`.
The key points:

```cpp
// G4GDMLRead.cc:300-301
G4GDMLAuxStructType auxstruct = { "", "", "", 0 };
G4GDMLAuxListType* auxList    = nullptr;
```

The `auxList` pointer starts as `nullptr`. It is only heap-allocated if child
`<auxiliary>` elements exist (`G4GDMLRead.cc:362-366`):

```cpp
if(!auxList)
{
  auxList = new G4GDMLAuxListType;
}
auxList->push_back(AuxiliaryRead(child));  // recursive
```

If no nested children exist, `auxstruct.auxList` remains `nullptr`
(`G4GDMLRead.cc:370-373`). Callers must null-check before dereferencing.

### Storage: per-volume map in `G4GDMLReadStructure`

`source/persistency/gdml/src/G4GDMLReadStructure.cc:763-815` shows
`VolumeRead()`. When a `<volume>` element is processed, a local
`G4GDMLAuxListType auxList` accumulates every `<auxiliary>` child of that
volume. After the volume's `G4LogicalVolume*` is created:

```cpp
// G4GDMLReadStructure.cc:809-812
if(!auxList.empty())
{
  auxMap[pMotherLogical] = auxList;
}
```

`auxMap` is a `std::map<G4LogicalVolume*, G4GDMLAuxListType>` held inside
`G4GDMLReadStructure` (declared in its header at line 87 via the icc:
`using G4GDMLAuxMapType = std::map<G4LogicalVolume*, G4GDMLAuxListType>;`).
Volumes that have no `<auxiliary>` tags are **not inserted** into the map.

### Lookup: `GetVolumeAuxiliaryInformation`

`source/persistency/gdml/src/G4GDMLReadStructure.cc:1119-1131`:

```cpp
G4GDMLAuxListType G4GDMLReadStructure::GetVolumeAuxiliaryInformation(
  G4LogicalVolume* logvol) const
{
  auto pos = auxMap.find(logvol);
  if(pos != auxMap.cend())
  {
    return pos->second;
  }
  else
  {
    return G4GDMLAuxListType();   // empty vector by value
  }
}
```

The public `G4GDMLParser::GetVolumeAuxiliaryInformation` is an inline
one-liner that calls directly into the reader
(`source/persistency/gdml/include/G4GDMLParser.icc:181-185`):

```cpp
inline G4GDMLAuxListType
G4GDMLParser::GetVolumeAuxiliaryInformation(G4LogicalVolume* logvol) const
{
  return reader->GetVolumeAuxiliaryInformation(logvol);
}
```

The return type is `G4GDMLAuxListType` **by value**. An empty vector is
returned for any volume not in the map.

### Parent-to-daughter inheritance

There is none. `VolumeRead()` only collects `<auxiliary>` elements that are
direct children of the `<volume>` XML element (`G4GDMLReadStructure.cc:792-794`):

```cpp
if(tag == "auxiliary")
{
  auxList.push_back(AuxiliaryRead(child));
}
```

Daughter volumes placed inside the volume via `<physvol>` elements are parsed
separately by `Volume_contentRead()` (`G4GDMLReadStructure.cc:814`), and each
gets its own entry in `auxMap` only if it has its own `<auxiliary>` tags.

### Before `Read()` is called

The `auxMap` is a default-constructed `std::map`, which is empty.
`GetVolumeAuxiliaryInformation` on any `G4LogicalVolume*` will return an
empty vector. No crash, no exception; the map simply has no entries to find.
If called after `Clear()` (`G4GDMLReadStructure.cc:1166: auxMap.clear()`) the
same empty-map behaviour applies.

### Multi-module GDML

`G4GDMLReadStructure::FileRead` merges child module maps into the parent's
`auxMap` (`G4GDMLReadStructure.cc:344-349`):

```cpp
const G4GDMLAuxMapType* aux = structure.GetAuxMap();
if(!aux->empty())
{
  for(auto pos = aux->cbegin(); pos != aux->cend(); ++pos)
  {
    auxMap.insert(std::make_pair(pos->first, pos->second));
```

This insert uses the non-replacing form: if the same `G4LogicalVolume*` key
already exists in the parent map, the child module's entry is silently ignored.

## Gotchas / edge cases

1. **`auxList` pointer vs. empty list.** For a leaf `<auxiliary>` tag
   (no nested children), `auxstruct.auxList` is `nullptr`, not an empty
   vector. Code that does `for (const auto& c : *a.auxList)` without
   null-checking will segfault. The source pattern is always:
   `if(iaux->auxList) { ... }`.

2. **Return by value copies the whole list.** `GetVolumeAuxiliaryInformation`
   returns `G4GDMLAuxListType` by value, not by pointer or const reference.
   Iterating over the return value is fine; storing the return value is also
   fine (it's a real copy). Storing a pointer to the return value is undefined
   because the temporary is destroyed at the semicolon.

3. **`strip = true` by default.** `G4GDMLParser`'s default constructor sets
   `strip(true)` (`G4GDMLParser.cc:43`). This means volume names returned by
   `GetVolume()` and stored as `auxMap` keys have their pointer suffixes
   stripped. The `G4LogicalVolume*` pointers in `auxMap` are valid C++ object
   addresses; the stripping only affects the name strings, not the pointer
   keys. The key lookup by pointer is unaffected.

4. **No deduplication.** All `<auxiliary>` tags for a volume are pushed into
   the list. If the same type appears twice, both entries appear in the
   returned list. The first call to `break` after finding a match is therefore
   correct; not breaking would process all matching tags.

5. **Module merge silently drops conflicts.** When a child GDML module is
   loaded via `<file>`, its `auxMap` is merged using `insert` (not
   `insert_or_assign`). A duplicate `G4LogicalVolume*` key in the child module
   results in the parent's entry being kept and the child's being discarded
   without any warning.
