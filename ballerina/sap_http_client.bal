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
import ballerina/io;
import ballerina/jballerina.java;
import ballerina/mime;

# The `sap` client provides the capability for initiating contact with a remote HTTP service provided by any SAP products. The API it
# provides includes the functions for the standard HTTP methods.
public client isolated class Client {

    final http:Client httpClient;
    // CSRF tokens by SAP session: the `sap-client`, Cloud Connector location and user the request is sent for.
    private map<string> csrfTokens = {};
    private final (readonly & SamlBearerAuthConfig)? samlAuthConfig;
    private string? samlAccessToken = ();
    private final (readonly & http:ClientSecureSocket)? samlTokenSecureSocket;
    private final (readonly & http:ProxyConfig)? samlTokenProxy;

    # Gets invoked to initialize the `client`. Caching is enabled always.
    #
    # If `config.auth` is a `SamlBearerAuthConfig`, a SAML Bearer access token is attached as an
    # `Authorization` header on every request (like the CSRF token), refreshed and retried once on
    # a `401`. `privateKey` must be a file path (`string`), not a pre-decoded `crypto:PrivateKey` -
    # the latter can't be safely retained across requests. The token exchange reuses this client's
    # own `secureSocket`/`proxy`.
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
            // Cookies carry the SAP session that the CSRF token belongs to, so they are always enabled. The rest of
            // the caller's cookie settings (for example a persistent cookie handler or cookie limits) are kept.
            http:CookieConfig callerCookieConfig = config.cookieConfig ?: {};
            http:CookieConfig cookieConfig = {...callerCookieConfig};
            cookieConfig.enabled = true;
            httpConfig.cookieConfig = cookieConfig;
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

    # Sets the `Authorization` header on `headers` to the current (or freshly obtained) SAML Bearer
    # token, if this client is using `SamlBearerAuthConfig`; otherwise leaves `headers` untouched.
    #
    # + headers - The headers map to update in place
    # + refresh - Force obtaining a fresh token even if one is already cached
    # + return - An `sap:ClientError` if a fresh token was needed but could not be obtained
    private isolated function applySamlAuthHeader(map<string|string[]> headers, boolean refresh = false) returns ClientError? {
        string? samlAuthHeader = check self.getSamlAuthHeader(refresh);
        if samlAuthHeader is string {
            setHeader(headers, AUTHORIZATION_HEADER, samlAuthHeader);
        }
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
        return self.sendModifyingRequest("POST", path, message, targetType, mediaType, headers);
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
        return self.sendModifyingRequest("PUT", path, message, targetType, mediaType, headers);
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
        return self.sendModifyingRequest("PATCH", path, message, targetType, mediaType, headers);
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
        return self.sendModifyingRequest("DELETE", path, message, targetType, mediaType, headers);
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
        map<string|string[]> headersModified = copyHeaders(headers);
        check self.applySamlAuthHeader(headersModified);
        http:Response|ClientError response = self.httpClient->head(path, headersModified);
        if self.isSAMLAuthFailure(response) {
            check self.applySamlAuthHeader(headersModified, true);
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
        map<string|string[]> headersModified = prepareHeaders(headers);
        check self.applySamlAuthHeader(headersModified);
        TargetType|error response = self.httpClient->get(path, headersModified, targetType);
        if self.isSAMLAuthFailure(response) {
            check self.applySamlAuthHeader(headersModified, true);
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
        map<string|string[]> headersModified = prepareHeaders(headers);
        check self.applySamlAuthHeader(headersModified);
        TargetType|ClientError response = self.httpClient->options(path, headersModified, targetType);
        if self.isSAMLAuthFailure(response) {
            check self.applySamlAuthHeader(headersModified, true);
            return self.httpClient->options(path, headersModified, targetType);
        }
        return response;
    }

    # Sends a modifying request (`POST`, `PUT`, `PATCH` or `DELETE`) with a CSRF token, and sends it once more after
    # refreshing the SAML Bearer token (on `401`) or the CSRF token (on `403 X-CSRF-Token: Required`).
    #
    # + method - The HTTP method
    # + path - Request path
    # + message - An HTTP outbound request or any allowed payload
    # + targetType - HTTP response or `anydata`, which is expected to be returned after data binding
    # + mediaType - The MIME type header of the request entity
    # + headers - The entity headers
    # + return - The response or the payload, or an `sap:ClientError`
    private isolated function sendModifyingRequest(string method, string path, http:RequestMessage message,
            typedesc<TargetType> targetType, string? mediaType, map<string|string[]>? headers)
            returns TargetType|ClientError {
        // A stream can be read only once: read it now, so that a retry after a token refresh resends the body.
        http:RequestMessage body = message is http:Request ? message : check bufferStreamBody(message);
        // An `http:Request` message is never sent itself. `http:Client` writes the headers, the credentials and the
        // session cookies onto the request it sends, so every attempt sends a new request built from the caller's.
        RequestSnapshot? snapshot = message is http:Request ? check snapshotRequest(message) : ();
        // An `Accept` header set on an `http:Request` message counts as the caller's choice too.
        boolean acceptOnRequest = snapshot is RequestSnapshot && hasHeaderValue(snapshot.headers, ACCEPT_HEADER);
        map<string|string[]> headersModified = prepareHeaders(headers, !acceptOnRequest);
        // The SAP session the token belongs to is selected by the headers of the request as it is sent: the ones on
        // an `http:Request` message, and the `headers` map over them.
        map<string|string[]> sessionHeaders = snapshot is RequestSnapshot
            ? mergeHeaders(snapshot.headers, headersModified) : headersModified;
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest(path, sessionHeaders);
        // Applied after the token fetch, which may have refreshed the SAML Bearer token.
        check self.applySamlAuthHeader(headersModified);
        setHeader(headersModified, SAP_CSRF_HEADER, csrfToken);
        TargetType|ClientError response = self.invoke(method, path, attemptBody(body, snapshot), headersModified,
            mediaType, targetType);
        if self.isSAMLAuthFailure(response) {
            check self.applySamlAuthHeader(headersModified, true);
            response = self.invoke(method, path, attemptBody(body, snapshot), headersModified, mediaType, targetType);
        }
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(path, sessionHeaders, true);
            check self.applySamlAuthHeader(headersModified);
            setHeader(headersModified, SAP_CSRF_HEADER, csrfToken);
            response = self.invoke(method, path, attemptBody(body, snapshot), headersModified, mediaType, targetType);
        }
        return response;
    }

    private isolated function invoke(string method, string path, http:RequestMessage body,
            map<string|string[]> headers, string? mediaType, typedesc<TargetType> targetType)
            returns TargetType|ClientError {
        return self.httpClient->execute(method, path, body, headers, mediaType, targetType);
    }

    # Returns the CSRF token for the SAP session a modifying request belongs to, fetching it with
    # `HEAD <service URL>/` and `X-CSRF-TOKEN: fetch` when none is cached or `refreshToken` is set.
    #
    # The fetch carries the request's own headers (except the body, conditional and method-override headers), so
    # that headers deciding which system or session the token belongs to, such as `sap-client`,
    # `SAP-Connectivity-SCC-Location_ID` or `Proxy-Authorization`, reach the same backend as the request. A
    # `sap-client` given as a query parameter of the request is sent as a query parameter of the fetch as well.
    #
    # + path - The path of the request the token is for, including its query parameters
    # + requestHeaders - The headers of the request the token is for
    # + refreshToken - Fetch a new token even if one is cached
    # + return - The CSRF token, or an `sap:CSRFTokenFetchFailure` if the server did not return one
    isolated function fetchCSRFTokenForModifyingRequest(string path, map<string|string[]> requestHeaders,
            boolean refreshToken = false) returns string|CSRFTokenFetchFailure {
        string? sapClientInQuery = hasHeader(requestHeaders, SAP_CLIENT) ? () : sapClientQueryParam(path);
        // With SAML Bearer authentication the `Authorization` header is this client's own token, which changes
        // on every refresh, so it does not identify the user.
        string cacheKey = csrfSessionKey(requestHeaders, sapClientInQuery, self.samlAuthConfig is ());
        string? csrfToken = ();
        lock {
            csrfToken = self.csrfTokens[cacheKey];
        }
        if csrfToken is () || refreshToken {
            map<string|string[]> headersModified = tokenFetchHeaders(requestHeaders);
            check self.applySamlAuthHeader(headersModified);
            headersModified[SAP_CSRF_HEADER] = SAP_CSRF_TOKEN_FETCH;
            string fetchPath = sapClientInQuery is string ? string `/?${SAP_CLIENT}=${sapClientInQuery}` : "/";
            http:Response response = check self.httpClient->head(fetchPath, headersModified);
            if response.statusCode == http:STATUS_UNAUTHORIZED && self.samlAuthConfig !is () {
                // The cached SAML Bearer token has expired: get a new one and fetch once more.
                check self.applySamlAuthHeader(headersModified, true);
                response = check self.httpClient->head(fetchPath, headersModified);
            }
            string|http:HeaderNotFoundError header = response.getHeader(SAP_CSRF_HEADER);
            if header is string {
                lock {
                    if self.csrfTokens.length() >= MAX_CACHED_CSRF_TOKENS && !self.csrfTokens.hasKey(cacheKey) {
                        // The session headers come from the caller, so the cache is bounded: the oldest token
                        // makes room. A dropped token is simply fetched again.
                        _ = self.csrfTokens.remove(self.csrfTokens.keys()[0]);
                    }
                    self.csrfTokens[cacheKey] = header;
                }
                return header;
            } else {
                // Name the status, so that a rejected fetch (for example `401` for wrong credentials or `403` for
                // a missing authorization) is not mistaken for a CSRF problem.
                return error CSRFTokenFetchFailure(
                    string `CSRF token not found: the token fetch returned status ${response.statusCode}`, header);
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
            // `detail.headers` keeps the header names as the server sent them (for example `X-CSRF-Token`), so the
            // name is matched case-insensitively, like `http:Response.getHeader` does.
            string? value = headerValue(detail.headers, SAP_CSRF_HEADER);
            return value is string && value.equalsIgnoreCaseAscii(SAP_CSRF_TOKEN_FAILURE_HEADER_VALUE);
        }
    }
    return false;
}

# Returns a mutable copy of the caller's headers, so that the client never modifies the caller's map
# (which may also be read-only) when it adds the `Accept`, CSRF token or `Authorization` headers. A header record's
# `@http:Header` names are resolved, as `http:Client` does for the value it is given.
#
# + headers - The headers passed by the caller
# + return - A new map holding the same headers
isolated function copyHeaders(map<string|string[]>? headers) returns map<string|string[]> {
    return headers is () ? {} : http:getHeaderMap(headers);
}

# Returns a mutable copy of the caller's headers and sets `Accept: application/json`, unless the caller
# has already set an `Accept` header (in any letter case), for example `application/atom+xml` or
# `application/xml` for an OData V2 service. Empty `Accept` values are not a choice and are dropped.
#
# + headers - The headers passed by the caller
# + defaultAccept - Whether to add the default `Accept` header when the caller's headers have none
# + return - A new map holding the caller's headers and an `Accept` header
isolated function prepareHeaders(map<string|string[]>? headers, boolean defaultAccept = true)
        returns map<string|string[]> {
    map<string|string[]> headersModified = copyHeaders(headers);
    foreach string key in headersModified.keys() {
        if !key.equalsIgnoreCaseAscii(ACCEPT_HEADER) {
            continue;
        }
        string|string[] value = headersModified.get(key);
        string[] allValues = [];
        if value is string {
            allValues.push(value);
        } else {
            allValues = value;
        }
        string[] values = allValues.filter(v => v.trim() != "");
        if values.length() == 0 {
            _ = headersModified.remove(key);
        } else if value is string[] {
            headersModified[key] = values;
        }
    }
    if defaultAccept && !hasHeader(headersModified, ACCEPT_HEADER) {
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
    }
    return headersModified;
}

# Checks whether the headers of an `http:Request` have a non-empty value for a header.
#
# + headers - The headers of the request
# + name - The header name
# + return - `true` if there is a non-empty value for the header
isolated function hasHeaderValue(map<string[]> headers, string name) returns boolean {
    foreach [string, string[]] [key, values] in headers.entries() {
        if key.equalsIgnoreCaseAscii(name) && values.some(v => v.trim() != "") {
            return true;
        }
    }
    return false;
}

# The headers and the payload of an `http:Request` message, from which the request of each attempt is built.
type RequestSnapshot record {|
    # The headers of the request, except `Content-Type` when the request has a payload
    map<string[]> headers;
    # The payload: the bytes of the body, or the body parts of a multipart request
    byte[]|mime:Entity[]? payload;
    # The content type of the request, or an empty string
    string contentType;
|};

# Reads the headers and the payload of the caller's `http:Request`, so that the request itself is never sent. A
# stream payload is read into memory, as a stream can be read only once.
#
# + request - The caller's request
# + return - The headers and the payload, or an `sap:ClientError` if a stream payload fails
isolated function snapshotRequest(http:Request request) returns RequestSnapshot|ClientError {
    string contentType = request.getContentType();
    byte[]|mime:Entity[]? payload = ();
    // Only a payload set with `setByteStream` is returned as a stream, whatever its content type (an OData `$batch`
    // body is a stream with a `multipart/mixed` content type).
    stream<byte[], io:Error?>|http:ClientError payloadStream = request.getByteStream();
    if payloadStream is stream<byte[], io:Error?> {
        payload = check readStream(payloadStream);
    } else if contentType.toLowerAscii().startsWith("multipart/") {
        mime:Entity[]|http:ClientError bodyParts = request.getBodyParts();
        payload = bodyParts is mime:Entity[] ? bodyParts : ();
    } else {
        byte[]|http:ClientError bytes = request.getBinaryPayload();
        payload = bytes is byte[] && bytes.length() > 0 ? bytes : ();
    }
    map<string[]> headers = {};
    foreach string name in request.getHeaderNames() {
        if payload !is () && name.equalsIgnoreCaseAscii(mime:CONTENT_TYPE) {
            // Set together with the payload.
            continue;
        }
        string[]|http:HeaderNotFoundError values = request.getHeaders(name);
        if values is string[] {
            headers[name] = values;
        }
    }
    return {headers, payload, contentType};
}

# Returns the body to send on one attempt: a new `http:Request` when the caller passed one, so that each attempt
# starts from the caller's own headers, and otherwise the body itself.
#
# + body - The request body
# + snapshot - The headers and the payload of the caller's `http:Request`, if the body is one
# + return - The body to send
isolated function attemptBody(http:RequestMessage body, RequestSnapshot? snapshot) returns http:RequestMessage {
    if snapshot is () {
        return body;
    }
    http:Request request = new;
    foreach [string, string[]] [name, values] in snapshot.headers.entries() {
        foreach string value in values {
            request.addHeader(name, value);
        }
    }
    byte[]|mime:Entity[]? payload = snapshot.payload;
    string? contentType = snapshot.contentType == "" ? () : snapshot.contentType;
    if payload is byte[] {
        request.setBinaryPayload(payload, contentType);
    } else if payload is mime:Entity[] {
        request.setBodyParts(payload, contentType);
    }
    return request;
}

# Returns the headers a request is sent with when the caller passes an `http:Request` and a `headers` map: the
# headers of the request, replaced by the entries of the map for the same header.
#
# + requestHeaders - The headers of the `http:Request`
# + headers - The `headers` map
# + return - A new map holding both
isolated function mergeHeaders(map<string[]> requestHeaders, map<string|string[]> headers)
        returns map<string|string[]> {
    map<string|string[]> merged = {};
    foreach [string, string[]] [name, values] in requestHeaders.entries() {
        merged[name] = values;
    }
    foreach [string, string|string[]] [name, value] in headers.entries() {
        removeHeader(merged, name);
        merged[name] = value;
    }
    return merged;
}

# Removes a header in any letter case.
#
# + headers - The headers to update in place
# + name - The header name
isolated function removeHeader(map<string|string[]> headers, string name) {
    foreach string key in headers.keys() {
        if key.equalsIgnoreCaseAscii(name) {
            _ = headers.remove(key);
        }
    }
}

# Sets a header, replacing any entry for the same header in another letter case (for example a caller's
# `x-csrf-token` or `authorization`), so that the request never carries two values for it.
#
# + headers - The headers to update in place
# + name - The header name
# + value - The header value
isolated function setHeader(map<string|string[]> headers, string name, string value) {
    removeHeader(headers, name);
    headers[name] = value;
}

# Returns the first value of a header, comparing header names case-insensitively as HTTP does.
#
# + headers - The headers to search
# + name - The header name
# + return - The first value of the header, or `()` if the header is not present
isolated function headerValue(map<string|string[]> headers, string name) returns string? {
    foreach [string, string|string[]] [key, value] in headers.entries() {
        if key.equalsIgnoreCaseAscii(name) {
            if value is string {
                return value;
            }
            return value.length() > 0 ? value[0] : "";
        }
    }
    return ();
}

# Checks whether a header is present, comparing header names case-insensitively as HTTP does.
#
# + headers - The headers to check
# + name - The header name
# + return - `true` if the header is present
isolated function hasHeader(map<string|string[]> headers, string name) returns boolean {
    return headerValue(headers, name) is string;
}

const SAP_CLIENT = "sap-client";
const SCC_LOCATION_ID_HEADER = "SAP-Connectivity-SCC-Location_ID";
const PROXY_AUTHORIZATION_HEADER = "Proxy-Authorization";

// The number of CSRF tokens kept, one per SAP session the client has sent modifying requests to.
const int MAX_CACHED_CSRF_TOKENS = 100;

// Request headers that are not sent on the CSRF token fetch: they describe the request body, make the request
// conditional or change its method, none of which applies to the `HEAD` request that fetches the token.
final readonly & string[] TOKEN_FETCH_EXCLUDED_HEADERS = [
    "accept",
    "content-encoding",
    "content-length",
    "content-type",
    "expect",
    "if-match",
    "if-modified-since",
    "if-none-match",
    "if-range",
    "if-unmodified-since",
    "transfer-encoding",
    "x-csrf-token",
    "x-http-method",
    "x-http-method-override"
];

# Returns the request headers to send on the CSRF token fetch.
#
# + requestHeaders - The headers of the request the token is for
# + return - A new map holding the headers to send on the token fetch
isolated function tokenFetchHeaders(map<string|string[]> requestHeaders) returns map<string|string[]> {
    map<string|string[]> fetchHeaders = {};
    foreach [string, string|string[]] [name, value] in requestHeaders.entries() {
        if TOKEN_FETCH_EXCLUDED_HEADERS.indexOf(name.toLowerAscii()) is () {
            fetchHeaders[name] = value;
        }
    }
    return fetchHeaders;
}

# Returns the `sap-client` query parameter of a request path, if it has one.
#
# + path - The request path, including its query parameters
# + return - The value of the `sap-client` query parameter, or `()`
isolated function sapClientQueryParam(string path) returns string? {
    int? queryStart = path.indexOf("?");
    if queryStart is () {
        return ();
    }
    foreach string param in re `&`.split(path.substring(queryStart + 1)) {
        int? separator = param.indexOf("=");
        if separator is int && param.substring(0, separator).equalsIgnoreCaseAscii(SAP_CLIENT) {
            return param.substring(separator + 1);
        }
    }
    return ();
}

# Returns the key a CSRF token is cached under. A token belongs to an SAP session, which is selected by the SAP
# client, the Cloud Connector location the SAP BTP Connectivity proxy routes the request to, and the user the
# request is sent for (the caller's `Authorization` and `Proxy-Authorization` headers, kept only as a hash).
#
# + requestHeaders - The headers of the request the token is for
# + sapClientInQuery - The `sap-client` query parameter of the request, used when there is no such header
# + includeAuthorization - Whether the `Authorization` header identifies the user
# + return - The cache key
isolated function csrfSessionKey(map<string|string[]> requestHeaders, string? sapClientInQuery,
        boolean includeAuthorization) returns string {
    string sapClient = headerValue(requestHeaders, SAP_CLIENT) ?: sapClientInQuery ?: "";
    string location = headerValue(requestHeaders, SCC_LOCATION_ID_HEADER) ?: "";
    string user = (includeAuthorization ? headerValue(requestHeaders, AUTHORIZATION_HEADER) ?: "" : "") + "|" +
        (headerValue(requestHeaders, PROXY_AUTHORIZATION_HEADER) ?: "");
    string userKey = user == "|" ? "" : crypto:hashSha256(user.toBytes()).toBase16();
    return string `${sapClient}|${location}|${userKey}`;
}

# Makes a stream body safe to send twice. A request may be sent a second time, after its CSRF token or SAML Bearer
# token is refreshed, and a stream can be read only once, so it would otherwise be resent empty. A stream body is
# read into memory. Other bodies can already be resent and are returned as they are.
#
# + message - The request body
# + return - The request body, or an `sap:ClientError` if the stream fails
isolated function bufferStreamBody(http:RequestMessage message) returns http:RequestMessage|ClientError {
    if message is stream<byte[], io:Error?> {
        return readStream(message);
    }
    return message;
}

# Reads a byte stream to its end.
#
# + byteStream - The stream to read
# + return - The bytes of the stream, or an `sap:ClientError` if the stream fails
isolated function readStream(stream<byte[], io:Error?> byteStream) returns byte[]|ClientError {
    byte[] body = [];
    record {|byte[] value;|}|io:Error? chunk = byteStream.next();
    while chunk is record {|byte[] value;|} {
        body.push(...chunk.value);
        chunk = byteStream.next();
    }
    if chunk is io:Error {
        // Release the source (for example a file) of a stream that failed midway.
        io:Error? closeResult = byteStream.close();
        if closeResult is io:Error {
            // The read error below is the one to report.
        }
        return error ClientError("Failed to read the request body stream", chunk);
    }
    return body;
}
