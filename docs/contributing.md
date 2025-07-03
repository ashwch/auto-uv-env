---
layout: page
title: Contributing
permalink: /contributing/
---

# Contributing

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/ashwch/auto-uv-env.git
   cd auto-uv-env
   ```

2. **Install development dependencies**
   ```bash
   uv tool install pre-commit
   ```

3. **Set up pre-commit hooks**
   ```bash
   uv tool run pre-commit install
   ```

## Testing

Run the test suite:

```bash
./test/test.sh
```

Security testing:
```bash
./test/test-security.sh
```

## Code Style

- Use 4-space indentation for shell scripts
- Follow existing patterns and conventions
- Add comments for complex logic
- Ensure all scripts have proper shebangs
- Use shellcheck-compliant code

## Pull Request Guidelines

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the development workflow
4. Ensure all tests pass and pre-commit hooks succeed
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request