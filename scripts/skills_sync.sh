#!/usr/bin/env bash
# =============================================================================
# ec_sign.sh — EC key generation & SHA256withECDSA request signing
# Compatible with macOS (BSD base64) and Linux (GNU base64)
# Dependencies: openssl (>=1.1)
# Usage:
#   ./ec_sign.sh generate
#   ./ec_sign.sh sign <private_key_b64> <url> [body]
#   ./ec_sign.sh selftest
# =============================================================================
set -euo pipefail

# macOS base64 uses "-b 0", Linux uses "-w 0" — detect automatically
b64_encode() {
    if base64 --version 2>&1 | grep -q GNU; then
        base64 -w 0
    else
        base64 -b 0   # macOS / BSD
    fi
}

# ─────────────────────────────────────────────
# 1. generate_key_pair
# ─────────────────────────────────────────────
generate_key_pair() {
    local tmpdir
    tmpdir=$(mktemp -d)

    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
        -out "$tmpdir/private.pem" 2>/dev/null

    openssl pkey -in "$tmpdir/private.pem" \
        -pubout -outform DER -out "$tmpdir/public.der" 2>/dev/null

    openssl pkcs8 -topk8 -nocrypt \
        -in "$tmpdir/private.pem" -outform DER \
        -out "$tmpdir/private.der" 2>/dev/null

    PUB_KEY_B64=$(b64_encode < "$tmpdir/public.der")
    PRI_KEY_B64=$(b64_encode < "$tmpdir/private.der")

    rm -rf "$tmpdir"
    export PUB_KEY_B64 PRI_KEY_B64
}

# ─────────────────────────────────────────────
# 2. gen_sign <private_key_b64> <message>
# ─────────────────────────────────────────────
gen_sign() {
    local private_key_b64="$1"
    local message="$2"

    local tmpdir
    tmpdir=$(mktemp -d)

    echo "$private_key_b64" | base64 -d > "$tmpdir/private.der"

    openssl pkey -inform DER -in "$tmpdir/private.der" \
        -out "$tmpdir/private.pem" 2>/dev/null

    printf '%s' "$message" > "$tmpdir/message.bin"

    SIGN_B64=$(openssl dgst -sha256 -sign "$tmpdir/private.pem" \
        "$tmpdir/message.bin" 2>/dev/null | b64_encode)
    
    rm -rf "$tmpdir"
    export SIGN_B64
}


# ─────────────────────────────────────────────
# 3. sign_request <private_key_b64> <url> [body]
# ─────────────────────────────────────────────
sign_request() {
    local private_key_b64="$1"
 

    TIMESTAMP=$(date +%s)000   # seconds * 1000 ≈ milliseconds
    # macOS date doesn't support %3N; if gdate (GNU coreutils) is available use it
    if command -v gdate &>/dev/null; then
        TIMESTAMP=$(gdate +%s%3N)
    fi

    local pre_sign

    pre_sign="/v3/users/login/login${BODY}${TIMESTAMP}"

    echo "[sign_request] pre_sign_str : ${pre_sign:0:40}..."
    echo "[sign_request] timestamp    : $TIMESTAMP"

    gen_sign "$private_key_b64" "$pre_sign"

    SIGN="$SIGN_B64"

    export SIGN TIMESTAMP
}

# =============================================================================
# 4. get_token
#    使用已生成的 PUB_KEY_B64 / PRI_KEY_B64 完成签名并 POST 登录接口
# =============================================================================
get_token() {
    # ── 确保密钥已生成 ──────────────────────────────────────────────────────
    if [[ -z "${PUB_KEY_B64:-}" || -z "${PRI_KEY_B64:-}" ]]; then
        echo "[login] 未检测到密钥，自动生成..." >&2
        generate_key_pair
    fi
    # ── 构造 pre-sign 并签名 ───────────────────────────────────────────────
    sign_request "$PRI_KEY_B64"
    # sign_request 会 export SIGN 和 TIMESTAMP

    local url="https://www.okx.com/v3/users/login/login"
    echo ""
    echo "[login] POST $url"
    echo "[login] body: ${BODY:0:40}..."
    echo ""

    # ── 发送请求 ───────────────────────────────────────────────────────────
    RESPONSE=$(curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "devid: 1bacb89f-3218-4b4d-a3ba-c1f984e9ba48" \
        -H "Referer: https://www.okx.com" \
        -H "Set-Cookie: tmxSessionId=" \
        -H "x-brokerid: 0" \
        -H "x-simulated-trading: 0" \
        -H "X-Client-Public-Key: ${PUB_KEY_B64}" \
        -H "X-Client-Signature: ${SIGN}" \
        -H "X-Request-Timestamp: ${TIMESTAMP}" \
        -H "X-Client-Private-Key: ${PRI_KEY_B64}" \
        -d "$USER")

    # ── 检查 code，提取 token（纯 shell）─────────────────────────────────
    CODE=$(echo "$RESPONSE" | grep -o '"code":[0-9]*' | head -1 | cut -d: -f2)
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)
 
    if [[ "$CODE" == "0" ]]; then
        echo "[login] Login success"
        echo "[login] TOKEN: ${TOKEN:0:40}..."
        export TOKEN
    else
        echo "[login] Login failed, code: $CODE" >&2
        echo "[login] response: $RESPONSE" >&2
        exit 1
    fi

}

