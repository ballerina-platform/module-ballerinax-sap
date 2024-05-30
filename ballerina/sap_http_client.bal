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

# The `sap` client provides the capability for initiating contact with a remote HTTP service provided by any SAP products. The API it
# provides includes the functions for the standard HTTP methods.
public client isolated class Client {

    final http:Client httpClient;
    private string? csrfToken = ();

    # Gets invoked to initialize the `client`. During initialization, the configurations provided through the `config`
    # record is used to determine which type of additional behaviours are added to the endpoint (e.g.
    # security, circuit breaking). Caching is enabled always.
    #
    # + url - URL of the target service
    # + config - The configurations to be used when initializing the `client`
    # + return - The `client` or an `sap:ClientError` if the initialization failed
    public isolated function init(string url, http:ClientConfiguration config) returns ClientError? {
        config.cookieConfig = {
            enabled: true
        };
        self.httpClient = check new (url, config);
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
            mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
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
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPost(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        http:Response|anydata|ClientError response = self.httpClient->post(path, message, headersModified, mediaType, targetType);
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
            mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
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
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPut(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        http:Response|anydata|ClientError response = self.httpClient->put(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
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
            string? mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
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
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processPatch(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        http:Response|anydata|ClientError response = self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
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
            string? mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
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
            map<string|string[]>? headers = (), string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processDelete(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = mime:APPLICATION_JSON;
        http:Response|anydata|ClientError response = self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
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
    isolated resource function get [http:PathParamType... path](map<string|string[]>? headers = (), http:TargetType targetType = <>,
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
    remote isolated function get(string path, map<string|string[]>? headers = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processGet(string path, map<string|string[]>? headers, http:TargetType targetType)
            returns http:Response|anydata|error {
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
    isolated resource function options [http:PathParamType... path](map<string|string[]>? headers = (), http:TargetType targetType = <>,
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
    remote isolated function options(string path, map<string|string[]>? headers = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.ClientAction"
    } external;

    private isolated function processOptions(string path, map<string|string[]>? headers, http:TargetType targetType)
            returns http:Response|anydata|ClientError {
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

isolated function isCSRFTokenFailure(http:Response|anydata|ClientError response) returns boolean {
    if response is http:Response {
        if response.statusCode == http:STATUS_FORBIDDEN {
            string|http:HeaderNotFoundError header = response.getHeader(SAP_CSRF_HEADER);
            if header is string && header.equalsIgnoreCaseAscii(SAP_CSRF_TOKEN_FAILURE_HEADER_VALUE) {
                return true;
            }
        }
    }
    return false;
}
