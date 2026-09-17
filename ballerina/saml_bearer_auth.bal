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
import ballerina/time;
import ballerina/url;
import ballerina/uuid;

# Obtains an OAuth 2.0 access token via the SAML 2.0 Bearer Assertion Flow
# ([RFC 7522](https://www.rfc-editor.org/rfc/rfc7522)): builds a SAML assertion, signs it, and
# exchanges it at the tenant's OAuth2 token endpoint. Invoked by `Client` on demand (on init and
# whenever a request comes back `401`) - `secureSocket`/`proxy` are the same values the calling
# `Client` was configured with, so the token exchange trusts/routes the same way its other
# requests do.
isolated function getSamlBearerAccessToken(SamlBearerAuthConfig config, http:ClientSecureSocket? secureSocket = (),
        http:ProxyConfig? proxy = ()) returns SamlBearerToken|ClientError {
    do {
        crypto:PrivateKey privateKey = config.privateKey is string
            ? check crypto:decodeRsaPrivateKeyFromKeyFile(<string>config.privateKey)
            : <crypto:PrivateKey>config.privateKey;
        string certificatePem = check resolveCertificate(config.certificate);
        string certificateBase64 = stripPemHeaders(certificatePem);

        time:Utc now = time:utcNow();
        string issueInstant = toUtcSecondsString(now);
        string notBefore = toUtcSecondsString(time:utcAddSeconds(now, -config.validityPeriod));
        string notOnOrAfter = toUtcSecondsString(time:utcAddSeconds(now, config.validityPeriod));
        string assertionId = "_" + uuid:createRandomUuid();
        string recipient = check getHostFromUrl(config.tokenUrl);

        string assertionXml = buildAssertionXml(
            assertionId = assertionId,
            issueInstant = issueInstant,
            notBefore = notBefore,
            notOnOrAfter = notOnOrAfter,
            issuer = config.apiKey,
            subjectNameId = config.username,
            recipient = recipient
        );

        string signedAssertion = check signAssertion(assertionXml, assertionId, certificateBase64, privateKey);
        string assertionBase64 = signedAssertion.toBytes().toBase64();

        http:Client tokenClient = check new (config.tokenUrl, {secureSocket, proxy});
        string requestBody = string `client_id=${check url:encode(config.apiKey, "UTF-8")}` +
            string `&company_id=${check url:encode(config.companyId, "UTF-8")}` +
            string `&grant_type=${check url:encode("urn:ietf:params:oauth:grant-type:saml2-bearer", "UTF-8")}` +
            string `&assertion=${check url:encode(assertionBase64, "UTF-8")}`;
        http:Response response = check tokenClient->post("", requestBody,
                {"Content-Type": "application/x-www-form-urlencoded"});
        json payload = check response.getJsonPayload();
        if response.statusCode < 200 || response.statusCode >= 300 {
            return error ClientError("SAML Bearer token exchange failed", statusCode = response.statusCode, body = payload);
        }
        string accessToken = check payload.access_token.ensureType(string);
        decimal expiresIn = 3600;
        json|error expiresInField = payload.expires_in;
        if expiresInField is int {
            expiresIn = <decimal>expiresInField;
        } else if expiresInField is decimal {
            expiresIn = expiresInField;
        }
        return {accessToken, expiresIn};
    } on fail error e {
        return error ClientError("Failed to obtain an OAuth2 access token via the SAML Bearer flow", e);
    }
}

isolated function resolveCertificate(string certificate) returns string|error {
    string trimmed = certificate.trim();
    if trimmed.startsWith("-----BEGIN") {
        return certificate;
    }
    return check io:fileReadString(certificate);
}

isolated function toUtcSecondsString(time:Utc utc) returns string {
    string full = time:utcToString(utc);
    return full.substring(0, 19) + "Z";
}

isolated function getHostFromUrl(string tokenUrl) returns string|error {
    // tokenUrl looks like https://<host>/oauth/token - extract just the host for the SAML
    // Recipient/Audience-adjacent fields that reference the token endpoint's host.
    int? schemeEnd = tokenUrl.indexOf("://");
    if schemeEnd is () {
        return error("Invalid token URL: " + tokenUrl);
    }
    string afterScheme = tokenUrl.substring(schemeEnd + 3);
    int? pathStart = afterScheme.indexOf("/");
    return pathStart is () ? afterScheme : afterScheme.substring(0, pathStart);
}

