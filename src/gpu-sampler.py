#!/usr/bin/env python3
"""从 PowerVR debugfs 采集 GPU 状态，输出到 /run/a733-monitor/gpu.json（需 root）"""
import json, os, re, sys, time, tempfile

PVR = "/sys/kernel/debug/pvr"
OUT_DIR = "/run/a733-monitor"
OUT = os.path.join(OUT_DIR, "gpu.json")

def rd(p):
    try:
        with open(p) as f:
            return f.read()
    except OSError:
        return ""

def snap():
    st = rd(f"{PVR}/status")
    m = re.search(r"GPU Utilisation:\s+(\d+)%", st)
    blocks = {}
    for k in ("2D", "GEOM", "3D", "CDM", "RAY", "GEOM2"):
        mm = re.search(rf"^\s*{k}:\s+(\d+)%", st, re.M)
        blocks[k.lower()] = int(mm.group(1)) if mm else 0
    drv = "OK" if "Driver Status:   OK" in st else "ERR"
    vram = 0
    mm = re.search(r"^MemoryUsageAllocGPUMemUMA\s+(\d+)", rd(f"{PVR}/driver_stats"), re.M)
    if mm:
        vram = int(mm.group(1)) / 1048576.0
    clk = 0.0
    for ln in rd("/sys/kernel/debug/clk/clk_summary").splitlines():
        f = ln.split()
        if len(f) > 5 and f[0] == "gpu0":
            clk = int(f[4]) / 1e6
            break
    t = rd("/sys/class/thermal/thermal_zone4/temp").strip()
    return dict(util=int(m.group(1)) if (m := re.search(r"GPU Utilisation:\s+(\d+)%", st)) else 0,
                blocks=blocks, status=drv, vram=round(vram), clock=round(clk),
                temp=round(int(t) / 1000.0, 1) if t else 0.0, ts=time.time())

def write_atomic(d):
    os.makedirs(OUT_DIR, exist_ok=True)
    try:
        os.chmod(OUT_DIR, 0o755)
    except OSError:
        pass
    fd, tmp = tempfile.mkstemp(dir=OUT_DIR, prefix=".gpu")
    with os.fdopen(fd, "w") as f:
        json.dump(d, f)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)

def main():
    once = "--once" in sys.argv
    while True:
        try:
            d = snap()
            d["blocks"] = d.pop("blocks")
            flat = dict(d, **d.pop("blocks"))
            if once:
                print(json.dumps(flat, indent=2))
                return
            write_atomic(flat)
        except Exception as e:
            if once:
                print("ERR", e, file=sys.stderr)
                return
        time.sleep(1)

if __name__ == "__main__":
    main()
