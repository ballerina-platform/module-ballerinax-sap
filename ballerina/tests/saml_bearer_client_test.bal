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
import ballerina/io;
import ballerina/test;

// Exercises Client's SAML Bearer auth-header-injection and 401-retry logic end to end,
// through the real (native-bound) Client - not a hand-mirrored reproduction.

isolated int samlTokenIssueCount = 0;
isolated int samlGetRequestCount = 0;
isolated int samlPostRequestCount = 0;
isolated int basicAuthRequestCount = 0;

isolated function nextSamlTokenNumber() returns int {
    lock {
        samlTokenIssueCount += 1;
        return samlTokenIssueCount;
    }
}

isolated function nextSamlGetRequestNumber() returns int {
    lock {
        samlGetRequestCount += 1;
        return samlGetRequestCount;
    }
}

isolated function nextSamlPostRequestNumber() returns int {
    lock {
        samlPostRequestCount += 1;
        return samlPostRequestCount;
    }
}

isolated function nextBasicAuthRequestNumber() returns int {
    lock {
        basicAuthRequestCount += 1;
        return basicAuthRequestCount;
    }
}

listener http:Listener samlMockTenantListener = new (9098);

service /oauth on samlMockTenantListener {
    resource function post token(http:Request req) returns json {
        int n = nextSamlTokenNumber();
        return {"access_token": string `saml-mock-token-${n}`, "token_type": "Bearer", "expires_in": 86400};
    }
}

service /api on samlMockTenantListener {
    resource function head .(http:Request req) returns http:Response {
        http:Response resp = new;
        resp.setHeader("X-CSRF-TOKEN", "mock-csrf-token");
        return resp;
    }

    resource function get 'resource(http:Request req) returns http:Response|error {
        int n = nextSamlGetRequestNumber();
        string authHeader = check req.getHeader("Authorization");
        http:Response resp = new;
        if n == 1 {
            // Simulates a cached-but-now-stale token, forcing the refresh-and-retry path.
            resp.statusCode = 401;
            return resp;
        }
        resp.statusCode = 200;
        resp.setJsonPayload({seenAuth: authHeader});
        return resp;
    }

    resource function post 'resource(http:Request req) returns http:Response|error {
        int n = nextSamlPostRequestNumber();
        string authHeader = check req.getHeader("Authorization");
        http:Response resp = new;
        if n == 1 {
            resp.statusCode = 401;
            return resp;
        }
        resp.statusCode = 201;
        resp.setJsonPayload({seenAuth: authHeader});
        return resp;
    }
}

isolated function newSamlTestConfig() returns SamlBearerAuthConfig => {
    apiKey: "testApiKey",
    companyId: "testCompanyId",
    username: "testuser",
    privateKey: "tests/resources/saml_test_key.pem",
    certificate: "tests/resources/saml_test_cert.pem",
    tokenUrl: "http://localhost:9098/oauth/token"
};

@test:Config {}
function testSamlBearerGetRetriesOnceOn401() returns error? {
    Client samlClient = check new ("http://localhost:9098/api", {auth: newSamlTestConfig()});
    json result = check samlClient->get("/resource");
    map<json> resultMap = <map<json>>result;
    string seenAuth = <string>resultMap["seenAuth"];
    test:assertTrue(seenAuth.startsWith("Bearer saml-mock-token-"),
            "GET should succeed after the 401-triggered token refresh and retry, carrying the refreshed token");
}

@test:Config {}
function testSamlBearerPostRetriesOnceOn401() returns error? {
    Client samlClient = check new ("http://localhost:9098/api", {auth: newSamlTestConfig()});
    json result = check samlClient->post("/resource", "payload");
    map<json> resultMap = <map<json>>result;
    string seenAuth = <string>resultMap["seenAuth"];
    test:assertTrue(seenAuth.startsWith("Bearer saml-mock-token-"),
            "POST should succeed after the 401-triggered token refresh and retry, carrying the refreshed token");
}

@test:Config {}
function testBasicAuthClientDoesNotRetryOnSamlPathFor401() returns error? {
    Client basicAuthClient = check new ("http://localhost:9098/api", {auth: {username: "u", password: "p"}});

    // A 401 here is a real auth failure (wrong credentials), not a stale-SAML-token situation -
    // isSAMLAuthFailure should short-circuit to false since this client has no SamlBearerAuthConfig,
    // so there should be no retry: the mock should see exactly one more request, not two.
    int before = 0;
    lock {
        before = samlGetRequestCount;
    }
    json|error result = basicAuthClient->get("/resource");
    test:assertTrue(result is error, "a 401 should surface as an error");
    int 'after = 0;
    lock {
        'after = samlGetRequestCount;
    }
    test:assertEquals('after - before, 1, "a non-SAML client should not retry on 401 - the mock should be hit exactly once more");
}

@test:Config {}
function testPredecodedPrivateKeyRejectedWithClearError() returns error? {
    crypto:PrivateKey predecodedKey = check crypto:decodeRsaPrivateKeyFromKeyFile("tests/resources/saml_test_key.pem");
    string certPem = check io:fileReadString("tests/resources/saml_test_cert.pem");

    Client|error result = new ("http://localhost:9098/api", {
        auth: {
            apiKey: "testApiKey",
            companyId: "testCompanyId",
            username: "testuser",
            privateKey: predecodedKey,
            certificate: certPem,
            tokenUrl: "http://localhost:9098/oauth/token"
        }
    });

    test:assertTrue(result is error, "a pre-decoded crypto:PrivateKey should be rejected, not silently accepted and corrupted later");
    if result is error {
        test:assertTrue(result.message().includes("file path"),
                "error message should explain the file-path requirement");
    }
}
