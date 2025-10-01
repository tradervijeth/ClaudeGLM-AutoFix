# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Windows PowerShell support with full feature parity
- Cross-platform npm package installer (`npx claude-glm-installer`)
- Automatic detection and cleanup of old wrapper installations
- GLM-4.6 model support as new default
- GLM-4.5 wrapper (ccg45) for backward compatibility
- Universal bootstrap script for OS auto-detection
- Comprehensive Windows documentation and troubleshooting
- Platform-specific installation paths and configuration

### Changed
- Updated default model from GLM-4.5 to GLM-4.6
- Renamed aliases: removed `cca`, kept `cc` for regular Claude
- Improved installation flow with old wrapper detection
- Enhanced README with collapsible platform-specific sections
- Updated cross-platform support documentation

### Fixed
- PATH conflicts when multiple wrapper installations exist
- Version mismatches from old wrapper files
- Installation detection across different locations

## [1.0.0] - 2024-09-30

### Added
- Initial release
- Bash installer for Unix/Linux/macOS
- Support for GLM-4.5 and GLM-4.5-Air models
- Isolated configuration directories per model
- Shell aliases (ccg, ccf, cca, cc)
- No sudo/admin required installation
- Wrapper scripts in ~/.local/bin
- Z.AI API key integration
- Separate chat histories per model

### Features
- Easy switching between GLM and Claude models
- Cost-effective alternative to Claude API
- Risk-free installation (doesn't touch existing Claude setup)
- Server-friendly (user directory installation)
- Interactive API key setup
- Automatic PATH configuration

[Unreleased]: https://github.com/JoeInnsp23/claude-glm-wrapper/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/JoeInnsp23/claude-glm-wrapper/releases/tag/v1.0.0
