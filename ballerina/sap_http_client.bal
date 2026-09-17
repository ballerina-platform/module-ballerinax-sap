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
import ballerina/crypto;
import ballerina/http;
import ballerina/jballerina.java;
import ballerina/mime;

# The `sap` client provides the capability for initiating contact with a remote HTTP service provided by any SAP products. The API it
# provides includes the functions for the standard HTTP methods.
public client isolated class Client {

    final http:Client httpClient;
    private string? csrfToken = ();
    private final (readonly & SamlBearerAuthConfig)? samlAuthConfig;
    private string? samlAccessToken = ();
    private final (readonly & http:ClientSecureSocket)? samlTokenSecureSocket;
    private final (readonly & http:ProxyConfig)? samlTokenProxy;

    # Gets invoked to initialize the `client`. During initialization, the configurations provided through the `config`
    # record is used to determine which type of additional behaviours are added to the endpoint (e.g.
    # security, circuit breaking). Caching is enabled always.
    #
    # If `config.auth` is a `SamlBearerAuthConfig`, an OAuth 2.0 access token is obtained via the SAML
    # Bearer Assertion Flow and attached as an `Authorization: Bearer` header on every request from
    # then on (the same way an SAP CSRF token is fetched once and attached to every state-changing
    # request) - not baked into the underlying `http:Client`'s own auth config. If the server rejects
    # a request as unauthorized (`401`), a fresh token is obtained and the request retried once,
    # exactly like the existing CSRF-token-expiry retry.
    #
    # `SamlBearerAuthConfig.privateKey` must be a file path (`string`) when used here, not a
    # pre-decoded `crypto:PrivateKey` - the client needs to retain the key for the lifetime of the
    # connection to obtain fresh tokens on demand, and a `crypto:PrivateKey` cannot be safely cloned
    # for storage (its native key material isn't part of its Ballerina-visible shape, so cloning it
    # silently drops it). Pass the key file path instead; it is decoded fresh each time a token is
    # obtained.
    #
    # The token exchange call to `SamlBearerAuthConfig.tokenUrl` reuses this client's own
    # `secureSocket` and `proxy` settings, so a custom/private CA trust or a required corporate
    # proxy applies to it the same way it applies to every other request this client makes.
    #
    # + url - URL of the target service
    # + config - The configurations to be used when initializing the `client`
    # + return - The `client` or an `sap:ClientError` if the initialization failed
    public isolated function init(string url, ConnectionConfig config) returns ClientError? {
        do {
            http:ClientAuthConfig? resolvedAuth = ();
            if config.auth is SamlBearerAuthConfig {
                SamlBearerAuthConfig samlConfig = <SamlBearerAuthConfig>config.auth;
                if samlConfig.privateKey is crypto:PrivateKey {
                    return error ClientError(
                        "SamlBearerAuthConfig.privateKey must be a file path (string) when used with " +
                        "sap:Client, not a pre-decoded crypto:PrivateKey - the client cannot safely retain " +
                        "a decoded key across requests. Pass the private key file path instead.");
                }
                self.samlAuthConfig = samlConfig.cloneReadOnly();
                self.samlTokenSecureSocket = config.secureSocket.cloneReadOnly();
                self.samlTokenProxy = config.proxy.cloneReadOnly();
            } else {
                self.samlAuthConfig = ();
                self.samlTokenSecureSocket = ();
                self.samlTokenProxy = ();
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

    # Returns the current (cached, or freshly obtained) SAML Bearer `Authorization` header value, or
    # `()` if this client isn't using `SamlBearerAuthConfig` (Basic Auth and other
    # `http:ClientAuthConfig` variants are handled by the underlying `http:Client` itself and need
    # no extra header here).
    #
    # + refresh - Force obtaining a fresh token even if one is already cached
    # + return - The `Authorization` header value, `()`, or an `sap:ClientError` if a fresh token
    # could not be obtained
    private isolated function getSamlAuthHeader(boolean refresh = false) returns string?|ClientError {
        (readonly & SamlBearerAuthConfig)? samlConfig = self.samlAuthConfig;
        if samlConfig is () {
            return ();
        }
        string? token = ();
        lock {
            token = self.samlAccessToken;
        }
        if token is () || refresh {
            SamlBearerToken freshToken = check getSamlBearerAccessToken(samlConfig, self.samlTokenSecureSocket, self.samlTokenProxy);
            token = freshToken.accessToken;
            lock {
                self.samlAccessToken = freshToken.accessToken;
            }
        }
        if token is () {
            return error ClientError("Failed to resolve a SAML Bearer access token");
        }
        return string `Bearer ${token}`;
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->post(path, message, headersModified, mediaType, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            response = self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->put(path, message, headersModified, mediaType, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            response = self.httpClient->put(path, message, headersModified, mediaType, targetType);
        }
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            response = self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        }
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            response = self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        }
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
        map<string|string[]> headersModified = headers ?: {};
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        http:Response|ClientError response = self.httpClient->head(path, headersModified);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            return self.httpClient->head(path, headersModified);
        }
        return response;
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|error response = self.httpClient->get(path, headersModified, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            return self.httpClient->get(path, headersModified, targetType);
        }
        return response;
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
        string? samlAuthHeader = check self.getSamlAuthHeader();
        if samlAuthHeader is string {
            headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
        }
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        TargetType|ClientError response = self.httpClient->options(path, headersModified, targetType);
        if self.isSAMLAuthFailure(response) {
            string? refreshedSamlAuthHeader = check self.getSamlAuthHeader(true);
            if refreshedSamlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = refreshedSamlAuthHeader;
            }
            return self.httpClient->options(path, headersModified, targetType);
        }
        return response;
    }

    isolated function fetchCSRFTokenForModifyingRequest(boolean refreshToken = false) returns string|CSRFTokenFetchFailure {
        string? csrfToken = ();
        lock {
            csrfToken = self.csrfToken;
        }
        if csrfToken is () || refreshToken {
            map<string|string[]> headersModified = {};
            string? samlAuthHeader = check self.getSamlAuthHeader();
            if samlAuthHeader is string {
                headersModified[AUTHORIZATION_HEADER] = samlAuthHeader;
            }
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

    # Whether a response (or the error a generically-bound call failed with) indicates the request
    # was rejected as unauthorized - the trigger to obtain a fresh SAML Bearer token and retry once.
    # Always `false` when this client isn't using `SamlBearerAuthConfig`, since there is no SAML
    # token to refresh and retrying would just repeat the same failed request.
    #
    # + response - The response (or error) returned by the underlying `http:Client` call
    # + return - Whether a SAML Bearer token refresh and retry should be attempted
    private isolated function isSAMLAuthFailure(TargetType|error response) returns boolean {
        if self.samlAuthConfig is () {
            return false;
        }
        if response is http:Response {
            return response.statusCode == http:STATUS_UNAUTHORIZED;
        }
        if response is http:ClientRequestError {
            // Generically-bound (non-http:Response) calls surface a non-2xx status as an error
            // rather than a value - its detail carries the status code the underlying http:Client
            // reported.
            return response.detail().statusCode == http:STATUS_UNAUTHORIZED;
        }
        return false;
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
