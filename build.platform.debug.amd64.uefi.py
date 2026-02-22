import os
import subprocess
import sys
import shutil

def run(cmd: list[str]) -> None:
    print(">", " ".join(cmd))
    subprocess.check_call(cmd)

def main() -> int:
    # Resolve project root as the folder containing this script
    proj_dir = os.path.dirname(os.path.abspath(__file__))

     # ----------------------------
    # CLEAN (delete previous build)
    # ----------------------------
    build_dir = os.path.join(proj_dir, "build")
    if os.path.isdir(build_dir):
        print("Cleaning:", build_dir)
        shutil.rmtree(build_dir)

    # ----------------------------
    # 0) Build kernel first
    # ----------------------------
    projects_dir = os.path.abspath(os.path.join(proj_dir, "..", ".."))

    kernel_proj_dir = os.path.join(projects_dir, "systems", "el_kernel_system")
    kernel_build_py = os.path.join(kernel_proj_dir, "build.debug.amd64.py")

    if not os.path.isfile(kernel_build_py):
        raise FileNotFoundError(f"Kernel build script not found: {kernel_build_py}")

    run([sys.executable, kernel_build_py])

    kernel_bin = os.path.join(kernel_proj_dir, "build", "debug", "amd64", "kernel.bin")
    if not os.path.isfile(kernel_bin):
        raise FileNotFoundError(f"Kernel binary not found after build: {kernel_bin}")

    # ----------------------------
    # 1) Build bootloader EFI
    # ----------------------------
    src_asm = os.path.join(proj_dir, "src", "main.asm")

    obj_dir = os.path.join(proj_dir, "build", "obj")
    os.makedirs(obj_dir, exist_ok=True)

    out_obj = os.path.join(obj_dir, "main.obj")

    # Assemble: NASM source -> COFF object (win64)
    run(["nasm", "-f", "win64", src_asm, "-o", out_obj])
    print("Successfully Built:", out_obj)

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

    # ----------------------------
    # 2) Copy kernel.bin into ESP root
    # ----------------------------
    esp_root = os.path.abspath(os.path.join(efi_dir, "..", "..", ".."))
    dst_kernel_bin = os.path.join(esp_root, "esp", "kernel.bin")

    shutil.copy2(kernel_bin, dst_kernel_bin)
    print("Copied kernel:", dst_kernel_bin)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())