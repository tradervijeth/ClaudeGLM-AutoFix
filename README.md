# Claude-GLM Wrapper

Use [Z.AI's GLM models](https://z.ai) with [Claude Code](https://www.anthropic.com/claude-code) — **without losing your existing Claude setup!**

Switch freely between GLM-4.5, GLM-4.5-Air, and original Anthropic Claude models using simple commands.

## Why This Wrapper?

**💰 Cost-effective**: Z.AI's GLM models offer competitive pricing (often with free tiers)
**🔄 Risk-free**: Your existing Claude Code setup remains completely untouched
**⚡ Multiple options**: Choose between standard (GLM-4.5) and fast (GLM-4.5-Air) models
**🎯 Perfect for**: Development, testing, or when you want to conserve your Claude API credits

## Quick Start

```bash
# 1. Clone and install
git clone https://github.com/JoeInnsp23/claude-glm-wrapper.git
cd claude-glm-wrapper
bash install.sh

# 2. Source your shell config (the installer will tell you the exact command)
source ~/.zshrc  # or ~/.bashrc

# 3. Start using GLM models!
ccg              # Start Claude Code with GLM-4.5
ccf              # Start Claude Code with GLM-4.5-Air (faster)
cca              # Switch back to regular Claude
```

That's it! 🎉

## Features

- 🚀 **Easy switching** between GLM and Claude models
- ⚡ **Two GLM models**: Standard (GLM-4.5) and Fast (GLM-4.5-Air)
- 🔒 **No sudo required**: Installs to user's home directory
- 🖥️ **Server-friendly**: Works on Unix/Linux servers
- 📁 **Isolated configs**: Each model uses its own config directory — no conflicts!
- 🔧 **Shell aliases**: Quick access with simple commands

## Prerequisites

1. **Claude Code**: Install from [anthropic.com/claude-code](https://www.anthropic.com/claude-code)
2. **Z.AI API Key**: Get your free key from [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list)

## Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/JoeInnsp23/claude-glm-wrapper.git
cd claude-glm-wrapper
```

### Step 2: Run the Installer
```bash
bash install.sh
```

The installer will:
- Check if Claude Code is installed
- Ask for your Z.AI API key
- Create wrapper commands in `~/.local/bin`
- Add convenient aliases to your shell

### Step 3: Activate (IMPORTANT!)
After installation completes, run the command the installer shows you:
```bash
source ~/.zshrc  # or ~/.bashrc, depending on your shell
```

**⚠️ Don't skip this step!** Without sourcing, the commands won't be available in your current terminal.

## Usage

### Available Commands & Aliases

The installer creates these commands and aliases:

| Alias | Full Command | What It Does | When to Use |
|-------|--------------|--------------|-------------|
| `cc` | `claude` | Regular Claude Code | Default - use your normal Claude |
| `ccg` | `claude-glm` | GLM-4.5 (standard) | Best quality GLM model |
| `ccf` | `claude-glm-fast` | GLM-4.5-Air (fast) | Quicker responses, lower cost |
| `cca` | `claude-anthropic` | Original Claude | Switch back to Anthropic Claude |

**💡 Tip**: Use the short aliases! They're faster to type and easier to remember.

### How It Works

Each command starts a **separate Claude Code session** with different configurations:
- `ccg` and `ccf` use Z.AI's API with your Z.AI key
- `cca` uses Anthropic's API with your Anthropic key
- Your configurations **never conflict** — they're stored in separate directories

### Basic Examples

**Start a coding session with GLM:**
```bash
ccg
# Opens Claude Code using GLM-4.5
```

**Need faster responses? Use the fast model:**
```bash
ccf
# Opens Claude Code using GLM-4.5-Air
```

**Switch back to regular Claude:**
```bash
cca
# Opens Claude Code with Anthropic models
```

**Pass arguments like normal:**
```bash
ccg --help
ccg "refactor this function"
ccf "quick question about Python"
```

## Common Workflows

### Workflow 1: Testing with GLM, Production with Claude
```bash
# Develop and test with cost-effective GLM
ccg
# ... work on your code ...
# exit

# Switch to Claude for final review
cca
# ... final review with Claude ...
```

### Workflow 2: Quick Questions with Fast Model
```bash
# Quick syntax questions
ccf "how do I use async/await in Python?"

# Complex refactoring with standard model
ccg
# ... longer coding session ...
```

### Workflow 3: Multiple Projects
```bash
# Project 1: Use GLM to save costs
cd ~/project1
ccg

# Project 2: Use Claude for critical work
cd ~/project2
cca
```

**Each session is independent** — your chat history stays separate!

## Configuration Details

### Where Things Are Stored

Each wrapper uses its own configuration directory to prevent conflicts:

| Command | Config Directory | Purpose |
|---------|-----------------|---------|
| `claude-glm` | `~/.claude-glm/` | GLM-4.5 settings and history |
| `claude-glm-fast` | `~/.claude-glm-fast/` | GLM-4.5-Air settings and history |
| `claude-anthropic` | `~/.claude/` (default) | Your original Claude setup |

**This means:**
- ✅ Your original Claude settings are **never touched**
- ✅ Chat histories stay separate for each model
- ✅ API keys are isolated — no mixing!

### Wrapper Scripts Location

The installer creates wrapper scripts in `~/.local/bin/`:
- `~/.local/bin/claude-glm`
- `~/.local/bin/claude-glm-fast`
- `~/.local/bin/claude-anthropic`

These are just tiny bash scripts that set the right environment variables before launching Claude Code.

## Updating Your API Key

### Option 1: Use the Installer (Easiest)
```bash
cd claude-glm-wrapper
bash install.sh
# Choose option "1) Update API key only"
```

### Option 2: Edit Manually
```bash
nano ~/.local/bin/claude-glm
nano ~/.local/bin/claude-glm-fast
# Find and replace ANTHROPIC_AUTH_TOKEN value
```

## How It Works (Technical Details)

The wrapper scripts work by setting environment variables before launching Claude Code:

| Environment Variable | What It Does |
|---------------------|--------------|
| `ANTHROPIC_BASE_URL` | Points to Z.AI's API endpoint |
| `ANTHROPIC_AUTH_TOKEN` | Your Z.AI API key |
| `ANTHROPIC_MODEL` | Which model to use (glm-4.5 or glm-4.5-air) |
| `CLAUDE_HOME` | Where to store config files |

Claude Code reads these variables and uses them instead of the defaults. Simple! 🎯

## Troubleshooting

### ❌ "claude command not found"

**Problem**: Claude Code isn't installed or not in your PATH.

**Solutions**:
1. Install Claude Code from [anthropic.com/claude-code](https://www.anthropic.com/claude-code)
2. Or add Claude to your PATH if it's installed elsewhere

**Test it**: Run `which claude` — it should show a path.

### ❌ "ccg: command not found" (or ccf, cca)

**Problem**: You didn't source your shell config after installation.

**Solution**: Run the source command the installer showed you:
```bash
source ~/.zshrc  # or ~/.bashrc
```

**Still not working?** Try opening a new terminal window.

### ❌ API Authentication Errors

**Problem**: Z.AI API key issues.

**Solutions**:
1. **Check your key**: Visit [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list)
2. **Verify credits**: Make sure your Z.AI account has available credits
3. **Update the key**: Run `bash install.sh` and choose "Update API key only"

### ❌ Wrong Model Being Used

**Problem**: Using `ccg` but it's using the wrong API.

**Solution**: Each command is independent. Make sure you:
- Exit any running Claude Code session
- Start fresh with the command you want (`ccg`, `ccf`, or `cca`)

### 💡 General Tips

- **Open new terminal**: After installation, aliases work in new terminals automatically
- **Check the greeting**: Each command prints what model it's using when it starts
- **Test with**: `ccg --version` to verify the command works

## Uninstallation

### Quick Uninstall

```bash
# Remove wrapper scripts
rm ~/.local/bin/claude-glm
rm ~/.local/bin/claude-glm-fast
rm ~/.local/bin/claude-anthropic

# Remove config directories (optional - deletes chat history)
rm -rf ~/.claude-glm
rm -rf ~/.claude-glm-fast
```

### Remove Aliases

Edit your shell config file and remove these lines:
```bash
# Claude Code Model Switcher Aliases
alias cc='claude'
alias ccg='claude-glm'
alias ccf='claude-glm-fast'
alias cca='claude-anthropic'
```

**Files to check**: `~/.zshrc` or `~/.bashrc`

After removing, run: `source ~/.zshrc` (or your shell's rc file)

## FAQ

### Q: Will this affect my existing Claude Code setup?
**A**: No! Your regular Claude Code setup is completely untouched. The wrappers use separate config directories.

### Q: Can I use both GLM and Claude in the same project?
**A**: Yes! Just use `ccg` for GLM sessions and `cca` for Claude sessions. Each maintains its own chat history.

### Q: Which model should I use - standard or fast?
**A**:
- Use **`ccg` (GLM-4.5)** for: Complex coding, refactoring, detailed explanations
- Use **`ccf` (GLM-4.5-Air)** for: Quick questions, simple tasks, faster responses

### Q: Is this secure?
**A**: Yes! Your API keys are stored locally on your machine in plain bash scripts (just like Claude Code's default config). Keep your `~/.local/bin` directory permissions secure.

### Q: Does this work on Windows?
**A**: Not yet. This is designed for Unix/Linux/macOS. Windows users could try WSL (Windows Subsystem for Linux).

### Q: Can I use a different Z.AI model?
**A**: Yes! Edit the wrapper scripts in `~/.local/bin/` and change the `ANTHROPIC_MODEL` variable to any model Z.AI supports.

### Q: What happens if I run out of Z.AI credits?
**A**: The GLM commands will fail with an API error. Just switch to regular Claude using `cca` until you add more credits.

## Contributing

Found a bug? Have an idea? Contributions are welcome!

- 🐛 **Report issues**: [GitHub Issues](https://github.com/JoeInnsp23/claude-glm-wrapper/issues)
- 🔧 **Submit PRs**: Fork, improve, and open a pull request
- 💡 **Share feedback**: Tell us how you're using this tool!

## License

MIT License - see [LICENSE](LICENSE) file for details.

**TL;DR**: Free to use, modify, and distribute. No warranty provided.

## Acknowledgments

- 🙏 [Z.AI](https://z.ai) for providing GLM model API access
- 🙏 [Anthropic](https://anthropic.com) for Claude Code
- 🙏 You, for using this tool!

---

**⭐ Found this useful?** Give it a star on GitHub and share it with others!
