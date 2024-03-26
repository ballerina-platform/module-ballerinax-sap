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

public client isolated class HttpClient {

    final http:Client httpClient;
    private string? csrfToken = ();
    private final string acceptHeader;

    public isolated function init(string url, http:ClientConfiguration config,
            string acceptHeader = mime:APPLICATION_JSON) returns ClientError? {
        config.cookieConfig = {
            enabled: true
        };
        self.httpClient = check new (url, config);
        self.acceptHeader = acceptHeader;
        return;
    }

    isolated resource function post [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (), string?
            mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "postResource"
    } external;

    remote isolated function post(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processPost(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
        http:Response|anydata|ClientError response = self.httpClient->post(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
        return response;
    }

    isolated resource function put [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (), string?
            mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "putResource"
    } external;

    remote isolated function put(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processPut(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
        http:Response|anydata|ClientError response = self.httpClient->put(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    isolated resource function patch [http:PathParamType... path](http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "patchResource"
    } external;

    remote isolated function patch(string path, http:RequestMessage message, map<string|string[]>? headers = (),
            string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processPatch(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
        http:Response|anydata|ClientError response = self.httpClient->patch(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    isolated resource function delete [http:PathParamType... path](http:RequestMessage message = (), map<string|string[]>? headers = (),
            string? mediaType = (), http:TargetType targetType = <>, *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "deleteResource"
    } external;

    remote isolated function delete(string path, http:RequestMessage message = (),
            map<string|string[]>? headers = (), string? mediaType = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processDelete(string path, http:RequestMessage message, http:TargetType targetType,
            string? mediaType, map<string|string[]>? headers) returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        string csrfToken = check self.fetchCSRFTokenForModifyingRequest();
        headersModified[SAP_CSRF_HEADER] = csrfToken;
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
        http:Response|anydata|ClientError response = self.httpClient->delete(path, message, headersModified, mediaType, targetType);
        if isCSRFTokenFailure(response) {
            csrfToken = check self.fetchCSRFTokenForModifyingRequest(true);
            headersModified[SAP_CSRF_HEADER] = csrfToken;
            return self.httpClient->post(path, message, headersModified, mediaType, targetType);
        }
        return response;

    }

    isolated resource function head [http:PathParamType... path](map<string|string[]>? headers = (), *http:QueryParams params)
            returns http:Response|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "headResource"
    } external;

    remote isolated function head(string path, map<string|string[]>? headers = ()) returns http:Response|ClientError {
        return self.httpClient->head(path, headers);
    }

    isolated resource function get [http:PathParamType... path](map<string|string[]>? headers = (), http:TargetType targetType = <>,
            *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "getResource"
    } external;

    remote isolated function get(string path, map<string|string[]>? headers = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processGet(string path, map<string|string[]>? headers, http:TargetType targetType)
            returns http:Response|anydata|error {
        map<string|string[]> headersModified = headers ?: {};
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
        return self.httpClient->get(path, headersModified, targetType);
    }

    isolated resource function options [http:PathParamType... path](map<string|string[]>? headers = (), http:TargetType targetType = <>,
            *http:QueryParams params) returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction",
        name: "optionsResource"
    } external;

    remote isolated function options(string path, map<string|string[]>? headers = (), http:TargetType targetType = <>)
            returns targetType|ClientError = @java:Method {
        'class: "io.ballerina.lib.sap.HttpClientAction"
    } external;

    private isolated function processOptions(string path, map<string|string[]>? headers, http:TargetType targetType)
            returns http:Response|anydata|ClientError {
        map<string|string[]> headersModified = headers ?: {};
        headersModified[ACCEPT_HEADER] = self.acceptHeader;
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
            http:Response response = check self.httpClient->head("", headersModified);
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
