"""Download this app's training files through the paired USB iPhone."""

import argparse
import asyncio
from datetime import datetime
from pathlib import Path
import plistlib

from pymobiledevice3.services.house_arrest import HouseArrestService
from watch_connection import WatchConnection


async def export(args):
    info = plistlib.loads((args.app / "Info.plist").read_bytes())
    destination = args.state / "exports" / datetime.now().strftime("%Y%m%d-%H%M%S")
    async with WatchConnection(args.state) as watch:
        async with await HouseArrestService.create(watch, info["CFBundleIdentifier"]) as files:
            destination.mkdir(parents=True, exist_ok=False)
            await files.pull("/Documents/Workouts", str(destination), progress_bar=False)
    print(f"Training files downloaded to {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, default=Path(".watchos"))
    parser.add_argument("--app", type=Path, default=Path(".watchos/apps/RopeSkipStandalone.app"))
    args = parser.parse_args()
    try:
        asyncio.run(asyncio.wait_for(export(args), timeout=90))
    except Exception as error:
        print(f"Export failed: {type(error).__name__}: {error}")
        raise SystemExit(1) from None
