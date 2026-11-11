from pathlib import Path
import zipfile,hashlib,json
root=Path(__file__).resolve().parent.parent
files=['.gitignore','README.md','PRODUCT.md','THIRD_PARTY.md','RELEASE_REVIEW.md','RELEASE_NOTES.md','VALIDATION.md','build.sh',
       'Sources/main.swift','Resources/GenerateIcon.swift','scripts/generate-icon.sh','scripts/review-package.sh','scripts/source-package.py']
files += ['PERFORMANCE.md'] + [str(p.relative_to(root)) for p in sorted((root/'docs/images').glob('*.png'))]
if (root/'LICENSE').is_file():files.append('LICENSE')
records=[]
with zipfile.ZipFile(root/'dist/AI-Dock-source-review.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for name in files:
  data=(root/name).read_bytes()
  # No machine-specific home paths or personal bundle IDs in the review source.
  assert (b'/' + b'Users' + b'/') not in data, f'Private path/identifier in {name}'
  archive.writestr('ai-dock/'+name,data)
  records.append({'file':name,'sha256':hashlib.sha256(data).hexdigest()})
(root/'dist/SOURCE_MANIFEST.json').write_text(json.dumps(records,indent=2)+'\n')
print(f'Packaged {len(records)} allowlisted source files; no development branding or account data included.')
