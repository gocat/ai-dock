#!/usr/bin/env python3
"""Render bilingual example showcases using current native views; no live data."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Sources/main.swift').read_text().split('if CommandLine.arguments.contains("--self-test")')[0]
with tempfile.TemporaryDirectory(prefix='aidock-showcase-') as directory:
    temp=Path(directory)
    (temp/'main.swift').write_text(source+(root/'Resources/Showcase.swift').read_text())
    subprocess.run(['swiftc','-swift-version','5','-module-cache-path',str(temp/'cache'),'-framework','AppKit',str(temp/'main.swift'),str(root/'Sources/Localization.swift'),'-o',str(temp/'render')],check=True)
    subprocess.run([str(temp/'render')],cwd=root,check=True)
