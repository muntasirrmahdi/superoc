# SuperOC Changelog

## [0.2.0-alpha] - 2026-05-07

### Added
- Extraction Layer (lib/extract_session.sh) - Signal/noise filtering for session log analysis
- Semantic Bridge (lib/wikilinks_parser.py) - [[Entity]] link parser and knowledge graph builder
- User-Facing CLI (bin/remember) - Memory injection command with categories (-u, -d, -i, -l)
- Backup System (lib/backup.sh) - Automated weekly snapshots with restore capability
- Constitutional Template (templates/AGENTS.md) - Enforcement rules template
- Learning Model (templates/learning-models/learning-model.md) - Captures agent learnings
- Understanding Model (templates/learning-models/understanding-model.md) - Agent's understanding of user
- wikilinks_graph field in state.json - Entity knowledge graph
- daily.logs in state.json - Last 7 days of session activity
- days_loaded counter in state.json - Tracks loaded session count
- Updated state.schema.json with all 8 required fields

### Changed
- Directory structure updated to match full 11-component architecture
- Templates moved to proper locations (bin/, lib/, templates/)
- Wikilinks parser uses JSON configuration for flexibility

### Fixed
- Fix #7: Transcript capture using script command (wrapper now records session to latest_session.log)
- Fix #8: llm_extract.py path mismatch - aligned with compile_state.sh templates/ directory
- Fix #9: load_memory.sh literal variable writing - fixed double quote interpolation
- Fix #10: SUPEROC_ACTIVE bypass guard missing from generic and other adapters
- Fix #11: KNOWN_AGENTS outdated - updated to include all 5 adapters

### Known Limitations
- Wikilinks parser requires configuration file at ~/.superoc/wikilinks.json
- Backup system requires manual cron setup for automation

### LLM Extraction Status
- LLM extraction is LIVE via llm_extract.py (wired into post_session_audit.sh)
- Uses actual LLM API calls for semantic understanding (not keyword matching)
- See lib/llm_extract.py for implementation details

---

## [0.1.1-alpha] - 2026-05-06

### Added
- Comprehensive security fixes (lock permissions, state.json ownership)
- Cross-platform lock detection
- State.json validation after compilation
- Idempotent adapter injection
- Python3 fallback testing path
- Health monitoring script improvements
- Post-session audit exit code handling

### Changed
- Safe JSON compilation using --rawfile (no shell injection)
- Private lock directories (per-user)
- Template validation before compilation
- Better error messages (standardized)
- Documentation updated to reflect experimental philosophical prototype status

### Fixed
- Issue #1.3: jq JSON injection vulnerability
- Issue #2.1: Lock race window verification
- Issue #2.2: Lock directory permissions
- Issue #3.1: Temp file cleanup
- Issue #3.3: Cross-platform stale lock detection
- Issue #3.4: trap INT in child processes
- Issue #3.5: Empty template validation
- Issue #4.1: Recovery from corrupted state.json
- Issue #4.4: Post-audit exit code logging
- Issue #8.1: OpenCode adapter idempotent

### Known Limitations
- Cron-based checkpoint not fully implemented
- Limited agent adapter coverage

---

## [0.1.0-alpha] - 2026-03-26

### Added
- Initial experimental release
- State compilation from markdown
- Basic OpenCode and Claude Code adapters
- Installation/uninstallation scripts
- Basic health monitoring