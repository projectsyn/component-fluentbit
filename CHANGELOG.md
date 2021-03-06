# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.0.1]
### Fixed
- Configure custom parsers in separate file ([#13])

## [v1.0.0]
### Added

- Support for repeatable fluent-bit options ([#11])
- Restart fluent-bit pods when the custom config changes ([#3])
- Always enable fluent-bit's HTTP server for readiness/liveness probes ([#2])
- Patch containerPort in DaemonSet when metrics port is customized ([#2])
- Initial Implementation ([#1])

### Changed

- Upgrade Helm chart to v0.7.13 ([#7])
- Make volumes configurable ([#8])
- Upgrade Helm chart to 0.15.1 ([#10])

### Fixed

- Create ServiceMonitor manually ([#9])
- Properly quote 'On' and 'Off' values in `class/defaults.yml`
- Ensure filters are added to fluent-bit config in predictable order ([#6])

[Unreleased]: https://github.com/projectsyn/component-fluentbit/compare/v1.0.0...HEAD
[v1.0.1]: https://github.com/projectsyn/component-fluentbit/releases/tag/v1.0.1
[v1.0.0]: https://github.com/projectsyn/component-fluentbit/releases/tag/v1.0.0

[#1]: https://github.com/projectsyn/component-fluentbit/pull/1
[#2]: https://github.com/projectsyn/component-fluentbit/pull/2
[#3]: https://github.com/projectsyn/component-fluentbit/pull/3
[#6]: https://github.com/projectsyn/component-fluentbit/pull/6
[#7]: https://github.com/projectsyn/component-fluentbit/pull/7
[#8]: https://github.com/projectsyn/component-fluentbit/pull/8
[#9]: https://github.com/projectsyn/component-fluentbit/pull/9
[#10]: https://github.com/projectsyn/component-fluentbit/pull/10
[#11]: https://github.com/projectsyn/component-fluentbit/pull/11
[#13]: https://github.com/projectsyn/component-fluentbit/pull/13
