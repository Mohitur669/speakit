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

def update_package_json(pkg, target):
    pkg_path = Path("frontend/package.json")
    with open(pkg_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    replaced = False
    
    # Try updating in dependencies or devDependencies
    for section in ["dependencies", "devDependencies"]:
        if section in data and pkg in data[section]:
            data[section][pkg] = target
            replaced = True
            
    # If not a direct dependency, add/update in overrides.
    # Alternatively, if it IS a direct dependency but an override already exists,
    # we must update the override as well to prevent NPM EOVERRIDE conflicts.
    if not replaced:
        if "overrides" not in data:
            data["overrides"] = {}
        data["overrides"][pkg] = f"^{target}"
    else:
        if "overrides" in data and pkg in data["overrides"]:
            data["overrides"][pkg] = target
        
    with open(pkg_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def main():
    queue_path = Path("reports/dependabot/agent-queue.json")
    if not queue_path.exists():
        print("Queue file not found. Exiting.")
        sys.exit(1)
        
    with open(queue_path, "r", encoding="utf-8") as f:
        queue = json.load(f)

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

    for g in groups:
        pkg = g["pkg"]
        target = g["target"]
        print(f"\n=== Processing {pkg} -> {target} ===")
        
        update_package_json(pkg, target)
        
        # Install
        if not run_cmd("npm install", cwd="frontend"):
            print(f"Skipping {pkg} due to install failure.")
            run_cmd("git checkout package.json", cwd="frontend")
            continue
            
        # Build and Test
        if not run_cmd("npm run build && npm test -- --watch=false", cwd="frontend"):
            print(f"Skipping {pkg} due to test/build failure.")
            run_cmd("git checkout package.json package-lock.json", cwd="frontend")
            continue
            
        # Commit
        closes_list = ", ".join(f"#{a}" for a in g["closes"])
        msg = f"fix(deps): bump {pkg} to {target}\n\nCloses dependabot alert {closes_list}"
        
        run_cmd(f"git add package.json package-lock.json && git commit -m \"{msg}\"", cwd="frontend")
        
        # Log
        log_line = f"- #{g['alert']} {pkg} -> {target} — fixed, branch vapt-fix, verified\n"
        with open("reports/dependabot/fix-log.md", "a", encoding="utf-8") as f:
            f.write(log_line)
            
        print(f"SUCCESS: {pkg}")

if __name__ == "__main__":
    main()
