# decisions.md

Architectural Decision Log — epson-l3110-driver  
Format: ID | Date | Decision | Rationale | Alternatives considered

---

## 001 — Filter only, no custom backend (Phase 0-6)

**Date:** Phase 0  
**Decision:** Implement only a CUPS filter. Use the CUPS generic USB backend for
transmission.

**Rationale:** The generic CUPS USB backend (/usr/lib/cups/backend/usb) performs bulk
transfers correctly for USB Printer Class devices (Class 7, Protocol 2), which the L3110
is. Writing a custom backend requires understanding the CUPS backend protocol on top of
the printer protocol, adding scope without immediate benefit. The filter is where all the
interesting protocol work happens.

**Alternatives considered:**
- Custom backend from the start: rejected. More scope, no benefit until the protocol is
  understood.
- Direct write to /dev/usb/lpN: rejected. Bypasses CUPS entirely; loses job management,
  logging, and cancellation support.

**Revisit trigger:** If the generic backend causes observable problems (incorrect USB
transfers, missing status reads, timing issues) during Phase 3 or 4.

---

## 002 — libusb-1.0 for USB communication

**Date:** Phase 0  
**Decision:** Use libusb-1.0 for all USB device access in usb.c.

**Rationale:** libusb-1.0 is the standard userspace USB library on Linux. It provides a
stable, well-documented API for opening devices, claiming interfaces, and performing bulk
transfers without kernel driver involvement (using the usbfs kernel interface underneath).
It is available in all major distributions and has been maintained continuously since 2007.

**Alternatives considered:**
- Direct ioctl on /dev/bus/usb/NNN/NNN: equivalent to what libusb does internally, but
  requires writing and maintaining the ioctl layer ourselves. No benefit.
- Writing a kernel driver (kernel module): correct long-term approach for a production
  driver, but requires kernel development knowledge outside our current scope. Ruled out
  for educational phases.
- /dev/usb/lpN via the usblp kernel module: simpler but offers no control over interface
  selection, endpoint choice, or error handling. The generic CUPS backend already uses
  this path.

**Revisit trigger:** If a kernel module becomes a project goal in a later phase.

---

## 003 — C99 as the language standard

**Date:** Phase 0  
**Decision:** Compile with -std=c99 and treat warnings as errors (-Wall -Wextra -Werror).

**Rationale:** C99 provides stdint.h (fixed-width integer types: uint8_t, uint32_t, etc.),
stdbool.h, and designated initializers. These are essential for working with binary
protocols where exact byte widths matter. C89 lacks these. C11 adds little that we need
and reduces compiler compatibility. C99 is the pragmatic choice.

**Alternatives considered:**
- C89: lacks stdint.h. Would require manual typedef definitions for fixed-width types.
  Rejected.
- C11: minimal benefit over C99 for this project. Not rejected outright; can be revisited.
- GNU extensions (-std=gnu99): avoided. We want portable, standard C.

---

## 004 — No global mutable state

**Date:** Phase 0  
**Decision:** All module functions operate on data passed as arguments. No global variables
except compile-time constants (#define or const at file scope).

**Rationale:** Global state makes code hard to reason about, hard to test, and introduces
subtle bugs when execution order changes. A printer driver processes one job at a time,
so there is no benefit to global state that would not be better served by a job context
struct passed through the call chain.

**Alternatives considered:**
- Single global printer context struct: tempting for simplicity, but creates hidden
  coupling between modules. Rejected.