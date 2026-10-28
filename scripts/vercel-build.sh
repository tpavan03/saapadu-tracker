#!/usr/bin/env bash
set -euo pipefail

# Match the verified local/Android toolchain. Never print client config values.
flutter_version=3.47.3
flutter_sdk="${FLUTTER_SDK_PATH:-/tmp/saapadu-flutter-${flutter_version}}"
if [[ ! -x "$flutter_sdk/bin/flutter" ]]; then
  git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$flutter_sdk"
fi
export PATH="$flutter_sdk/bin:$PATH"
flutter config --no-analytics
flutter pub get

build_config_file=$(mktemp /tmp/saapadu-defines.XXXXXX.json)
trap 'rm -f "$build_config_file"' EXIT
node - "$build_config_file" <<'JS'
const fs = require('node:fs');
const keys = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'];
if (keys.some(key => !process.env[key])) throw new Error('The existing public Supabase client configuration is missing.');
fs.writeFileSync(process.argv[2], JSON.stringify(Object.fromEntries(keys.map(key => [key, process.env[key]]))), {mode: 0o600});
JS
flutter build web --release --dart-define-from-file="$build_config_file"
