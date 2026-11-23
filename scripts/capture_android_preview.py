"""Capture the foreground .preview app with Android's native system bars.

Uses the official SystemUI demo protocol only during capture, then restores
the device's demo setting. Does not edit pixels or clear notifications.
"""
import argparse
import os
import struct
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--adb", type=Path, default=Path(os.environ["LOCALAPPDATA"]) /
                        "Android/Sdk/platform-tools/adb.exe")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    adb = [str(args.adb), "-s", args.device]

    def shell(*command: str) -> str:
        return subprocess.check_output(adb + ["shell", *command], encoding="utf-8")

    focus = shell("dumpsys", "window")
    if not any("cn.edu.xmu.rollcall.xmu_rollcall.preview/" in line
               for line in focus.splitlines() if "mCurrentFocus=" in line):
        raise SystemExit("The dedicated preview app must be in the foreground.")
    allowed = shell("settings", "get", "global", "sysui_demo_allowed").strip()
    active = shell("settings", "get", "global", "sysui_tuner_demo_on").strip()
    if active == "1":
        raise SystemExit("Exit the device's existing demo session before capture.")

    def demo(command: str, *extras: str) -> None:
        shell("am", "broadcast", "-a", "com.android.systemui.demo",
              "-e", "command", command, *extras)

    try:
        shell("settings", "put", "global", "sysui_demo_allowed", "1")
        demo("enter")
        demo("clock", "-e", "hhmm", "0941")
        demo("notifications", "-e", "visible", "false")
        demo("battery", "-e", "level", "100", "-e", "plugged", "false")
        demo("network", "-e", "wifi", "show", "-e", "level", "4",
             "-e", "fully", "true")
        demo("status", "-e", "volume", "hide", "-e", "alarm", "hide",
             "-e", "bluetooth", "hide", "-e", "location", "hide")
        # Read back the demo state before asking Android for the display image.
        shell("settings", "get", "global", "sysui_tuner_demo_on")
        png = subprocess.check_output(adb + ["exec-out", "screencap", "-p"])
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("ADB did not return a PNG screenshot.")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(png)
        print(f"Captured {args.output}: {struct.unpack('>II', png[16:24])}")
    finally:
        demo("exit")
        for key, value in (("sysui_demo_allowed", allowed),
                           ("sysui_tuner_demo_on", active)):
            if value == "null":
                shell("settings", "delete", "global", key)
            else:
                shell("settings", "put", "global", key, value)


if __name__ == "__main__":
    main()
