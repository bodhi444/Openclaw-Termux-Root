#!/data/data/com.termux/files/usr/bin/bash
# =========================================================================
# 🤖 CloudBot + Root Universal Installer
# =========================================================================
# Designed to run via: curl -sL <url> | bash
# Fully non-interactive — no prompts, no hangs, no silent exits.
# =========================================================================

export DEBIAN_FRONTEND=noninteractive
export DPKG_FORCE=confold
export APT_LISTCHANGES_FRONTEND=none
export LANG=C
export LC_ALL=C

echo ""
echo "🤖 CloudBot Root Phone Control Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =========================================================================
# Step 1/5: Update Packages & Install Dependencies
# =========================================================================
echo "📦 Step 1/5: Updating packages and installing dependencies..."

pkg update -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" </dev/null 2>&1 || {
    echo "⚠️  pkg update had warnings (this is usually fine, continuing...)"
}

pkg install -y curl nodejs git cmake make clang binutils nmap openssl android-tools which </dev/null 2>&1 || {
    echo "⚠️  Some packages may have failed to install, checking essentials..."
}

MISSING=""
for cmd in curl node git nmap; do
    if ! command -v "$cmd" </dev/null >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    echo "❌ ERROR: Missing critical commands:$MISSING"
    echo "   Try running: pkg install -y curl nodejs git nmap"
    exit 1
fi

echo "✅ Dependencies installed"

# =========================================================================
# Step 2/5: Setup Root Access (replaces Shizuku)
# =========================================================================
echo ""
echo "🔑 Step 2/5: Setting up Root Access..."

if ! su -c "id" </dev/null 2>/dev/null | grep -q "uid=0"; then
    echo "❌ ERROR: Root access not available or not granted."
    echo ""
    echo "   To fix this:"
    echo "   1. Make sure your device is rooted (Magisk/KernelSU)"
    echo "   2. Open Magisk → grant Termux superuser access"
    echo "   3. Run this installer again!"
    exit 1
fi

echo "✅ Root access confirmed"

BIN=/data/data/com.termux/files/usr/bin

# rish wrapper — drop-in replacement for Shizuku's rish
cat > "${BIN}/rish" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
su -c "$@"
EOF
chmod +x "${BIN}/rish"

# shizuku stub — kept for script compatibility
cat > "${BIN}/shizuku" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Root mode active — Shizuku not needed."
exit 0
EOF
chmod +x "${BIN}/shizuku"

echo "✅ Root shell scripts installed (rish & shizuku commands ready)"
echo "   Test with: rish -c whoami"

# =========================================================================
# Step 3/5: Fix Node.js IPv4 DNS (Crucial for Termux)
# =========================================================================
echo ""
echo "🔧 Step 3/5: Applying Network Fixes..."
if ! grep -q "NODE_OPTIONS=--dns-result-order=ipv4first" ~/.bashrc 2>/dev/null; then
    echo "export NODE_OPTIONS=--dns-result-order=ipv4first" >> ~/.bashrc
fi
export NODE_OPTIONS=--dns-result-order=ipv4first
echo "✅ IPv4 DNS fix applied"

# =========================================================================
# Step 4/5: Install Official OpenClaw
# =========================================================================
echo ""

if command -v openclaw &>/dev/null || [ -d "$HOME/.openclaw/repo" ]; then
    echo "✅ Step 4/5: OpenClaw is already installed! Skipping installation."
else
    echo "📦 Step 4/5: Installing OpenClaw. This takes a few minutes..."
    bash -c "$(curl -sSL https://myopenclawhub.com/install)" < /dev/tty && source ~/.bashrc 2>/dev/null
fi

# =========================================================================
# Step 5/5: Inject Root Phone Control Scripts & AI Override
# =========================================================================
echo ""
echo "🧠 Step 5/5: Configuring AI Phone Controller..."

