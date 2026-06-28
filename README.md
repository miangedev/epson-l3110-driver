# epson-l3110-driver

A native Linux printer driver for the **Epson L3110** written in C, built from scratch without proprietary software, Gutenprint, or any existing driver as a base.

This is a long-term systems programming project. The goal is to understand every layer of the Linux printing stack — USB communication, ESC/P-R protocol, CUPS integration — and implement a clean, auditable, open-source driver.

> **Status: Phase 0 — Research and documentation.**
> No printing yet. If you are here for a working driver, Epson's official Linux packages are at [epson.com](https://www.epson.com). Come back when this notice changes.

---

## Goals

- Communicate with the Epson L3110 over USB using `libusb`.
- Understand and implement the ESC/P-R protocol without relying on reverse-engineered blobs.
- Write a CUPS filter and CUPS backend in C.
- Produce a clean `.deb` package and source tarball.
- Document every technical decision.

This project targets **one printer only**: the Epson L3110. No other models will be added unless they are confirmed to share the exact same protocol implementation.

---

## What this is not

- Not a wrapper around Epson's `iscan` or `escpr` packages.
- Not a fork of Gutenprint.
- Not a quick fix. This is a learning-driven engineering project.

---

## Roadmap

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Research: USB, ESC/P-R, CUPS, existing projects | Complete |
| 1 | Repository structure, Makefile, coding conventions | In progress |
| 2 | USB device detection and descriptor inspection | Pending |
| 3 | USB communication: open, claim, send, receive | Pending |
| 4 | Print a test page | Pending |
| 5 | Image processing: PNG, raster, color | Pending |
| 6 | CUPS filter and backend | Pending |
| 7 | Packaging: .deb, tarball, PKGBUILD | Pending |

---

## Documentation

Research notes and architectural decisions are kept in the `docs/` directory as the project progresses:

- `docs/architecture.md` — system design and module responsibilities
- `docs/protocol-notes.md` — ESC/P-R command analysis
- `docs/research-notes.md` — notes on USB, CUPS, and existing open-source projects
- `docs/decisions.md` — record of every significant design decision and its justification

---

## Dependencies

| Library | Purpose |
|---------|---------|
| `libusb-1.0` | USB device communication |
| `libcups` | CUPS filter and backend integration |

No other runtime dependencies are planned. Additional libraries will only be introduced with documented justification.

---

## Contributing

Contributions are welcome, but this project is in early research. Before opening a pull request:

1. Read the open issues and existing docs.
2. Open an issue to discuss what you want to change.
3. Keep patches focused and small.
4. Write in C. No C++, Rust, or Python unless there is a documented exceptional reason.
5. Document your reasoning, not just your code.

If you have experience with ESC/P-R, USB printer protocols, or CUPS internals, your input in the issues section is especially valuable even without code.

---

## License

GPL v3.0. See `LICENSE`.

---

## References

- [OpenPrinting](https://openprinting.github.io/)
- [CUPS documentation](https://www.cups.org/doc/)
- [libusb](https://libusb.info/)
- [Epson ESC/P Reference Manual](https://files.support.epson.com/pdf/general/escp2ref.pdf)
- [Gutenprint](https://gimp-print.sourceforge.net/) — studied for protocol insight, not used as a base
