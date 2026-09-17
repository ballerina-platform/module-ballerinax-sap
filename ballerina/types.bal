// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
import ballerina/crypto;
import ballerina/http;

# The `sap` client return type for the HTTP client actions.
public type TargetType http:Response|anydata;

# Configuration for SAP's OAuth 2.0 SAML Bearer Assertion Flow.
#
# Use this when a SuccessFactors (or other SAP) tenant has an OAuth2 client application
# registered under Admin Center > Manage OAuth2 Client Applications, as an alternative to
# Basic Authentication.
@display {label: "SAML Bearer Auth Config"}
public type SamlBearerAuthConfig record {|
    # The API Key of the registered OAuth2 client application (used as the SAML assertion `Issuer`)
    string clientId;
    # The SAP company/tenant ID
    string companyId;
    # The SAP user to authenticate as (used as the SAML assertion `Subject`/`NameID`)
    string username;
    # The private key matching the certificate registered with the OAuth2 client application
    crypto:PrivateKey|string privateKey;
    # PEM-encoded X.509 certificate matching what was registered with the OAuth2 client application.
    # Accepts either the certificate content directly, or a file path to it.
    string certificate;
    # The OAuth2 token endpoint, typically `https://<admin-center-host>/oauth/token`
    string tokenUrl;
    # SAML assertion validity window, in seconds, before/after the time of the request
    decimal validityPeriod = 300;
|};

# An OAuth 2.0 access token obtained via the SAML Bearer flow, along with how long it is valid
# for, so callers can tell when it needs to be refreshed.
public type SamlBearerToken record {|
    # The OAuth 2.0 access token, for use as `http:BearerTokenConfig`
    string accessToken;
    # How long the access token is valid for, in seconds, as reported by the token endpoint
    # (defaults to 3600 if the endpoint did not include an `expires_in` field)
    decimal expiresIn = 3600;
|};

# Configurations for initializing an `sap:Client`. Mirrors `http:ClientConfiguration` field for
# field (record type inclusion can't be used here: it only allows narrowing an included field's
# type, and `auth` needs to be widened instead), except `auth` also accepts `SamlBearerAuthConfig`
# for SAP's OAuth 2.0 SAML Bearer Assertion Flow, alongside the usual Basic Auth
# (`http:CredentialsConfig`) and other `http:ClientAuthConfig` variants.
public type ConnectionConfig record {|
    # Configurations related to client authentication
    http:ClientAuthConfig|SamlBearerAuthConfig auth;
    # The HTTP version understood by the client
    http:HttpVersion httpVersion = http:HTTP_2_0;
    # Configurations related to HTTP/1.x protocol
    http:ClientHttp1Settings http1Settings = {};
    # Configurations related to HTTP/2 protocol
    http:ClientHttp2Settings http2Settings = {};
    # The maximum time to wait (in seconds) for a response before closing the connection
    decimal timeout = 30;
    # The choice of setting `forwarded`/`x-forwarded` header
    string forwarded = "disable";
    # Configurations associated with Redirection
    http:FollowRedirects followRedirects?;
    # Configurations associated with request pooling
    http:PoolConfiguration poolConfig?;
    # HTTP caching related configurations
    http:CacheConfig cache = {};
    # Specifies the way of handling compression (`accept-encoding`) header
    http:Compression compression = http:COMPRESSION_AUTO;
    # Configurations associated with the behaviour of the Circuit Breaker
    http:CircuitBreakerConfig circuitBreaker?;
    # Configurations associated with retrying
    http:RetryConfig retryConfig?;
    # Configurations associated with cookies
    http:CookieConfig cookieConfig?;
    # Configurations associated with inbound response size limits
    http:ResponseLimitConfigs responseLimits = {};
    # SSL/TLS-related options
    http:ClientSecureSocket secureSocket?;
    # Proxy server related options
    http:ProxyConfig proxy?;
    # Provides settings related to client socket configuration
    http:ClientSocketConfig socketConfig = {};
    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    boolean validation = true;
    # Enables relaxed data binding on the client side. When enabled, `nil` values are treated as optional,
    # and absent fields are handled as `nilable` types. Enabled by default.
    boolean laxDataBinding = true;
|};
