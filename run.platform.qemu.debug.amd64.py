# projects/platform/el_boot_platform/build.platform.debug.qemu.amd64.uefi.py
#
# Build + run an AMD64 UEFI bootloader (NASM) using QEMU + OVMF.
#
# Inputs:
#   projects/platform/el_boot_platform/src/main.asm
#
# Outputs:
#   projects/platform/el_boot_platform/build/main.obj
#   projects/platform/el_boot_platform/build/debug/amd64_uefi/esp/EFI/BOOT/BOOTX64.EFI
#
# Requirements (must be on PATH via your DevKit env):
#   nasm
#   lld-link
#   qemu-system-x86_64
#
# Firmware (your absolute paths):
#   F:\DEV\devkit\qemu\OVMF_CODE.fd
#   F:\DEV\devkit\qemu\OVMF_VARS.fd
#
# Run:
#   python build.platform.debug.qemu.amd64.uefi.py

from __future__ import annotations

import subprocess
from pathlib import Path


def run(cmd: list[str]) -> None:
    # Prints the command and then executes it. If it fails, Python raises an error immediately.
    print("> " + " ".join(cmd))
    subprocess.check_call(cmd)


def main() -> int:
    # The project directory is the folder containing this script:
    # .../projects/platform/el_boot_platform/
    proj_dir = Path(__file__).resolve().parent

    # ---- Input source ----
    src_asm = proj_dir / "src" / "main.asm"
    if not src_asm.is_file():
        raise FileNotFoundError(f"Missing source file: {src_asm}")

    # ---- Build outputs ----
    # Intermediate object file
    out_obj = proj_dir / "build" / "main.obj"
    out_obj.parent.mkdir(parents=True, exist_ok=True)

    # UEFI “bundle” root for this configuration
    bundle_root = proj_dir / "build" / "debug" / "amd64_uefi"

    # ESP (EFI System Partition) folder that QEMU will expose as a FAT drive
    esp_dir = bundle_root / "esp"

    # UEFI fallback boot path: \EFI\BOOT\BOOTX64.EFI
    boot_dir = esp_dir / "EFI" / "BOOT"
    boot_dir.mkdir(parents=True, exist_ok=True)

    out_efi = boot_dir / "BOOTX64.EFI"

    # ---- OVMF firmware (absolute paths as requested) ----
    ovmf_code = r"F:\DEV\devkit\qemu\OVMF_CODE.fd"
    ovmf_vars = r"F:\DEV\devkit\qemu\OVMF_VARS.fd"

    # ---- Assemble: main.asm -> main.obj ----
    # -f win64 outputs a COFF object file that lld-link can link into a PE32+ .EFI.
    run(["nasm", "-f", "win64", str(src_asm), "-o", str(out_obj)])

    # ---- Link: main.obj -> BOOTX64.EFI ----
    run([
        "lld-link",
        "/subsystem:efi_application",
        "/entry:efi_main",
        "/nodefaultlib",
        "/machine:x64",
        "/out:" + str(out_efi),
        str(out_obj),
    ])

    # ---- Run in QEMU ----
    # QEMU exposes esp_dir as a FAT drive via the "fat:rw:" pseudo-backend.
    run([
        "qemu-system-x86_64",
        "-machine", "q35",
        "-m", "512",
        "-drive", f"if=pflash,format=raw,readonly=on,file={ovmf_code}",
        "-drive", f"if=pflash,format=raw,file={ovmf_vars}",
        "-drive", f"file=fat:rw:{esp_dir},format=raw",
        "-net", "none",
    ])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())