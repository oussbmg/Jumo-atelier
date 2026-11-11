# Marker Creator (Flutter / Android, offline)

Garment marker tool: real fabric dimensions, rectangle + irregular polygon pieces (X/Y in cm),
to-scale placement, efficiency / waste, fabric cost per marker **and per piece**, imported marker
image with calibration, product costing. Everything is stored locally (no internet).

## Geometry conventions
* Internal unit: **cm** (`double`). Areas for costing: **m²**.
* Marker x axis = marker **length**, y axis = fabric **width**.
* A placement stores the centre of the piece's bounding box + rotation; rotation never changes area.
* Polygon area = shoelace formula. Self-intersecting polygons are rejected.
* Side lengths alone cannot define an irregular polygon: enter X/Y points, or add points by
  *side length + direction angle*.

## Cost allocation
`piece cost = marker fabric cost × (piece total area / total pieces area)`
The waste cost is shared proportionally, so piece costs add up to the full marker cost.
The "Calculation details" section also shows the area-only cost (area × price per m²).

## Build
GitHub: push the repo, the workflow `.github/workflows/build-apk.yml` generates the Android
platform files (`flutter create`, sources are preserved), runs analyze + tests, builds the release
APK and uploads it as artifact `marker-creator-apk`.

Local:
```
flutter create --platforms=android --org com.markercreator --project-name marker_creator .   # once; keeps lib/ and pubspec.yaml if you back them up first
flutter pub get
flutter test
flutter build apk --release
```
(`flutter create .` may overwrite `lib/main.dart`, `test/` and `pubspec.yaml` in an existing folder: copy them aside first, as the workflow does.)

APK: `build/app/outputs/flutter-apk/app-release.apk` (signed with the debug key; add your own keystore for the Play Store).

## Limits of version 1
No curves, no automatic nesting, no DXF/PDF/Excel/cloud (architecture allows adding them:
`PlacementService`, `Geo`, `MarkerCalc` are UI-independent). Image calibration is a two-point
scale (no perspective correction); the image can be moved but not rotated.
