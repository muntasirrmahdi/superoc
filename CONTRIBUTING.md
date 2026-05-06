# Contributing to SuperOC

First off, thanks for taking the time to contribute!

## Development Setup
1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b my-new-feature`
4. Make your changes

## Writing Adapters
If you are adding support for a new agent (e.g., Goose, OpenHands), please create a new file in `lib/adapters/`. 
Ensure your adapter correctly identifies the agent's system prompt or configuration file and safely injects the verification directive without breaking the agent's native format.

## Pull Request Process
1. Ensure your scripts are POSIX compliant or specify `bash`.
2. Do not use `flock` assuming it exists everywhere; use the fallback detection from `install.sh`.
3. Submit a PR describing the problem you solve.
