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

import ballerina/http;
import ballerina/io;
import ballerina/test;

// Paths that have already been rejected once. The fake service answers the first POST to each path with
// `403 X-Csrf-Token: Required`, like an SAP system whose session (and so its CSRF token) has expired.
isolated map<boolean> rejectedPaths = {};

// The `sap-client` and Cloud Connector location ID of every token fetch, in order.
isolated string[] tokenFetches = [];

isolated function headerOf(http:Request req, string name) returns string {
    string|http:HeaderNotFoundError value = req.getHeader(name);
    return value is string ? value : "";
}

isolated function recordedTokenFetches() returns string[] {
    lock {
        return tokenFetches.clone();
    }
}

// A fake SAP endpoint. A token is issued per `sap-client`, and a request is only accepted with the token of its own
// `sap-client`. The failure header is sent as `X-Csrf-Token`, in a casing other than the client's `X-CSRF-TOKEN`.
service /csrf on new http:Listener(9405) {
    resource function head .(http:Request req) returns http:Response {
        string sapClient = headerOf(req, "sap-client");
        string location = headerOf(req, "SAP-Connectivity-SCC-Location_ID");
        lock {
            tokenFetches.push(string `${sapClient}|${location}`);
        }
        http:Response response = new;
        response.setHeader("X-Csrf-Token", string `token-${sapClient}`);
        return response;
    }

    resource function post [string... path](http:Request req) returns http:Response|error {
        string sapClient = headerOf(req, "sap-client");
        string key = string `${string:'join("/", ...path)}|${sapClient}`;
        boolean firstAttempt;
        lock {
            firstAttempt = !rejectedPaths.hasKey(key);
            rejectedPaths[key] = true;
        }
        http:Response response = new;
        if firstAttempt || headerOf(req, "X-CSRF-Token") != string `token-${sapClient}` {
            response.statusCode = http:STATUS_FORBIDDEN;
            response.setHeader("X-Csrf-Token", "Required");
            return response;
        }
        byte[] body = check req.getBinaryPayload();
        response.setTextPayload(body.length().toString());
        return response;
    }
}

final Client csrfClient = check new ("http://localhost:9405/csrf", {
    auth: {username: "testuser", password: "testpassword"}
});

@test:Config {}
function testCsrfRetryForDataBoundTarget() returns error? {
    // A data-bound target surfaces the 403 as an error; the client must still refresh the token and retry.
    string received = check csrfClient->post("/databound", "x");
    test:assertEquals(received, "1");
}

@test:Config {}
function testCsrfRetryForResponseTarget() returns error? {
    http:Response response = check csrfClient->post("/response", "x");
    test:assertEquals(response.statusCode, http:STATUS_OK);
}

@test:Config {}
function testTokenFetchCarriesRoutingHeaders() returns error? {
    map<string> headers = {"sap-client": "100", "SAP-Connectivity-SCC-Location_ID": "loc1"};
    string received = check csrfClient->post("/routed", "x", headers);
    test:assertEquals(received, "1");
    test:assertTrue(recordedTokenFetches().indexOf("100|loc1") !is (),
            string `The token fetch did not carry the routing headers: ${recordedTokenFetches().toString()}`);
}

@test:Config {
    dependsOn: [testTokenFetchCarriesRoutingHeaders]
}
function testTokensAreCachedPerSapClient() returns error? {
    map<string> client100 = {"sap-client": "100", "SAP-Connectivity-SCC-Location_ID": "loc1"};
    map<string> client200 = {"sap-client": "200", "SAP-Connectivity-SCC-Location_ID": "loc1"};
    string received = check csrfClient->post("/routed", "x", client200);
    test:assertEquals(received, "1");
    // The token of sap-client 100 is still cached, so this request needs no new token fetch.
    int fetches = recordedTokenFetches().length();
    received = check csrfClient->post("/routed", "x", client100);
    test:assertEquals(received, "1");
    test:assertEquals(recordedTokenFetches().length(), fetches, "The token of sap-client 100 was fetched again");
}

@test:Config {}
function testStreamBodyIsResentOnRetry() returns error? {
    // The first attempt is rejected for a fresh CSRF token; the retry must carry the whole body again.
    byte[][] chunks = [[104, 101], [108, 108, 111]];
    stream<byte[], io:Error?> body = chunks.toStream();
    string received = check csrfClient->post("/stream", body);
    test:assertEquals(received, "5", "The retried request did not carry the stream body");
}
