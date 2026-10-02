#!/bin/bash
# Checks whether The Row's Soft Margaux 15 (black suede) is in stock and sends an
# ntfy push when it comes back. Runs in GitHub Actions; the ntfy channel comes
# from the NTFY_TOPIC secret. ./state holds the last known state (committed back
# by the workflow when it changes) so each restock alerts only once.
# Prints IN_STOCK, SOLD_OUT, or FAILED: <reason>. Pass --test to send a test alert.
URL="https://www.therow.com/products/soft-margaux-15-black-suede"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"

notify() {
  curl -s --max-time 15 -H "Title: The Row" -H "Priority: urgent" -H "Tags: handbag" -H "Click: $URL" \
    -d "$1" "https://ntfy.sh/$NTFY_TOPIC" > /dev/null || echo "WARN: ntfy failed"
}

[ -n "$NTFY_TOPIC" ] || { echo "FAILED: NTFY_TOPIC secret not set"; exit 1; }
[ "$1" = "--test" ] && { notify "Test from GitHub: The Row stock alert is working."; echo "TEST_SENT"; exit 0; }

json=$(curl -sL --max-time 30 -A "$UA" -w '\n%{http_code}' "$URL.js")
code=$(echo "$json" | tail -1)
if [ "$code" != "200" ]; then echo "FAILED: HTTP $code"; exit 0; fi

# Product-level "available" is true when any variant can be bought.
avail=$(echo "$json" | sed '$d' | grep -oE '"available":(true|false)' | head -1 | cut -d: -f2)
if [ -z "$avail" ]; then echo "FAILED: no stock info in product data"; exit 0; fi

prev=$(cat state 2>/dev/null || echo sold_out)
if [ "$avail" = "true" ]; then
  echo "IN_STOCK"
  echo in_stock > state
  [ "$prev" != "in_stock" ] && notify "IN STOCK: The Row Soft Margaux 15 (black suede) — $URL"
else
  echo "SOLD_OUT"
  echo sold_out > state
fi
