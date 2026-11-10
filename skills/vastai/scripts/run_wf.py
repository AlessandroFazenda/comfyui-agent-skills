# Sends a workflow (API format) to the instance's local ComfyUI and waits for the result.
# Usage: python run_wf.py wf.json
import json, sys, time, urllib.request
wf = json.load(open(sys.argv[1])); U = "http://127.0.0.1:8188"
r = json.load(urllib.request.urlopen(urllib.request.Request(U + "/prompt", json.dumps({"prompt": wf}).encode(), {"Content-Type": "application/json"})))
pid = r["prompt_id"]; t = time.time(); print("prompt_id", pid, flush=True)
while True:
    h = json.load(urllib.request.urlopen(f"{U}/history/{pid}"))
    if pid in h:
        st = h[pid]["status"]; print("status", st.get("status_str"), f"{time.time()-t:.0f}s")
        for m in st.get("messages", []):
            if m[0] == "execution_error": print(json.dumps(m[1])[:2000])
        for node, o in h[pid]["outputs"].items():
            for k in ("images", "videos", "gifs", "audio"):
                for f in o.get(k, []): print("output", f.get("subfolder", ""), f["filename"])
        break
    time.sleep(5)
