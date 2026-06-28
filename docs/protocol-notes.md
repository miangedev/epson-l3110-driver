# protocol-notes.md

Protocol Notes — ESC/P-R  
Project: epson-l3110-driver  
Status: Phase 0 — incomplete, updated as evidence is gathered

---

## 1. Protocol Family

The Epson L3110 uses ESC/P-R (Epson Standard Code for Printers — Raster), the third
generation of Epson's print protocol family.

| Protocol | Era | Target hardware |
|----------|-----|-----------------|
| ESC/P | 1980s | Dot matrix printers |
| ESC/P2 | 1990s | Early inkjet printers; supported by Gutenprint |
| ESC/P-R | 2000s–present | Modern inkjet printers including EcoTank series |

ESC/P-R is not fully documented publicly. The ESC/P-2 Reference Manual (Epson, 1997)
covers the earlier protocol. ESC/P-R extends it with a packet-based structure for raster
data and a remote configuration mode. Some commands must be inferred from source code
analysis and USB traffic captures.

---

## 2. Command Structure

Every ESC/P-R command follows this structure:

```
[ ESC ] [ cmd ] [ length: 4 bytes LE ] [ code ] [ data: length bytes ]
  0x1B    1B           4B                  1B         variable
```

Length is the number of bytes in the data field, encoded as a 32-bit unsigned integer
in little-endian byte order.

Source: analysis of epson-escpr-api.c (mrnuke/epson-printer-escpr-improved) and
python-epson (ezrec/python-epson).

---

## 3. Known Command Sequences

### 3.1 Enter ESC/P-R mode

Must be sent before any other ESC/P-R command.

```
Bytes: 1B 28 52 06 00 00 00 45 53 43 50 52
ASCII:  ESC (  R  .  .  .  .  E  S  C  P  R
```

Breakdown:
- `1B` — ESC
- `28` — command `(`
- `52` — subcommand `R` (select remote mode)
- `06 00 00 00` — data length: 6 bytes (little-endian uint32)
- `00` — padding byte
- `45 53 43 50 52` — ASCII string "ESCPR"

### 3.2 Enter REMOTE mode

Used for printer configuration before beginning a print job.

```
Bytes: 1B 28 52 08 00 00 00 52 45 4D 4F 54 45 31
ASCII:  ESC (  R  .  .  .  .  R  E  M  O  T  E  1
```

- Data length: 8 bytes
- Payload: "REMOTE1" (7 bytes) + 1 padding byte

### 3.3 ESC/P-R JPEG mode (alternative)

Not used initially. Documents that the printer supports a JPEG data path in addition
to raw raster.

```
Bytes: 1B 28 52 07 00 00 00 45 53 43 50 52 4A
ASCII:  ESC (  R  .  .  .  .  E  S  C  P  R  J
```

---

## 4. Raster Data Compression

The driver uses Run Length Encoding (RLE) to compress raster lines before packetizing.

RLE format (Epson variant):
- A repeat byte N followed by a data byte D means: repeat D for (N+1) times.
- A literal byte N followed by (N+1) raw bytes means: copy those bytes as-is.

Maximum packet size for raster data: 4096 bytes (ESCPR_PACKET_SIZE_4KB).

If a compressed raster line exceeds 4096 bytes, it is split into multiple packets.

Source: epson-escpr-api.c, function RunLengthEncode.

---

## 5. IEEE 1284 Device ID

The printer exposes an IEEE 1284 Device ID string readable via a USB class control
transfer:

```
bmRequestType: 0xA1  (Device-to-Host | Class | Interface)
bRequest:      0x00  (GET_DEVICE_ID)
wValue:        0x0000
wIndex:        0x0001  (Interface 1 — Printer)
wLength:       1024
```

Expected format:

```
MFG:EPSON;CMD:ESCPL2,BDC,ESCPR7,...;MDL:L3110 Series;CLS:PRINTER;...
```

The CMD field will confirm the exact ESC/P-R version. Not yet read from this device.
Pending: Phase 2.

---

## 6. Print Job Sequence (Inferred)

Based on source code analysis. Not yet verified against actual USB traffic.

```
1. Send ESC/P-R mode entry sequence
2. Send REMOTE mode entry sequence
3. Send job configuration commands:
   - Paper size
   - Media type
   - Print quality
   - Color mode
   - Resolution
4. For each page:
   a. Send page start command
   b. For each raster line:
      - Compress line with RLE
      - Split into <=4096 byte packets if necessary
      - Send each packet with ESC/P-R raster command
   c. Send page end command
5. Send job end sequence
6. Send ESC/P-R exit sequence
```

---

## 7. Resolution

The official Epson driver (epson-inkjet-printer-escpr) is documented by OpenPrinting as
supporting only 360 dpi. The L3110 hardware is capable of higher resolutions (up to
5760x1440 dpi according to Epson specifications). Whether higher resolutions are
accessible via ESC/P-R commands requires USB traffic analysis.

---

## 8. Pending / Unknown

- Exact byte sequences for job configuration commands (paper size, media type, quality).
- Exact byte sequence for page start and page end.
- Exact byte sequence for ESC/P-R exit.
- Whether status polling uses EP 3 IN or a separate mechanism.
- How the printer signals ready, busy, out-of-paper, and error states.
- Whether higher resolutions require different command variants.

All of the above will be populated during USB traffic capture in Phase 0 (final step)
and refined during Phase 3.

---

## 9. Sources

- mrnuke/epson-printer-escpr-improved — epson-escpr-api.c: packet structure, RLE, init sequences.
- ezrec/python-epson — escpr.py: clean reimplementation confirming command structure.
- Epson ESC/P-2 Reference Manual (1997): https://files.support.epson.com/pdf/general/escp2ref.pdf
- USB Printer Class Definition (USB-IF): GET_DEVICE_ID control transfer.