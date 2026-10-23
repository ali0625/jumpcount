"""Inspect a log exported by the iPhone app; Python 3, no extra packages needed."""
import argparse
import csv
import math
from pathlib import Path


def analyze(path: Path, expected: int | None = None) -> str:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {"event", "sensor_seconds", "elapsed_seconds", "magnitude_g", "filtered_g", "is_jump", "count", "detail"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError("这不是本 App 导出的日志：缺少必需列。")
        rows = list(reader)
    samples = [row for row in rows if row["event"] == "sample"]
    if not samples:
        return "日志中没有运动样本。请检查手表运动权限和传感器错误记录。"
    timestamps = [float(row["sensor_seconds"]) for row in samples]
    if not all(math.isfinite(t) for t in timestamps):
        raise ValueError("日志包含无效时间戳。")
    intervals = [b - a for a, b in zip(timestamps, timestamps[1:])]
    jumps = sum(row["is_jump"] == "1" for row in samples)
    final_count = int(samples[-1]["count"])
    duration = timestamps[-1] - timestamps[0]
    stops = [row for row in rows if row["event"] == "stop"]
    errors = [row for row in rows if row["event"] == "sensor_error"]
    lines = [
        f"样本数：{len(samples)}",
        f"采集跨度：{duration:.2f} 秒",
        f"平均采样频率：{(len(samples) - 1) / duration:.1f} Hz" if duration > 0 else "平均采样频率：不足以计算",
        f"最后记录次数：{final_count}，跳跃标记数：{jumps}",
        f"超过 0.1 秒的数据间隔：{sum(gap > 0.1 for gap in intervals)} 处",
        f"重复或倒退的时间戳：{sum(gap <= 0 for gap in intervals)} 处",
        f"结束原因：{stops[-1]['detail'] if stops else '没有结束标记，日志可能因中断而不完整'}",
        f"传感器错误记录：{len(errors)} 条",
    ]
    if expected is not None:
        lines.append(f"人工计数：{expected}，差值：{final_count - expected:+d}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="分析跳绳 App 导出的 CSV 日志")
    parser.add_argument("log", type=Path, help="导出的 CSV 文件")
    parser.add_argument("--expected", type=int, help="人工确认的实际跳绳次数")
    args = parser.parse_args()
    if args.expected is not None and args.expected < 0:
        parser.error("人工计数不能为负数")
    try:
        print(analyze(args.log, args.expected))
    except (OSError, ValueError, KeyError, csv.Error) as error:
        parser.exit(1, f"分析失败：{error}\n")


if __name__ == "__main__":
    main()
