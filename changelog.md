# Changelog

This file contains all the notable changes done to the Ballerina `sap` package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- [Default the client to HTTP/1.1](https://github.com/ballerina-platform/ballerina-library/issues/9768)

### Fixed

- [Send the caller's `Accept` header instead of replacing it with `application/json`](https://github.com/ballerina-platform/ballerina-library/issues/9763). A request that passes an `Accept` header, for example one forwarded from an inbound request, gets the format it asks for instead of JSON
- [Stop modifying the caller's header map and `http:Request`](https://github.com/ballerina-platform/ballerina-library/issues/9763)
- [Resend stream bodies in full when a request is retried after a token refresh](https://github.com/ballerina-platform/ballerina-library/issues/9765). A stream body, and the content of body parts, of a modifying request is read into memory before it is sent
- [Send the request's routing and session headers on the CSRF token fetch](https://github.com/ballerina-platform/ballerina-library/issues/9766)
- [Match the CSRF failure header case-insensitively for data-bound targets](https://github.com/ballerina-platform/ballerina-library/issues/9767)
- [Keep the caller's cookie settings](https://github.com/ballerina-platform/ballerina-library/issues/9769)
- Report the HTTP status when the CSRF token fetch or the SAML Bearer token exchange is rejected
- Escape the API key and user name in the SAML assertion
- Refresh an expired SAML Bearer token when the CSRF token fetch is rejected with `401`

## [1.4.0] - 17/09/2026

### Added

- [Add OAuth 2.0 SAML Bearer Assertion Flow support](https://github.com/ballerina-platform/module-ballerinax-sap/pull/35)

## [1.3.1] - 26/03/2026

### Changed

- Update the package overview and keywords

### Fixed

- Fix the distribution version in `Ballerina.toml`

## [1.3.0] - 09/02/2026

### Added

- Depends on 2201.13.0 distribution

### Fixed

- [Fix Wrong HTTP method on retry for CSRF token failure](https://github.com/ballerina-platform/ballerina-library/issues/8640)
- [Fix CSRF token refresh fails for request with databinding](https://github.com/ballerina-platform/ballerina-library/issues/8641)

## [1.2.0] - 03/03/2025

### Changed

- Release on top of Update 11, Add Java 21 Support

## [1.1.0] - 23/08/2024

### Changed

- Release on top of Update 10

## [1.0.0] - 03/06/2024

### Added

- Add `sap:Client` support