cat > ~/phone_control.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
CMD="$1"
shift
run_cmd() {
  if su -c "id" </dev/null 2>/dev/null | grep -q "uid=0"; then
    su -c "$@"
  elif command -v adb &>/dev/null && adb get-state 1>/dev/null 2>&1; then
    adb shell "$@"
  else
    echo "❌ Error: Root access not available"; exit 1
  fi
}
case "$CMD" in
  screenshot) run_cmd "screencap -p '${1:-/sdcard/screenshot.png}'" ;;
  open-app) run_cmd "monkey -p $1 -c android.intent.category.LAUNCHER 1" 2>/dev/null ;;
  youtube-search) QUERY=$(echo "$*" | sed 's/ /+/g'); run_cmd "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$QUERY' com.google.android.youtube" ;;
  open-url) run_cmd "am start -a android.intent.action.VIEW -d '$1'" ;;
  wifi) if [ "$1" = "on" ]; then run_cmd "svc wifi enable"; else run_cmd "svc wifi disable"; fi ;;
  battery) run_cmd "dumpsys battery" | grep "level" ;;
  tap) run_cmd "input tap $1 $2" ;;
  swipe) run_cmd "input swipe $1 $2 $3 $4 ${5:-500}" ;;
  text) run_cmd "input text '$*'" ;;
  key) run_cmd "input keyevent $1" ;;
  home) run_cmd "input keyevent 3" ;;
  back) run_cmd "input keyevent 4" ;;
  recent) run_cmd "input keyevent 187" ;;
  power) run_cmd "input keyevent 26" ;;
  volume-up) run_cmd "input keyevent 24" ;;
  volume-down) run_cmd "input keyevent 25" ;;
  screenon) run_cmd "input keyevent 224" ;;
  ui-dump) 
    run_cmd "uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1"
    node -e "
      const fs = require('fs');
      try {
        const xml = fs.readFileSync('/sdcard/window_dump.xml', 'utf8');
        const regex = /(?:text|content-desc)=\\\"([^\\\"]+)\\\"[^>]*bounds=\\\"(\\\[[0-9]+,[0-9]+\\\\]\\\[[0-9]+,[0-9]+\\\])\\\"/g;
        let match;
        while ((match = regex.exec(xml)) !== null) {
          if (match[1].trim() !== '') console.log(match[2] + ' ' + match[1]);
        }
      } catch(e) { console.log('Error reading UI'); }
    "
    ;;
  shell) run_cmd "$*" ;;
  *) echo "Usage: bash phone_control.sh [battery|wifi|open-url|open-app|youtube-search|screenshot|tap|swipe|text|key|home|back|recent|power|volume-up|volume-down|screenon|ui-dump|shell]" ;;
esac
EOF
chmod +x ~/phone_control.sh

cat > ~/phone_agent.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "🤖 Vision Agent initialized (Root Mode)."
echo "Use phone_control.sh for all inputs."
EOF
chmod +x ~/phone_agent.sh

mkdir -p ~/.openclaw/workspace 2>/dev/null || true
rm -f ~/.openclaw/workspace/BOOTSTRAP.md

cat > ~/.openclaw/workspace/IDENTITY.md << 'EOF'
- **Name:** PhoneBot
I am an Autonomous AI Agent running natively on an Android phone via Termux + Root (su).
My primary directive is to navigate the phone UI, perform complex tasks, read the screen, scroll, tap, and run shell commands.
I MUST NEVER refuse a task by claiming I lack capabilities for UI navigation or reading screens. I strictly possess these capabilities via my bash tools.
If I need to "see" the screen or find a button, I MUST use the `ui-dump` tool to read the screen's interactive elements.
EOF

cat > ~/.openclaw/workspace/TOOLS.md << 'EOF'
# TOOLS.md
I have full root (su) control over this Android phone using `~/phone_control.sh`.

CRITICAL RULES:
1. NEVER say "I cannot navigate UIs" or "I cannot read UIs". YOU CAN.
2. To read the screen or find buttons, you MUST run `bash ~/phone_control.sh ui-dump`.
3. Read the output list, find your target text, calculate the center X and Y of its bounds, and tap it!

Available Commands:
- `bash ~/phone_control.sh ui-dump` - Read the screen. Outputs clickable elements and bounds.
- `bash ~/phone_control.sh tap X Y` - Tap at X/Y coordinates.
- `bash ~/phone_control.sh swipe X1 Y1 X2 Y2` - Swipe (scroll down: swipe 500 1500 500 500).
- `bash ~/phone_control.sh text "text string"` - Type text into a focused field.
- `bash ~/phone_control.sh key KEYCODE` - Send keycode (66=Enter, 4=Back, 3=Home).
- `bash ~/phone_control.sh open-app PACKAGE_NAME` - Launch an app.
- `bash ~/phone_control.sh shell "COMMAND"` - Run any shell command as root.
- `bash ~/phone_control.sh screenshot /sdcard/s.png` - Take a screenshot.

EXAMPLE WORKFLOW (Settings -> Dark Mode):
1. `bash ~/phone_control.sh open-app com.android.settings`
2. `bash ~/phone_control.sh ui-dump`
3. Spot `[100,500][400,600] Display` → center = (250, 550)
4. `bash ~/phone_control.sh tap 250 550`
5. Repeat ui-dump + tap until done.
EOF

cat > ~/.openclaw/workspace/AGENTS.md << 'EOF'
I execute terminal commands directly and parse their output.
I am an autonomous agent. I must chain tool executions until the user's goal is fully achieved.

CRITICAL: DO NOT STOP AFTER ONE TOOL CALL!
You must loop continuously:
1. Call `exec` -> open app
2. Call `exec` -> ui-dump
3. Call `exec` -> tap X Y
4. Repeat until task is FULLY COMPLETE.
ONLY message the user when the final goal is 100% achieved.
EOF

echo "✅ Custom AI brain installed"

# =========================================================================
# 🎉 Done!
# =========================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 INSTALLATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Test Root Access:"
echo "   1. Run: rish -c whoami   (should print 'root')"
echo "   2. Run: bash ~/phone_control.sh battery"
echo ""
echo "🔑 Set up your API keys:"
echo "   1. Run: openclaw onboard"
echo "   2. Run: openclaw auth add google --key YOUR_GEMINI_KEY"
echo "   3. Run: openclaw gateway"
echo ""