isolated function buildAssertionXml(string assertionId, string issueInstant, string notBefore,
        string notOnOrAfter, string issuer, string subjectNameId, string recipient) returns string {
    return string `<saml2:Assertion xmlns:saml2="urn:oasis:names:tc:SAML:2.0:assertion" ID="${assertionId}" IssueInstant="${issueInstant}" Version="2.0">
  <saml2:Issuer>${issuer}</saml2:Issuer>
  <saml2:Subject>
    <saml2:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified">${subjectNameId}</saml2:NameID>
    <saml2:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
      <saml2:SubjectConfirmationData NotOnOrAfter="${notOnOrAfter}" Recipient="https://${recipient}/oauth/token"></saml2:SubjectConfirmationData>
    </saml2:SubjectConfirmation>
  </saml2:Subject>
  <saml2:Conditions NotBefore="${notBefore}" NotOnOrAfter="${notOnOrAfter}">
    <saml2:AudienceRestriction><saml2:Audience>www.successfactors.com</saml2:Audience></saml2:AudienceRestriction>
  </saml2:Conditions>
  <saml2:AuthnStatement AuthnInstant="${issueInstant}">
    <saml2:AuthnContext><saml2:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml2:AuthnContextClassRef></saml2:AuthnContext>
  </saml2:AuthnStatement>
</saml2:Assertion>`;
}

# Signs the assertion with an enveloped, Exclusive-C14N RSA-SHA256 XML-DSig signature and splices
# it in immediately after `<saml2:Issuer>`, matching the SAML Assertion schema's required element
# order (`Issuer`, `Signature?`, `Subject?`, ...).
#
# No general-purpose XML canonicalization library is used: every element in `assertionXml` and in
# the `SignedInfo` block below is written without self-closing tags, so each is already in its own
# canonical form and the literal bytes can be hashed/signed directly.
#
# + assertionXml - The unsigned assertion XML, as built by `buildAssertionXml`
# + assertionId - The assertion's `ID` attribute, referenced by the signature's `Reference URI`
# + certificateBase64 - The base64 DER of the X.509 certificate to embed in `KeyInfo`
# + privateKey - The private key to sign with
# + return - The signed assertion XML, or an error if signing failed
isolated function signAssertion(string assertionXml, string assertionId, string certificateBase64,
        crypto:PrivateKey privateKey) returns string|error {
    byte[] digestBytes = crypto:hashSha256(assertionXml.toBytes());
    string digestBase64 = digestBytes.toBase64();

    string signedInfo = string `<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">` +
        string `<ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:CanonicalizationMethod>` +
        string `<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"></ds:SignatureMethod>` +
        string `<ds:Reference URI="#${assertionId}"><ds:Transforms>` +
        string `<ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></ds:Transform>` +
        string `<ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:Transform></ds:Transforms>` +
        string `<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"></ds:DigestMethod>` +
        string `<ds:DigestValue>${digestBase64}</ds:DigestValue></ds:Reference></ds:SignedInfo>`;

    byte[] signatureBytes = check crypto:signRsaSha256(signedInfo.toBytes(), privateKey);
    string signatureBase64 = signatureBytes.toBase64();

    string signatureBlock = string `<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">${signedInfo}` +
        string `<ds:SignatureValue>${signatureBase64}</ds:SignatureValue><ds:KeyInfo><ds:X509Data>` +
        string `<ds:X509Certificate>${certificateBase64}</ds:X509Certificate></ds:X509Data></ds:KeyInfo></ds:Signature>`;

    string marker = "</saml2:Issuer>";
    int? idx = assertionXml.indexOf(marker);
    if idx is () {
        return error("Assertion template is missing the expected <saml2:Issuer> element");
    }
    int insertAt = idx + marker.length();
    return assertionXml.substring(0, insertAt) + signatureBlock + assertionXml.substring(insertAt);
}

isolated function stripPemHeaders(string pem) returns string {
    string[] lines = re `\n`.split(pem);
    string result = "";
    foreach string line in lines {
        string trimmed = line.trim();
        if trimmed.startsWith("-----") || trimmed.length() == 0 {
            continue;
        }
        result += trimmed;
    }
    return result;
}
