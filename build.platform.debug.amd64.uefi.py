import os
import subprocess
import sys

def run(cmd: list[str]) -> None:
    print(">", " ".join(cmd))
    subprocess.check_call(cmd)

def main() -> int:
    # Resolve project root as the folder containing this script
    proj_dir = os.path.dirname(os.path.abspath(__file__))

    src_asm = os.path.join(proj_dir, "src", "main.asm")
    out_obj = os.path.join(proj_dir, "build", "main.obj")

    os.makedirs(os.path.dirname(out_obj), exist_ok=True)

    # Assemble: NASM source -> COFF object (win64)
    run(["nasm", "-f", "win64", src_asm, "-o", out_obj])

    print("Successfully Built: ", out_obj)

        # Define output directories for UEFI layout
    efi_dir = os.path.join(
        proj_dir,
        "build",
        "debug",
        "amd64_uefi",
        "esp",
        "EFI",
        "BOOT"
    )

    os.makedirs(efi_dir, exist_ok=True)

    out_efi = os.path.join(efi_dir, "BOOTX64.EFI")

    # Link: COFF object -> PE32+ EFI application
    run([
        "lld-link",
        "/subsystem:efi_application",
        "/entry:efi_main",
        "/nodefaultlib",
        "/machine:x64",
        "/out:" + out_efi,
        out_obj
    ])

    print("Successfully Built:", out_efi)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())