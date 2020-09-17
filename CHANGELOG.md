# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added

- Restart fluent-bit pods when the custom config changes ([#3])
- Always enable fluent-bit's HTTP server for readiness/liveness probes ([#2])
- Patch containerPort in DaemonSet when metrics port is customized ([#2])
- Initial Implementation ([#1])

### Fixed

- Properly quote 'On' and 'Off' values in `class/defaults.yml`

[Unreleased]: https://github.com/projectsyn/component-fluentbit/compare/50f0caf4c8718ca57f09c8bff71c8518717ce6d3...HEAD
[#1]: https://github.com/projectsyn/component-fluentbit/pull/1
[#2]: https://github.com/projectsyn/component-fluentbit/pull/2
[#3]: https://github.com/projectsyn/component-fluentbit/pull/3
