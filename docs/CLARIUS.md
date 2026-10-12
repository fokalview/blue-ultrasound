# Clarius integration and full-support definition

Blue prioritizes Clarius; GE is deferred. **No native Clarius adapter is implemented or hardware-verified in this release.** The public SDK source has been inspected and pinned, rather than assuming that importing two libraries gives app parity.

## Routes

| Route | Intended role | Android | Windows | Requirements |
|---|---|---|---|---|
| Solum | Standalone scanning and probe control | Vendor Android integration | Native SDK | Commercial partner, OEM license per probe, certificate, compatible firmware |
| Cast | Companion image streaming and selected controls | Vendor Java interface | Desktop C API | Clarius App connected to probe; same network; compatible versions; feature licensing |
| Local file import | Review previously exported scans | Implemented | Implemented | Blue's supported PNG/JPEG/DICOM subset |

Cloudflare hosts the UI and optional future cloud services. It cannot run the native SDK against a local probe on behalf of the browser. Acquisition belongs on the Android/Windows device. Solum and Cast have overlapping C type names; keep their native wrappers in separate translation units/modules.

## Coverage required before “full support”

Every row below is **pending implementation and physical verification**. The public API indicates possibilities, not support for every probe or workflow.

| Area | SDK surface / acceptance requirement |
|---|---|
| Discovery and transport | Platform BLE permissions, probe power/discovery, Wi-Fi credentials/endpoint, network routing, reconnect and orderly teardown |
| Initialization and authentication | Init/destroy, certificates and expiry, explicit failure states, matched runtime/firmware version |
| Probe/workflow discovery | Enumerate probes/applications; load supported application; display geometry/status |
| Imaging | B, compounding, M, color, power, PW, needle enhancement, strain, RF and element-test enum coverage, gated by actual probe/application availability |
| Parameters | Depth, gain/auto-gain, contrast, chroma, smoothing, penetration, focus, extended FOV, color/PW controls, needle side, strain opacity, research switches; query ranges and report failed commands |
| Geometry | TGC, active region, ROI move/size/maximize, Doppler gate position; preserve calibration and units |
| Frames | Processed/raw/spectral callbacks, requested output size/format, separated overlays, timestamps and IMU samples; bounded queues and copied callback buffers |
| Research | Raw availability/request/read/progress, frozen-state requirements, RF/IQ metadata, IMU streaming and calibration |
| Status and safety | Imaging/power/error/button events, acoustic indices, stale frames, low battery/heat/poor Wi-Fi handling; never infer live state from a successful request alone |
| Maintenance | Firmware progress/results, probe settings, Wi-Fi optimization, reset, 5V control, TEE information and battery health where supported; explicit user-driven operations |
| Low-level research | Parameter/pulse controls in a separately validated research workflow; vendor warns they may operate outside tested limits |
| Blue functionality | Study capture, calibrated measurements, cine timing, DICOM export/reporting, optional cloud synchronization; these are not supplied by Solum |

The machine-readable [SDK inventory](clarius-sdk-inventory.json) lists every exported C function found in the pinned headers with its current Blue implementation status. It is a source inventory, **not generated bindings, a runtime adapter, or an Android Java parity claim**. It does not enumerate every Java method, enum, callback or struct.

## Reproduce the SDK audit

Run `node scripts/clarius-inventory.mjs --check` from the repository root. It fetches only the two pinned public headers and compares them with the checked-in inventory. Without `--check`, it regenerates the inventory. No credentials, SDK binaries or probe traffic are involved. `--local` uses the ignored developer clones under `.tools` instead.

Pinned source revisions:

- Solum: `6d5c55fe49076e36eae3f63fa0dcf2d38dc4b328`; header definitions identify version 12.2.4.
- Cast: `559717022388e2975e3e2826642d97879daa14a3`.

For runtime implementation, acquire platform release packages from Clarius, inspect their terms and pin release tags, archive hashes and ABI versions together. Public repository licensing does not substitute for probe licensing. Do not commit OEM keys, certificates, private firmware or unreviewed runtime archives.

## Native implementation sequence

1. Confirm exact model, firmware, OEM/Cast entitlement and intended workflow with the owner. Run the matching vendor sample against the probe on each target OS.
2. Build separate Solum/Cast platform wrappers. Android uses the documented vendor Android interface; Windows uses the matching C header/runtime pair. Keep acquisition and callbacks off the Flutter UI thread.
3. Implement a connection state machine: disconnected → initializing → connecting → certificate/firmware check → ready → imaging/frozen. Errors, expiry, transport loss and power-down invalidate acquisition. Never auto-upgrade firmware or reset a probe during connection.
4. Copy callback-owned buffers before returning. Bound frame queues, preserve color/spectral/raw representations and original timing. The existing grayscale demo frame model must be extended before receiving color or raw SDK data.
5. Expose typed commands and per-probe capability/range queries. Test unsupported commands, malformed frames, timeout, reconnection, lifecycle backgrounding and stale capture prevention with an SDK test double.
6. Verify each inventory item on actual Android and Windows hardware. Record model, firmware, runtime, license, expected/actual behavior and evidence. Mark unavailable capabilities with a reason. Complete medical-software validation appropriate to intended use before clinical use.

## Authoritative references

- [Solum prerequisites and scope](https://github.com/clariusdev/solum)
- [Solum lifecycle](https://github.com/clariusdev/solum/blob/6d5c55fe49076e36eae3f63fa0dcf2d38dc4b328/docs/getting-started.md)
- [Solum modes, parameters and low-level warnings](https://github.com/clariusdev/solum/blob/6d5c55fe49076e36eae3f63fa0dcf2d38dc4b328/include/solum/solum_def.h)
- [Cast constraints and licensing](https://github.com/clariusdev/cast)
- [Solum Android example](https://github.com/clariusdev/solum/tree/6d5c55fe49076e36eae3f63fa0dcf2d38dc4b328/examples/solum_android)
