# Repository Guidance

This repository contains try-outs, proofs of concept, experiments, and throwaway programs. It is not intended for general usage or broad exploration.

When working in this repository, agents should assume they are expected to work only in a specific folder provided by the user. Unless explicitly told otherwise:

- Do not explore unrelated folders.
- Do not inspect or modify files outside the requested folder.
- Do not infer repo-wide conventions from other experiments in this repository.
- Keep discovery, edits, and verification scoped to the specified folder.

If the user does not specify a folder, ask for the target folder before exploring the repository.

## Git Configuration

Before making any commits, always configure git identity:

```bash
git config user.name "Martin Palma"
git config user.email "m@palma.bz"
```
