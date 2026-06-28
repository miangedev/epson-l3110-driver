# architecture.md

System Architecture — epson-l3110-driver  
Status: Phase 0 — draft, subject to revision

---

## Overview

The driver is structured as a CUPS filter written in C. It receives print data from CUPS in
standard CUPS Raster format, converts it to ESC/P-R commands, and sends those commands to
the printer over USB.

The implementation is divided into four independent modules plus a logging utility. Each
module has a single responsibility and communicates only with adjacent layers.

---

## Layer Diagram

```
┌─────────────────────────────────┐
│         CUPS filter             │  entry point invoked by CUPS
│         filter.c                │  reads stdin, coordinates modules
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│       Protocol layer            │  builds ESC/P-R packets
│       escpr.c / escpr.h         │  init sequence, job commands, page end
└──────┬─────────────┬────────────┘
       │             │
       ▼             ▼
┌────────────┐  ┌───────────────────┐
│ Image layer│  │    USB layer      │
│ raster.c   │  │    usb.c / usb.h  │
│ raster.h   │  │                   │
└────────────┘  └───────────────────┘
```

Data flows top to bottom. No module calls upward into a higher layer.

---

## Modules

### filter.c — CUPS entry point

Invoked by CUPS as:

```
epson-l3110-filter job user title copies options [filename]
```

Responsibilities:
- Parse CUPS job arguments (copies, PPD options).
- Open the CUPS Raster stream from stdin.
- Read the raster header to determine page dimensions, resolution, and color space.
- Read pixel data line by line using cupsRasterReadPixels().
- Coordinate raster.c and escpr.c to process each page.
- Handle SIGTERM for job cancellation.
- Report errors to stderr (captured by CUPS into error_log).

Does not know about USB or ESC/P-R packet structure.

---

### escpr.c / escpr.h — ESC/P-R protocol layer

Responsibilities:
- Build the ESC/P-R mode entry sequence.
- Build job configuration commands (paper size, media type, print quality, color mode).
- Wrap compressed raster data into ESC/P-R packets.
- Build the end-of-job sequence.
- Call usb.c to transmit each packet.

Does not know about pixel formats, CUPS Raster headers, or libusb internals.

Public interface (escpr.h):

```c
int  escpr_init(usb_device_t *dev);
int  escpr_begin_job(usb_device_t *dev, const job_params_t *params);
int  escpr_send_raster_line(usb_device_t *dev, const uint8_t *data, size_t len);
int  escpr_end_job(usb_device_t *dev);
void escpr_cleanup(usb_device_t *dev);
```

These signatures are preliminary and will be revised during Phase 3.

---

### raster.c / raster.h — Image processing layer

Responsibilities:
- Receive a line of raw pixels from the CUPS Raster stream.
- Convert color space if necessary (CUPS Raster may deliver sRGB; printer may expect a
  different format — confirmed during Phase 4).
- Apply Run Length Encoding (RLE) compression to the pixel data.
- Return a compressed buffer ready to be passed to escpr.c.

Does not know about USB, ESC/P-R, or CUPS.

Public interface (raster.h):

```c
int raster_compress_line(const uint8_t *input, size_t input_len,
                          uint8_t *output, size_t *output_len);
```

---

### usb.c / usb.h — USB communication layer

Responsibilities:
- Locate the Epson L3110 by VID (0x04b8) and PID (0x1142).
- Open the device using libusb.
- Claim Interface 1 (Printer class, bidirectional).
- Send data to EP 4 OUT (bulk transfer).
- Receive data from EP 3 IN (bulk transfer).
- Release the interface and close the device on cleanup.

Does not know about ESC/P-R, pixel data, or CUPS.

Public interface (usb.h):

```c
typedef struct usb_device usb_device_t;

usb_device_t *usb_open_printer(void);
int           usb_send(usb_device_t *dev, const uint8_t *data, size_t len);
int           usb_recv(usb_device_t *dev, uint8_t *buf, size_t len, int *actual);
void          usb_close_printer(usb_device_t *dev);
```

The struct definition is private to usb.c. Callers only hold an opaque pointer.

---

### log.c / log.h — Logging utility

Responsibilities:
- Provide leveled logging (DEBUG, INFO, WARN, ERROR).
- Write to stderr. CUPS captures stderr from filter processes and appends it to
  /var/log/cups/error_log.
- Include the source module name and line number in each log entry.

Public interface (log.h):

```c
typedef enum { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR } log_level_t;

void log_msg(log_level_t level, const char *file, int line, const char *fmt, ...);

#define LOG_DEBUG(fmt, ...) log_msg(LOG_DEBUG, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  log_msg(LOG_INFO,  __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...)  log_msg(LOG_WARN,  __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_ERROR(fmt, ...) log_msg(LOG_ERROR, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
```

---

## Repository Layout

```
epson-l3110-driver/
├── README.md
├── LICENSE
├── Makefile
├── docs/
│   ├── architecture.md     (this file)
│   ├── protocol-notes.md
│   ├── research-notes.md
│   └── decisions.md
└── src/
    ├── filter.c
    ├── escpr.c
    ├── escpr.h
    ├── raster.c
    ├── raster.h
    ├── usb.c
    ├── usb.h
    ├── log.c
    └── log.h
```

---

## Key Design Decisions

### Filter only, no custom backend (Phase 0-6)

The CUPS generic USB backend (/usr/lib/cups/backend/usb) handles transmission to the
printer. We write only the filter.

Rationale: the generic backend handles bulk USB transfers correctly for printer class
devices. A custom backend adds implementation cost without immediate benefit. It will be
reconsidered in Phase 6 once the protocol is working and we can identify specific
limitations of the generic backend.

See decisions.md entry 001.

### Opaque USB handle

usb_device_t is defined only inside usb.c. All other modules hold a pointer to it but
cannot access its fields directly. This isolates libusb types from the rest of the codebase.
Replacing libusb with a different transport (e.g., writing directly to /dev/usb/lpN) requires
changes only in usb.c.

### No global state

Each module operates on data passed through function arguments. No global variables except
compile-time constants. This makes the code easier to test and reason about.

### Error handling convention

All public functions return int. Zero means success. Negative values mean failure. The
specific negative value identifies the error type. Callers must check every return value.
Errors are propagated upward; no silent failures.

---

## What This Architecture Does Not Cover Yet

- PPD file format and contents (Phase 6).
- Color management beyond basic RGB (Phase 5).
- Multi-page job handling details (Phase 4).
- Printer status polling (Phase 3).
- Custom CUPS backend (Phase 6, optional).