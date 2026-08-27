# Skate Dataset Studio

A standalone iOS and Android Flutter application for creating a figure-skating edge-detection dataset from monocular smartphone video.

This repository is intentionally independent of earlier skating applications and task catalogues. It does not import legacy templates, recordings, calibrations, or labels.

## Current first milestone

- Create new task definitions from explicit line and circular-arc primitives.
- Preserve semantic expectations for foot, forward/backward travel, and inside/outside edge.
- Keep a separate subpath and physical gap for a foot change.
- Select one smartphone video and calibrate it with four rink boundary correspondences.
- Convert normalized image coordinates to rink-floor metres with a 3x3 homography.
- Store task snapshots, source-video URIs, manual calibration, and review labels in on-device SQLite.
- Keep expected task edges separate from verified observed edges. Only clear, expert-confirmed observations qualify for future classifier training.

## Coordinate contract

The only shared spatial value is a rink-floor point in metres.

```text
normalized video point (u, v) --homography--> rink point (xM, yM)
```

The same rink coordinate contract will later drive trajectory comparison, AR anchoring, and Quest VR replay. Pixel values are retained only as source-video audit evidence.

## Development
## Task notation

Task guides use an explicit line-based format. Every curve or line includes its
expected edge and subpath; a foot change must begin a different subpath and
meet the declared gap in rink metres.

```text
task Forward outside eight
gap 0.22
arc left-circle LFO left-circle 10 8 3 180 -180
arc right-circle RBO right-circle 16.22 8 3 180 180
```

`arc` columns are: segment id, edge, subpath, centre-x-m, centre-y-m,
radius-m, start-degrees, sweep-degrees. `line` uses: segment id, edge,
subpath, start-x-m, start-y-m, end-x-m, end-y-m. Supported edge codes are
`LFO`, `LFI`, `LBO`, `LBI`, `RFO`, `RFI`, `RBO`, and `RBI`.


The project path deliberately contains English-only folder names:

```text
D:\\SkateDatasetStudio
```

Run:

```powershell
flutter pub get
flutter analyze
flutter test --no-test-assets
```

`--no-test-assets` avoids a current Windows Flutter SDK shader-tool failure that occurs before pure Dart/Flutter tests start. It does not skip the project test files.

## Next milestones

1. Add an editor for multi-segment task notation and explicit AR guide geometry.
2. Add hockey-line-assisted calibration and a visual top-down rink review.
3. Add native video/pose pre-annotation, supporting-foot candidates, and review timeline ranges.
4. Add ARCore/ARKit rink anchors and an OpenXR Quest replay client using this same data contract.
5. Train and validate edge and turn classifiers only from verified labels.
