#!/usr/bin/env bash
# Chạy toàn bộ test headless: mọi tests/*_test.gd, rồi hai cặp test LAN hai tiến trình.
# Thoát 1 nếu có test fail hoặc quá thời gian. Dùng: bash tools/run_tests.sh
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
TIMEOUT="${TEST_TIMEOUT:-180}"
LOG_DIR="${TEST_LOG_DIR:-.godot/test-logs}"
mkdir -p "$LOG_DIR"

results=()
failed=0

record() { # name, exit code
	if [ "$2" -eq 0 ]; then
		results+=("PASS  $1")
	else
		results+=("FAIL  $1 (exit $2, log $LOG_DIR/$1.log)")
		failed=$((failed + 1))
	fi
}

run_one() { # script path relative to res://, log name
	timeout "$TIMEOUT" "$GODOT" --headless --path . --script "res://$1" -- "${3:-}" >"$LOG_DIR/$2.log" 2>&1
}

echo "== import"
"$GODOT" --headless --path . --editor --import --quit >"$LOG_DIR/import.log" 2>&1
record import $?

for test in tests/*_test.gd; do
	name="$(basename "$test" .gd)"
	echo "== $name"
	run_one "$test" "$name"
	record "$name" $?
done

run_pair() { # host script, client script, name
	echo "== $3"
	run_one "$1" "$3_host" "${4:-}" &
	local host=$!
	sleep 2
	run_one "$2" "$3_client" "${5:-}"
	local client_rc=$?
	wait "$host"
	local host_rc=$?
	record "$3_host" "$host_rc"
	record "$3_client" "$client_rc"
}

run_pair tests/network_host_harness.gd tests/network_client_harness.gd network_pair
run_pair tests/lan_match_host.gd tests/lan_match_client.gd lan_match
run_pair tests/combat_readability_lan_test.gd tests/combat_readability_lan_test.gd combat_readability_lan --host --client

echo
printf '%s\n' "${results[@]}"
echo "${#results[@]} checks, $failed failed"
[ "$failed" -eq 0 ]
