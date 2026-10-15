#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/iOS/Desktop/Apps/Browser/DesktopBrowserState.swift"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Compile the actual URL sanitizer and sensitive-name declaration extracted from
# the application source. Fail closed if either implementation disappears.
python3 - "$SOURCE" "$TMP/BrowserSecuritySmoke.swift" <<'PY'
from pathlib import Path
import re
import sys
source = Path(sys.argv[1]).read_text()

names = re.search(r'private static let sensitiveHistoryQueryNames:\s*Set<String>\s*=\s*\[[^\]]*\]', source, re.S)
if not names:
    raise SystemExit('Missing sensitiveHistoryQueryNames declaration')
method = re.search(r'\bstatic func historySafeURL\(_ url: URL\) -> URL\?\s*\{', source)
if not method:
    raise SystemExit('Missing historySafeURL method')
start = method.start()
depth = 0
end = None
for i in range(method.end() - 1, len(source)):
    if source[i] == '{': depth += 1
    elif source[i] == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end is None:
    raise SystemExit('Unterminated historySafeURL method')

header = 'import Foundation\n\nenum BrowserSecurityUnderTest {\n'
body = names.group(0) + '\n\n' + source[start:end]
tests = r'''
}

let cases: [(String, String, String?)] = [
    ("OAuth token", "https://example.com/cb?access_token=FAKE", "https://example.com/cb"),
    ("OAuth code", "https://example.com/cb?code=FAKE", "https://example.com/cb"),
    ("fragment", "https://example.com/cb#access_token=FAKE", "https://example.com/cb"),
    ("userinfo", "https://demo:FAKE@example.com/account", "https://example.com/account"),
    ("api_key", "https://example.com/?api_key=FAKE", "https://example.com/"),
    ("api-key", "https://example.com/?api-key=FAKE", "https://example.com/"),
    ("apikey", "https://example.com/?apikey=FAKE", "https://example.com/"),
    ("client_secret", "https://example.com/?client_secret=FAKE", "https://example.com/"),
    ("refreshToken", "https://example.com/?refreshToken=FAKE", "https://example.com/"),
    ("refresh_token", "https://example.com/?refresh_token=FAKE", "https://example.com/"),
    ("AWS signature", "https://example.com/?X-Amz-Signature=FAKE", "https://example.com/"),
    ("AWS credential", "https://example.com/?X-Amz-Credential=FAKE", "https://example.com/"),
    ("sessionId", "https://example.com/?sessionId=FAKE", "https://example.com/"),
    ("JWT", "https://example.com/?jwt=FAKE", "https://example.com/"),
    ("ordinary query", "https://example.com/?q=hello&sort=new", "https://example.com/?q=hello&sort=new"),
    ("mixed query", "https://example.com/?q=hello&api_key=FAKE&sort=new", "https://example.com/?q=hello&sort=new"),
    ("authToken", "https://example.com/callback?authToken=FAKE", "https://example.com/callback"),
    ("AWSAccessKeyId", "https://example.com/file?AWSAccessKeyId=FAKE", "https://example.com/file"),
    ("SAMLResponse", "https://example.com/login?SAMLResponse=FAKE", "https://example.com/login"),
    ("oauth_verifier", "https://example.com/callback?oauth_verifier=FAKE", "https://example.com/callback"),
    ("oauth state", "https://example.com/callback?state=FAKE", "https://example.com/callback"),
    ("sessionKey", "https://example.com/?sessionKey=FAKE", "https://example.com/"),
    ("signed URL with extra params", "https://example.com/file?X-Amz-Signature=FAKE&X-Amz-Credential=FAKE&download=1", "https://example.com/file?download=1"),
    ("normal search", "https://example.com/search?q=hello&sort=new", "https://example.com/search?q=hello&sort=new"),
    ("authCode alias", "https://example.com/cb?authCode=FAKE", "https://example.com/cb"),
    ("accessKeyId alias", "https://example.com/?accessKeyId=FAKE", "https://example.com/"),
    ("clientAssertion credential", "https://example.com/?clientAssertion=FAKE", "https://example.com/"),
    ("auth_code alias", "https://example.com/cb?auth_code=FAKE", "https://example.com/cb"),
    ("authorizationCode alias", "https://example.com/cb?authorizationCode=FAKE", "https://example.com/cb"),
    ("client_assertion", "https://example.com/?client_assertion=FAKE", "https://example.com/"),
    ("AWS secret access key", "https://example.com/?aws_secret_access_key=FAKE", "https://example.com/"),
    ("signedRequest", "https://example.com/?signedRequest=FAKE", "https://example.com/"),
    ("access_key", "https://example.com/?access_key=FAKE", "https://example.com/"),
    ("auth_key", "https://example.com/?auth_key=FAKE", "https://example.com/"),
    ("secret_key", "https://example.com/?secret_key=FAKE", "https://example.com/"),
    ("private_key", "https://example.com/?private_key=FAKE", "https://example.com/"),
    ("x-api-key", "https://example.com/?x-api-key=FAKE", "https://example.com/"),
    ("nested OAuth token", "https://example.com/go?next=https%3A%2F%2Fauth.example%2Fcb%3Faccess_token%3DFAKE&q=hello", "https://example.com/go?q=hello"),
    ("nested userinfo", "https://example.com/go?next=https%3A%2F%2Fuser%3AFAKE%40auth.example%2Fhome", "https://example.com/go"),
    ("double-encoded nested OAuth token", "https://example.com/go?next=https%253A%252F%252Fauth.example%252Fcb%253Faccess_token%253DFAKE", "https://example.com/go"),
    ("two nested redirects OAuth", "https://example.com/go?next=https%3A%2F%2Fmiddle.example%2Fredirect%3Fnext%3Dhttps%253A%252F%252Fauth.example%252Fcb%253Faccess_token%253DFAKE", "https://example.com/go"),
    ("three nested redirects OAuth", "https://example.com/go?next=https%3A%2F%2Fmiddle2.example%2Fredirect%3Fnext%3Dhttps%253A%252F%252Fmiddle.example%252Fredirect%253Fnext%253Dhttps%25253A%25252F%25252Fauth.example%25252Fcb%25253Faccess_token%25253DFAKE", "https://example.com/go"),
    ("benign nested URL", "https://example.com/go?next=https://other.example/article", "https://example.com/go?next=https://other.example/article"),
    ("non-http", "ftp://example.com/file?token=FAKE", nil)
]
var failures = 0
for (name, input, expected) in cases {
    guard let url = URL(string: input) else { fatalError("Bad test URL") }
    let actual = BrowserSecurityUnderTest.historySafeURL(url)?.absoluteString
    let passed = actual == expected
    print("\(passed ? "PASS" : "FAIL") \(name): \(actual ?? "nil")")
    if !passed { failures += 1 }
}
if failures > 0 {
    fputs("BROWSER_PERSISTENCE_SECURITY_FAIL: \(failures) of \(cases.count)\n", stderr)
    exit(1)
}
print("BROWSER_PERSISTENCE_SECURITY_OK: \(cases.count) cases")
'''
Path(sys.argv[2]).write_text(header + body + tests)
PY
swiftc "$TMP/BrowserSecuritySmoke.swift" -o "$TMP/browser-security-smoke"
"$TMP/browser-security-smoke"
