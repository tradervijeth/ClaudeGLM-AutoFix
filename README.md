# Claude-GLM Wrapper

A convenient wrapper for using [Z.AI's GLM models](https://z.ai) with [Claude Code](https://www.anthropic.com/claude-code), allowing you to switch between GLM-4.5, GLM-4.5-Air, and original Anthropic Claude models.

## Features

- 🚀 **Easy switching** between GLM and Claude models
- ⚡ **Multiple model options**: GLM-4.5 (standard) and GLM-4.5-Air (fast)
- 🔒 **No sudo required**: Installs to user's home directory
- 🖥️ **Server-friendly**: Works on Unix/Linux servers
- 📁 **Isolated configs**: Each model variant uses its own config directory
- 🔧 **Shell aliases**: Quick access with `ccg`, `ccf`, and `cca` commands

## Prerequisites

1. **Claude Code**: Install from [anthropic.com/claude-code](https://www.anthropic.com/claude-code)
2. **Z.AI API Key**: Get your key from [z.ai/manage-apikey/apikey-list](https://z.ai/manage-apikey/apikey-list)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/JoeInnsp23/claude-glm-wrapper.git
cd claude-glm-wrapper
```

2. Run the installer:
```bash
bash install.sh
```

3. Follow the prompts to enter your Z.AI API key

4. Update your PATH (required):
```bash
source ~/.zshrc  # or ~/.bashrc, depending on your shell
```

## Usage

### Commands

After installation, you'll have three commands available:

| Command | Description | Model |
|---------|-------------|-------|
| `claude-glm` | GLM-4.5 standard model | glm-4.5 |
| `claude-glm-fast` | GLM-4.5-Air fast model | glm-4.5-air |
| `claude-anthropic` | Original Anthropic Claude | claude-sonnet-4-5 |

### Aliases

For convenience, short aliases are also available:

```bash
ccg      # Alias for claude-glm
ccf      # Alias for claude-glm-fast
cca      # Alias for claude-anthropic
```

### Examples

Start Claude Code with GLM-4.5:
```bash
claude-glm
# or
ccg
```

Start with the fast model:
```bash
claude-glm-fast
# or
ccf
```

Switch back to Anthropic Claude:
```bash
claude-anthropic
# or
cca
```

Pass arguments to Claude Code:
```bash
claude-glm --help
ccg "explain this code"
```

## Configuration

Each wrapper uses its own configuration directory to avoid conflicts:

- `claude-glm` → `~/.claude-glm/`
- `claude-glm-fast` → `~/.claude-glm-fast/`
- `claude-anthropic` → default Claude config directory

The installer creates wrapper scripts in:
- `~/.local/bin/claude-glm`
- `~/.local/bin/claude-glm-fast`
- `~/.local/bin/claude-anthropic`

## Updating API Key

If you need to update your Z.AI API key later:

1. Run the installer again:
```bash
bash install.sh
```

2. Choose option "1) Update API key only"

Or manually edit the wrapper scripts:
```bash
nano ~/.local/bin/claude-glm
nano ~/.local/bin/claude-glm-fast
```

## How It Works

The wrapper scripts set environment variables that Claude Code respects:

- `ANTHROPIC_BASE_URL` → Points to Z.AI's API endpoint
- `ANTHROPIC_AUTH_TOKEN` → Your Z.AI API key
- `ANTHROPIC_MODEL` → The model to use
- `CLAUDE_HOME` → Custom config directory

## Troubleshooting

### "claude command not found"

Claude Code is not in your PATH. Install it from [anthropic.com/claude-code](https://www.anthropic.com/claude-code) or add it to your PATH.

### Wrappers not found after installation

Your `~/.local/bin` directory is not in your PATH. Run:
```bash
source ~/.zshrc  # or your shell's rc file
```

### API authentication errors

- Verify your Z.AI API key is correct
- Check your Z.AI account has credits
- Ensure the API key is properly set in the wrapper scripts

## Uninstallation

Remove the wrapper scripts and aliases:

```bash
rm ~/.local/bin/claude-glm
rm ~/.local/bin/claude-glm-fast
rm ~/.local/bin/claude-anthropic
```

Then remove the alias lines from your shell rc file (`~/.zshrc` or `~/.bashrc`).

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Z.AI](https://z.ai) for providing GLM model API access
- [Anthropic](https://anthropic.com) for Claude Code
