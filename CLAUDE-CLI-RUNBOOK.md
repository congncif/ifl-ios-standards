# Claude CLI candidate runbook

Runbook này dùng Claude CLI với cấu hình/local transport bình thường của máy để đọc đúng plugin
candidate trong checkout hiện tại. Không có bước kiểm tra auth, cấu hình provider, build hay test.

## 1. Chọn đúng candidate

Chạy từ repository root:

```bash
cd /Volumes/KingstonXS1000/WORKSPACE/ABC/ifl-ios-pack/marketplace/.build/worktrees/ifl-ios-pack-standards-v1

REPO="$(git rev-parse --show-toplevel)"
PLUGIN="$REPO/ifl-ios-standards"
VERSION="$(tr -d '\r\n' < "$PLUGIN/VERSION")"
SHA="$(git rev-parse HEAD)"
CLI_VERSION="$(claude --version | head -n 1)"

test -z "$(git status --porcelain)" || { echo "STOP: candidate worktree is not clean"; exit 1; }
printf 'CLI=%s\nVERSION=%s\nSHA=%s\nPLUGIN=%s\n' \
  "$CLI_VERSION" "$VERSION" "$SHA" "$PLUGIN"
```

`--plugin-dir "$PLUGIN"` bên dưới là authority xác định candidate. Claude vẫn dùng setting sources
bình thường để đi qua local model/transport đã cấu hình.

## 2. Smoke test nhanh — khuyến nghị

Chạy đúng một lần:

```bash
claude -p \
  --no-session-persistence \
  --output-format text \
  --plugin-dir "$PLUGIN" \
  --permission-mode bypassPermissions \
  --dangerously-skip-permissions \
  --settings '{"enabledPlugins":{}}' \
  "Use /ifl-ios-standards:brain-flow as the first Standards action. Inspect only the exact candidate at $PLUGIN, expected version $VERSION and commit $SHA. Read only VERSION, skills/brain-flow/SKILL.md, skills/boardy-review/SKILL.md, and the metadata of agents/*.md. Do not edit files, build, test, run verification scripts, or invoke another provider. Return exactly these bounded lines and no prose:
CLI_VERSION=$CLI_VERSION
CANDIDATE_VERSION=<observed>
CANDIDATE_PATH=<observed>
BRAIN_FLOW_LOADED=PASS|FAIL
CLAUDE_AGENTS=<observed count>/9
BOARDY_REVIEW_SINGLE_PASS=PASS|FAIL
Q2=NOT_RUN
Q4=NOT_RUN
Q6=NOT_RUN
P0_P1=<NONE or concise finding>
RELEASE_CROSSING=NO"
```

Kết quả mong đợi: đúng `CANDIDATE_VERSION`, đúng path, `BRAIN_FLOW_LOADED=PASS`,
`CLAUDE_AGENTS=9/9`, `BOARDY_REVIEW_SINGLE_PASS=PASS`, không có P0/P1 và
`RELEASE_CROSSING=NO`.

## 3. Tùy chọn — một lượt readiness Q2/Q4/Q6

Lệnh này chỉ đánh giá tính sẵn sàng tĩnh qua Claude provider. `READY` không đồng nghĩa với row đã
được field-qualified; không có fixture hay product build/test trong runbook này.

```bash
claude -p \
  --no-session-persistence \
  --output-format text \
  --plugin-dir "$PLUGIN" \
  --permission-mode bypassPermissions \
  --dangerously-skip-permissions \
  --settings '{"enabledPlugins":{}}' \
  "Use /ifl-ios-standards:brain-flow as the first Standards action. Read the exact candidate at $PLUGIN, expected version $VERSION and commit $SHA. Perform one joined read-only readiness review for Claude rows Q2, Q4, and Q6 as defined in RELEASE.md. Read only VERSION, RELEASE.md, skills/brain-flow/SKILL.md, skills/boardy-review/SKILL.md, agents/*.md, and the minimum directly referenced standards needed to decide those three rows. Do not edit files, build, test, run verification scripts, create evidence files, or invoke another provider. Collect all findings before disposition and do not re-review. Return exactly these bounded lines and no prose:
CLI_VERSION=$CLI_VERSION
CANDIDATE_VERSION=<observed>
CANDIDATE_PATH=<observed>
BRAIN_FLOW_LOADED=PASS|FAIL
CLAUDE_AGENTS=<observed count>/9
BOARDY_REVIEW_SINGLE_PASS=PASS|FAIL
Q2=READY|GAP:<concise reason>
Q4=READY|GAP:<concise reason>
Q6=READY|GAP:<concise reason>
P0_P1=<NONE or concise joined finding>
RELEASE_CROSSING=NO"
```

## 4. Quy tắc dừng

- Không thêm `--setting-sources ""`; nó loại bỏ setting source dùng cho local-model route.
- Không thêm `--mcp-config` hoặc `--strict-mcp-config`; MCP không cần cho phép thử này, và inline JSON
  không phải input ổn định giữa các phiên bản CLI.
- Không đặt `CLAUDE_CONFIG_DIR` rỗng và không làm auth preflight.
- Nếu xuất hiện connector warning nhưng inference vẫn chạy, bỏ qua warning.
- Nếu sau 5 phút chưa có final output, nhấn `Ctrl-C` một lần, ghi nhận `PROVIDER_TIMEOUT`, và không
  chạy lại nguyên lệnh không thay đổi.
- Không redirect raw output vào repository. Chỉ gửi lại block kết quả gồm các dòng bounded ở trên.
