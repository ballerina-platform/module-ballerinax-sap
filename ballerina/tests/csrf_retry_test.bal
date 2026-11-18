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

import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/mime;
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
        string[]|http:HeaderNotFoundError tokens = req.getHeaders("X-CSRF-Token");
        if tokens is string[] && tokens.length() > 1 {
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setTextPayload("more than one X-CSRF-Token header");
            return response;
        }
        if firstAttempt || headerOf(req, "X-CSRF-Token") != string `token-${sapClient}` {
            response.statusCode = http:STATUS_FORBIDDEN;
            response.setHeader("X-Csrf-Token", "Required");
            return response;
        }
        if req.getContentType().startsWith("multipart/") {
            mime:Entity[] parts = check req.getBodyParts();
            response.setTextPayload(string `parts:${parts.length()}`);
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

@test:Config {}
function testFileStreamBodyIsResentOnRetry() returns error? {
    string path = check file:createTemp();
    check io:fileWriteString(path, "hello from a file");
    stream<io:Block, io:Error?> body = check io:fileReadBlocksAsStream(path, 4);
    string received = check csrfClient->post("/filestream", body);
    test:assertEquals(received, "17", "The retried request did not carry the file stream body");
    check file:remove(path);
}

class FailingStream {
    private int calls = 0;

    public isolated function next() returns record {|byte[] value;|}|io:Error? {
        self.calls += 1;
        if self.calls == 1 {
            return {value: [1, 2, 3]};
        }
        return error io:GenericError("the body source failed");
    }
}

@test:Config {}
function testFailingStreamBodyReturnsAnError() {
    stream<byte[], io:Error?> body = new (new FailingStream());
    string|ClientError received = csrfClient->post("/failingstream", body);
    test:assertTrue(received is ClientError, "A failing body stream must fail the call instead of sending a partial body");
}

@test:Config {}
function testCallerCsrfHeaderInAnotherCaseIsReplaced() returns error? {
    // The client's own token must be the only X-CSRF-Token value, whatever casing the caller used.
    string received = check csrfClient->post("/callertoken", "x", {"x-csrf-token": "from-the-caller"});
    test:assertEquals(received, "1");
}

@test:Config {}
function testRequestWithStreamPayloadOnRetry() returns error? {
    http:Request request = new;
    byte[][] chunks = [[104, 101], [108, 108, 111]];
    request.setByteStream(chunks.toStream());
    string received = check csrfClient->post("/requeststream", request);
    test:assertEquals(received, "5", "The retried http:Request did not carry its stream payload");
}

@test:Config {}
function testMultipartBodyOnRetry() returns error? {
    mime:Entity part = new;
    part.setText("hello");
    mime:Entity[] parts = [part];
    string received = check csrfClient->post("/multipart", parts);
    test:assertEquals(received, "parts:1", "The retried multipart request did not carry its parts");
}

@test:Config {}
function testRequestPayloadAndContentTypeAreKeptOnRetry() returns error? {
    http:Request request = new;
    request.setJsonPayload({message: "hello"}, "application/json; charset=utf-8");
    string received = check csrfClient->post("/requestjson", request);
    test:assertEquals(received, "19");
    test:assertTrue(request.getContentType().startsWith("application/json"));

    http:Request text = new;
    text.setTextPayload("hello");
    received = check csrfClient->post("/requesttext", text);
    test:assertEquals(received, "5");

    http:Request empty = new;
    received = check csrfClient->post("/requestempty", empty);
    test:assertEquals(received, "0");
}

@test:Config {}
function testBatchRequestStreamIsResentOnRetry() returns error? {
    // An OData $batch body: a stream whose content type is multipart/mixed. The fake service answers with the
    // number of batch parts it could decode, which is none when the body is missing.
    string batch = "--batch_1\r\nContent-Type: application/http\r\n\r\nGET A_SalesOrder HTTP/1.1\r\n\r\n\r\n--batch_1--\r\n";
    http:Request request = new;
    byte[][] chunks = [batch.toBytes()];
    request.setByteStream(chunks.toStream(), "multipart/mixed; boundary=batch_1");
    string received = check csrfClient->post("/batchrequest", request);
    test:assertEquals(received, "parts:1", "The retried $batch request did not carry its body");
    test:assertTrue(request.getContentType().startsWith("multipart/mixed"), request.getContentType());

    stream<byte[], io:Error?> body = [batch.toBytes()].toStream();
    received = check csrfClient->post("/batchstream", body, mediaType = "multipart/mixed; boundary=batch_1");
    test:assertEquals(received, "parts:1", "The retried $batch stream did not carry its body");
}
