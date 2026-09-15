// Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org).
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
import ballerina/http;
import ballerina/jballerina.java;
import ballerina/mime;

# The `sap` client return type for the HTTP client actions.
public type TargetType http:Response|anydata;

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

# The `sap` client provides the capability for initiating contact with a remote HTTP service provided by any SAP products. The API it
# provides includes the functions for the standard HTTP methods.
public client isolated class Client {

    final http:Client httpClient;
    private string? csrfToken = ();

    # Gets invoked to initialize the `client`. During initialization, the configurations provided through the `config`
    # record is used to determine which type of additional behaviours are added to the endpoint (e.g.
    # security, circuit breaking). Caching is enabled always.
    #
    # If `config.auth` is a `SamlBearerAuthConfig`, an OAuth 2.0 access token is obtained via the SAML
    # Bearer Assertion Flow before the underlying HTTP client is created. **That token is not
    # refreshed automatically** - the token endpoint's own `expires_in` (commonly around 24 hours for
    # SuccessFactors) is the client's effective lifetime. For a long-running integration, reconstruct
    # this `Client` (a cheap operation - it just repeats the assertion build/sign/exchange) before
    # that window lapses, or after observing an authentication failure from the underlying service.
    #
    # + url - URL of the target service
    # + config - The configurations to be used when initializing the `client`
    # + return - The `client` or an `sap:ClientError` if the initialization failed
    public isolated function init(string url, ConnectionConfig config) returns ClientError? {
        do {
            http:ClientAuthConfig resolvedAuth;
            if config.auth is SamlBearerAuthConfig {
                SamlBearerToken token = check getSamlBearerAccessToken(<SamlBearerAuthConfig>config.auth);
                resolvedAuth = {token: token.accessToken};
            } else {
                resolvedAuth = <http:ClientAuthConfig>config.auth;
            }
            http:ClientConfiguration httpConfig = {
                auth: resolvedAuth,
                httpVersion: config.httpVersion,
                http1Settings: config.http1Settings,
                http2Settings: config.http2Settings,
                timeout: config.timeout,
                forwarded: config.forwarded,
                followRedirects: config.followRedirects,
                poolConfig: config.poolConfig,
                cache: config.cache,
                compression: config.compression,
                circuitBreaker: config.circuitBreaker,
                retryConfig: config.retryConfig,
                cookieConfig: config.cookieConfig,
                responseLimits: config.responseLimits,
                secureSocket: config.secureSocket,
                proxy: config.proxy,
                socketConfig: config.socketConfig,
                validation: config.validation,
                laxDataBinding: config.laxDataBinding
            };
            httpConfig.cookieConfig = {enabled: true};
            self.httpClient = check new (url, httpConfig);
        } on fail error e {
            return error ClientError("Failed to initialize the SAP client", e);
        }
        return;
    }

    # The client resource function to send HTTP POST requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + message - An HTTP outbound request or any allowed payload
    # + headers - The entity headers
    # + mediaType - The MIME type header of the request entity
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function post [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (), string?
            mediaType = (), typedesc<TargetType> targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "postResource"
    } external;

    # The `Client.post()` function can be used to send HTTP POST requests to SAP HTTP endpoints.
    #
    # + path - Resource path
    # + message - An HTTP outbound request or any allowed payload
    # + headers - The entity headers
    # + mediaType - The MIME type header of the request entity
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function post(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPost(string path, http:RequestMessage message, typedesc<TargetType> targetType,
            string? mediaType, map<string|string[]>? headers) returns TargetType|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->post(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
        return response;
    }

    # The client resource function to send HTTP PUT requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + message - An HTTP outbound request or any allowed payload
    # + headers - The entity headers
    # + mediaType - The MIME type header of the request entity
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function put [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (), string?
            mediaType = (), typedesc<TargetType> targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "putResource"
    } external;

    # The `Client.put()` function can be used to send HTTP PUT requests to SAP HTTP endpoints.
    #
    # + path - Resource path
    # + message - An HTTP outbound request or any allowed payload
    # + mediaType - The MIME type header of the request entity
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function put(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPut(string path, http:RequestMessage message, typedesc<TargetType> targetType,
            string? mediaType, map<string|string[]>? headers) returns TargetType|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->put(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->put(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    # The client resource function to send HTTP PATCH requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + message - An HTTP outbound request or any allowed payload
    # + headers - The entity headers
    # + mediaType - The MIME type header of the request entity
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function patch [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), typedesc<TargetType> targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "patchResource"
    } external;

    # The `Client.patch()` function can be used to send HTTP PATCH requests to SAP HTTP endpoints.
    #
    # + path - Resource path
    # + message - An HTTP outbound request or any allowed payload
    # + mediaType - The MIME type header of the request entity
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function patch(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPatch(string path, http:RequestMessage message, typedesc<TargetType> targetType,
            string? mediaType, map<string|string[]>? headers) returns TargetType|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    # The client resource function to send HTTP DELETE requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + message - An optional HTTP outbound request or any allowed payload
    # + headers - The entity headers
    # + mediaType - The MIME type header of the request entity
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function delete [http:PathParamType... path](http:RequestMessage message = (), map<string|string[]>? headers = (),
            string? mediaType = (), typedesc<TargetType> targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "deleteResource"
    } external;

    # The `Client.delete()` function can be used to send HTTP DELETE requests to SAP HTTP endpoints.
    #
    # + path - Resource path
    # + message - An optional HTTP outbound request message or any allowed payload
    # + mediaType - The MIME type header of the request entity
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function delete(string path, http:RequestMessage message = (),
            map<string|string[]>? headers = (), string? mediaType = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processDelete(string path, http:RequestMessage message, typedesc<TargetType> targetType,
            string? mediaType, map<string|string[]>? headers) returns TargetType|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    # The client resource function to send HTTP HEAD requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + headers - The entity headers
    # + params - The query parameters
    # + return - The response or an `sap:ClientError` if failed to establish the communication with the upstream server
    isolated resource function head [http:PathParamType... path](map<string|string[]>? headers = (), *http:QueryParams params)
            returns http:Response|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "headResource"
    } external;

    # The `Client.head()` function can be used to send HTTP HEAD requests to SAP HTTP endpoints.
    #
    # + path - Resource path
    # + headers - The entity headers
    # + return - The response or an `sap:ClientError` if failed to establish the communication with the upstream server
    remote isolated function head(string path, map<string|string[]>? headers = ()) returns http:Response|ClientError {
        return self.httpClient->head(path, headers);
    }

    # The client resource function to send HTTP GET requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function get [http:PathParamType... path](map<string|string[]>? headers = (), typedesc<TargetType> targetType = <>,
            *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "getResource"
    } external;

    # The `Client.get()` function can be used to send HTTP GET requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function get(string path, map<string|string[]>? headers = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processGet(string path, map<string|string[]>? headers, typedesc<TargetType> targetType)
            returns TargetType|error {
        map<string|string[]> headersModified = headers ?: {};
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        return self.httpClient->get(path, headersModified, targetType);
    }

    # The client resource function to send HTTP OPTIONS requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + params - The query parameters
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    isolated resource function options [http:PathParamType... path](map<string|string[]>? headers = (), typedesc<TargetType> targetType = <>,
            *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction",
        name: "optionsResource"
    } external;

    # The `Client.options()` function can be used to send HTTP OPTIONS requests to SAP HTTP endpoints.
    #
    # + path - Request path
    # + headers - The entity headers
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + return - The response or the payload (if the `targetType` is configured) or an `sap:ClientError` if failed to
    # establish the communication with the upstream server or a data binding failure
    remote isolated function options(string path, map<string|string[]>? headers = (), typedesc<TargetType> targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processOptions(string path, map<string|string[]>? headers, typedesc<TargetType> targetType)
            returns TargetType|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        return self.httpClient->options(path, headersModified, targetType);
    }

    isolated function fetchCSRFTokenForModifyingRequest(boolean refreshToken = false) returns string|CSRFTokenFetchFailure {
        string? csrfToken = ();
        lock {
            csrfToken = self.csrfToken;
        }
        if csrfToken is () || refreshToken {
            map<string|string[]> headersModified = {};
            headersModified[SAP_CSRF_HEADER] = SAP_CSRF_TOKEN_FETCH;
            http:Response response = check self.httpClient->head("/", headersModified);
            string|http:HeaderNotFoundError header = response.getHeader(SAP_CSRF_HEADER);
            if header is string {
                lock {
                    self.csrfToken = header;
                }
                return header;
            } else {
                return error CSRFTokenFetchFailure("CSRF token not found", header);
            }
        }
        return csrfToken;
    }
}

isolated function isCSRFTokenFailure(TargetType|ClientError response) returns boolean {
    if response is http:Response {
        if response.statusCode == http:STATUS_FORBIDDEN {
            string|http:HeaderNotFoundError header = response.getHeader(SAP_CSRF_HEADER);
            if header is string && header.equalsIgnoreCaseAscii(SAP_CSRF_TOKEN_FAILURE_HEADER_VALUE) {
                return true;
            }
        }
    } else if response is http:ClientRequestError {
        var detail = response.detail();
        if detail.statusCode == http:STATUS_FORBIDDEN {
            map<string[]> headers = detail.headers;
            string[]? csrfHeader = headers[SAP_CSRF_HEADER] ?: headers[SAP_CSRF_HEADER.toLowerAscii()];
            if csrfHeader is string[] && csrfHeader.length() > 0 &&
                    csrfHeader[0].equalsIgnoreCaseAscii(SAP_CSRF_TOKEN_FAILURE_HEADER_VALUE) {
                return true;
            }
        }
    }
    return false;
}
