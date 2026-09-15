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
import ballerina/lang.array;
import ballerina/test;
import ballerina/url;

// Captured from the last request the mock token endpoint received, for assertion-shape checks.
isolated string capturedAssertionXml = "";

isolated function setCapturedAssertion(string assertion) {
    lock {
        capturedAssertionXml = assertion;
    }
}

isolated function getCapturedAssertion() returns string {
    lock {
        return capturedAssertionXml;
    }
}

listener http:Listener mockTokenListener = new (9094);

service /oauth on mockTokenListener {
    resource function post token(http:Request req) returns json|error {
        string body = check req.getTextPayload();
        string[] pairs = re `&`.split(body);
        string assertionB64 = "";
        foreach string pair in pairs {
            if pair.startsWith("assertion=") {
                assertionB64 = check url:decode(pair.substring(10), "UTF-8");
            }
        }
        byte[] decoded = check array:fromBase64(assertionB64);
        setCapturedAssertion(check string:fromBytes(decoded));
        return {"access_token": "mock-access-token-value", "token_type": "Bearer", "expires_in": 86400};
    }
}

@test:Config {}
function testGetSamlBearerAccessTokenReturnsAccessToken() returns error? {
    crypto:PrivateKey privateKey = check crypto:decodeRsaPrivateKeyFromKeyFile("tests/resources/saml_test_key.pem");
    string certPem = check io:fileReadString("tests/resources/saml_test_cert.pem");

    SamlBearerAuthConfig config = {
        clientId: "testClientId",
        companyId: "testCompanyId",
        username: "testuser",
        privateKey: privateKey,
        certificate: certPem,
        tokenUrl: "http://localhost:9094/oauth/token"
    };

    SamlBearerToken token = check getSamlBearerAccessToken(config);
    test:assertEquals(token.accessToken, "mock-access-token-value");
    test:assertEquals(token.expiresIn, <decimal>86400);
}

@test:Config {
    dependsOn: [testGetSamlBearerAccessTokenReturnsAccessToken]
}
function testAssertionSignatureIsVerifiable() returns error? {
    string signedAssertion = getCapturedAssertion();
    test:assertTrue(signedAssertion.length() > 0, "mock endpoint should have captured an assertion");

    crypto:PublicKey publicKey = check crypto:decodeRsaPublicKeyFromCertFile("tests/resources/saml_test_cert.pem");

    // Extract the DigestValue and SignatureValue the way this module writes them, then
    // independently re-derive the digest and verify the signature - proving the emitted
    // assertion is a genuinely valid, verifiable XML-DSig signed SAML assertion.
    string digestValue = check extractBetween(signedAssertion, "<ds:DigestValue>", "</ds:DigestValue>");
    string signatureValue = check extractBetween(signedAssertion, "<ds:SignatureValue>", "</ds:SignatureValue>");
    string signedInfo = check extractBetween(signedAssertion, "<ds:SignedInfo", "</ds:SignedInfo>");
    signedInfo = "<ds:SignedInfo" + signedInfo + "</ds:SignedInfo>";

    // Re-derive the assertion-minus-signature bytes (enveloped-signature transform) to check the digest.
    int sigStart = check indexOfOrError(signedAssertion, "<ds:Signature ");
    int sigEnd = check indexOfOrError(signedAssertion, "</ds:Signature>") + "</ds:Signature>".length();
    string assertionWithoutSignature = signedAssertion.substring(0, sigStart) + signedAssertion.substring(sigEnd);

    byte[] recomputedDigest = crypto:hashSha256(assertionWithoutSignature.toBytes());
    test:assertEquals(recomputedDigest.toBase64(), digestValue, "digest over the enveloped-signature-stripped assertion should match DigestValue");

    byte[] signatureBytes = check array:fromBase64(signatureValue);
    boolean isValid = check crypto:verifyRsaSha256Signature(signedInfo.toBytes(), signatureBytes, publicKey);
    test:assertTrue(isValid, "SignatureValue should verify against SignedInfo using the test certificate's public key");
}

isolated function extractBetween(string text, string startMarker, string endMarker) returns string|error {
    int? startIdx = text.indexOf(startMarker);
    if startIdx is () {
        return error("marker not found: " + startMarker);
    }
    int contentStart = startIdx + startMarker.length();
    int? endIdx = text.indexOf(endMarker, contentStart);
    if endIdx is () {
        return error("end marker not found: " + endMarker);
    }
    return text.substring(contentStart, endIdx);
}

isolated function indexOfOrError(string text, string marker) returns int|error {
    int? idx = text.indexOf(marker);
    if idx is () {
        return error("marker not found: " + marker);
    }
    return idx;
}
