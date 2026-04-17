# Claude Code -- Global Instructions

## Behavioral Rules

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they are absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- NEVER use non-ASCII characters -- ASCII only in all output, code, and files (no emojis, no unicode symbols, no smart quotes)
- Batch all independent operations in a single message for parallelism

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- MUST validate user input at system boundaries
- MUST sanitize file paths to prevent directory traversal
