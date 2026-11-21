#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

def run_cmd(cmd, cwd="."):
    print(f"\n> {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    return result.returncode == 0

def _sync_override(data, pkg, target, is_direct):
    overrides = data.setdefault("overrides", {})
    if not is_direct:
        overrides[pkg] = f"^{target}"
    elif pkg in overrides:
        overrides[pkg] = target

def update_package_json(pkg, target):
    pkg_path = Path("frontend/package.json")
    with open(pkg_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    replaced = False
    for section in ["dependencies", "devDependencies"]:
        if section in data and pkg in data[section]:
            data[section][pkg] = target
            replaced = True
            
    _sync_override(data, pkg, target, replaced)
        
    with open(pkg_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def resolve_queue_path() -> Path:
    candidates = [
        Path("reports/dependabot-vapt/agent-queue.json"),
        Path("reports/dependabot/agent-queue.json"),
    ]
    for p in candidates:
        if p.exists():
            return p
    print("Queue file not found. Exiting.")
    sys.exit(1)

def get_npm_groups(queue):
    # We want to skip packages we already processed or know about.
    # Note: Modify this set based on what has already been fixed.
    processed_pkgs = {
        'vitest', 'tar', 'hono', '@hono/node-server', 
        'immutable', 'express-rate-limit', 'undici', 
        '@angular/core', '@angular/compiler'
    }
    groups = []
    seen_pkgs = set(processed_pkgs)
    for item in queue:
        if item.get("ecosystem") != "npm":
            continue
        pkg = item.get("package")
        if pkg in seen_pkgs:
            continue
        seen_pkgs.add(pkg)
        groups.append({
            "alert": item.get("alert_number"),
            "closes": item.get("closes_alerts", []),
            "pkg": pkg,
            "target": item.get("target_version")
        })
    return groups

def process_package_fix(g):
    pkg = g["pkg"]
    target = g["target"]
    print(f"\n=== Processing {pkg} -> {target} ===")
    
    update_package_json(pkg, target)
    
    # Install
    if not run_cmd("npm install", cwd="frontend"):
        print(f"Skipping {pkg} due to install failure.")
        run_cmd("git checkout package.json", cwd="frontend")
        return False
        
    # Build and Test
    if not run_cmd("npm run build && npm test -- --watch=false", cwd="frontend"):
        print(f"Skipping {pkg} due to test/build failure.")
        run_cmd("git checkout package.json package-lock.json", cwd="frontend")
        return False
        
    # Commit
    closes_list = ", ".join(f"#{a}" for a in g["closes"])
    msg = f"fix(deps): bump {pkg} to {target}\n\nCloses dependabot alert {closes_list}"
    
    run_cmd(f'git add package.json package-lock.json && git commit -m "{msg}"', cwd="frontend")
    
    # Log
    log_line = f"- #{g['alert']} {pkg} -> {target} — fixed, branch vapt-fix, verified"
    print(f"[LOG] {log_line}")
    print(f"SUCCESS: {pkg}")
    return True

def main():
    queue_path = resolve_queue_path()
    with open(queue_path, "r", encoding="utf-8") as f:
        queue = json.load(f)

    groups = get_npm_groups(queue)
    for g in groups:
        process_package_fix(g)

if __name__ == "__main__":
    main()