# =============================================================================
# 5. upload_skill
#    upload a new skill
#    example: ./skills_sync.sh upload_skill
# =============================================================================
upload_skill() {
    RESPONSE=$(curl -X POST "https://www.okx.com/priapi/v5/trade/skill/my/upload" \
  	-H "Authorization: ${TOKEN}" \
  	-F "name=$NAME" \
  	-F "title=$TITLE" \
  	-F "description=$DESC" \
  	-F "version=$VERSION" \
  	-F "categories=$CATEGORIES" \
	-F "tag=OFFICIAL" \
  	-F "file=@$FILE_PATH")

    echo "$RESPONSE"
    CODE=$(echo "$RESPONSE" | grep -o '"code":[0-9]*' | head -1 | cut -d: -f2)
    if [[ "$CODE" == "0" ]]; then
        echo "[upload_skill] upload_skill success"
    else
        echo "[upload_skill] upload_skill failed, code: $CODE" >&2
        echo "[upload_skill] response: $RESPONSE" >&2
        exit 1
    fi
}

# =============================================================================
# 6. update_skill
#    update an existing skill
#    example: ./skills_sync.sh update_skill
# =============================================================================
update_skill() {
    RESPONSE=$(curl -X POST "https://www.okx.com/priapi/v5/trade/skill/my/upload-version" \
  	-H "Authorization: ${TOKEN}" \
  	-F "name=$NAME" \
  	-F "title=$TITLE" \
  	-F "description=$DESC" \
  	-F "version=$VERSION" \
  	-F "categories=$CATEGORIES" \
	-F "tag=OFFICIAL" \
  	-F "file=@$FILE_PATH")

    echo "$RESPONSE"
    CODE=$(echo "$RESPONSE" | grep -o '"code":[0-9]*' | head -1 | cut -d: -f2)
    if [[ "$CODE" == "0" ]]; then
        echo "[update_skill] update_skill success"
    else
        echo "[update_skill] update_skill failed, code: $CODE" >&2
        echo "[update_skill] response: $RESPONSE" >&2
        exit 1
    fi
}

# =============================================================================
# 7. sync_skill
#    sync skill
# =============================================================================
sync_skill() {
    RESPONSE=$(curl -X POST "https://www.okx.com/priapi/v5/trade/skill/public/detail" \
	-H "Content-Type: application/json" \
  	-H "Authorization: ${TOKEN}" \
  	-d "{\"name\": \"${NAME}\"}")

    echo "skill detail response: $RESPONSE"
    CODE=$(echo "$RESPONSE" | grep -o '"code":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Response code: $CODE"
    if [[ "$CODE" == "0" ]]; then
        echo "skill $NAME found, updating skill..."
	update_skill
    elif [[ "$CODE" == "80001" ]]; then
    	echo "skill $NAME not found, uploading skill..."
	upload_skill
    else
        echo "[sync_skill] response: $RESPONSE" >&2
        exit 1
    fi
}

# =============================================================================
# 8. get_version
#    get skill version $CURR_VERSION , return "-1" if skill not found
#    example: ./skills_sync.sh get_version
# =============================================================================
get_version() {
    RESPONSE=$(curl -X POST "https://www.okx.com/priapi/v5/trade/skill/public/detail" \
	-H "Content-Type: application/json" \
  	-H "Authorization: ${TOKEN}" \
  	-d "{\"name\": \"${NAME}\"}")

    echo "skill detail response: $RESPONSE"
    CODE=$(echo "$RESPONSE" | grep -o '"code":"[^"]*"' | head -1 | cut -d'"' -f4)
    CURR_VERSION="-1"

    echo "Response code: $CODE"
    if [[ "$CODE" == "0" ]]; then
        CURR_VERSION=$(echo "$RESPONSE" | grep -o '"lastApprovedVersion":"[^"]*"' | cut -d'"' -f4)
        echo "skill $NAME found, current version: $CURR_VERSION "
        export CURR_VERSION
    elif [[ "$CODE" == "80001" ]]; then
    	echo "skill $NAME not found, it's a new skill"
    	export CURR_VERSION
    else
        echo "[sync_skill] response: $RESPONSE" >&2
        exit 1
    fi
}

# ─────────────────────────────────────────────
# 8. CLI entry-point
# ─────────────────────────────────────────────
cmd="${1:-sync_skill}"

case "$cmd" in
    generate)
        generate_key_pair
        echo "pubKey : $PUB_KEY_B64"
        echo "priKey : $PRI_KEY_B64"
        ;;
    sign)
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 sign <private_key_b64> <url> [body]" >&2
            exit 1
        fi
        sign_request "$2" "$3" "${4:-}"
        echo ""
        echo "Result → sign      : $SIGN"
        echo "         timestamp  : $TIMESTAMP"
        ;;
    sync_skill)
        echo "start sync_skill"
	      get_token
        sync_skill
        echo "complete sync_skill"
        ;;
    get_token)
        echo "getting token"
        get_token
        echo ""
        ;;
    upload_skill)
        echo "uploading skill"
        upload_skill
        echo ""
        ;;
    update_skill)
        echo "updating skill"
        update_skill
        echo ""
        ;;
    get_version)
        echo "getting skill version"
        get_token
        get_version
        echo ""
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        echo "Usage: $0 {generate|sign|get_token|selftest}" >&2
        exit 1
        ;;
esac

