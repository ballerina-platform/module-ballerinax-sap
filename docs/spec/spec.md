# Specification: Ballerina SAP Library

_Owners_: @niveathika  
_Reviewers_: @chathurace @RDPerera  
_Created_: 2024/05/30  
_Updated_: 2024/05/30   
_Edition_: Swan Lake  

## Introduction

This is the specification for the SAP library of [Ballerina language](https://ballerina.io/), which provides HTTP client functionalities to consume SAP HTTP APIs.

The SAP library specification has evolved and may continue to evolve in the future. The released versions of the specification can be found under the relevant GitHub tag. 

If you have any feedback or suggestions about the library, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome. Any accepted proposal, which affects the specification is stored under `/docs/proposals`. Proposals under discussion can be found with the label `type/proposal` in GitHub.

The conforming implementation of the specification is released and included in the distribution. Any deviation from the specification is considered a bug.

## Contents

1. [Overview](#1-overview)
2. [Components](#2-components)
    * 2.1. [Client](#21-client)
        * 2.1.1. [Security](#211-security)
        * 2.1.2. [Cookie](#212-cookie)
    * 2.2. [Client action](#22-client-action)
        * 2.2.1. [Entity body methods](#221-entity-body-methods)
        * 2.2.2. [Non entity body methods](#222-non-entity-body-methods)
        * 2.2.3. [Resource methods](#223-resource-methods)
    * 2.3. [Client actions return types](#23-client-action-return-types)

## 1. Overview

The Ballerina language is designed with a focus on network-oriented programming. Leveraging this, the SAP standard library establishes a programming model that simplifies the consumption of SAP HTTP APIs.

## 2. Components

### 2.1. Client

The client enables the application to communicate with a SAP server using the HTTP protocol. Each method of the client object corresponds to a specific network operation as defined by the HTTP protocol.

To initialize the client, you need a valid SAP URL and optional configuration parameters. Here's an example of how to create a new SAP client:

```ballerina
sap:Client sapClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
  auth: {
    username,
    password
  }
});
```

#### 2.1.1 Security

The `sap:Client` provides secure HTTP methods for interacting with SAP's HTTP endpoints.

```ballerina
sap:Client sapClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
  auth: {
    username: username,
    password: password
  },
  secureSocket: {
    cert: {
      path: truststore_path,
      password: "ballerina"
    }
  }
});
```

This client is equipped with built-in CSRF token authentication, ensuring compliance with SAP system security standards.

#### 2.1.2 Cookie

As per SAP's CSRF token authentication requirements, cookie functionality is always enabled.

### 2.2. Client action

The SAP client contains separate remote method representing each HTTP method such as `get`, `put`, `post`,
`delete`,`patch`,`head`,`options` and some custom remote methods.

#### 2.2.1 Entity body methods
 
POST, PUT, DELETE, PATCH methods are considered as entity body methods. These remote methods contains RequestMessage
as the second parameter to send out the Request or Payload. 

```ballerina
public type RequestMessage Request|string|xml|json|byte[]|int|float|decimal|boolean|map<json>|table<map<json>>|
                           (map<json>|table<map<json>>)[]|mime:Entity[]|stream<byte[], io:Error?>|();
```

```ballerina
# The post() function can be used to send HTTP POST requests to HTTP endpoints.
remote isolated function post(string path, RequestMessage message, map<string|string[]>? headers = (),
        string? mediaType = (), TargetType targetType = <>)
        returns targetType|ClientError;

# The put() function can be used to send HTTP PUT requests to HTTP endpoints.
remote isolated function put(string path, RequestMessage message, map<string|string[]>? headers = (),
        string? mediaType = (), TargetType targetType = <>)
        returns targetType|ClientError;

# The patch() function can be used to send HTTP PATCH requests to HTTP endpoints.
remote isolated function patch(string path, RequestMessage message, map<string|string[]>? headers = (),
        string? mediaType = (), TargetType targetType = <>)
        returns targetType|ClientError;

# The delete() function can be used to send HTTP DELETE requests to HTTP endpoints.
remote isolated function delete(string path, RequestMessage message = (), map<string|string[]>? headers = (),
        string? mediaType = (), TargetType targetType = <>)
        returns targetType|ClientError;
```

#### 2.2.2 Non Entity body methods

GET, HEAD, OPTIONS methods are considered as non entity body methods. These remote methods do not contain 
RequestMessage, but the header map an optional param.

```ballerina
# The head() function can be used to send HTTP HEAD requests to HTTP endpoints.
remote isolated function head(string path, map<string|string[]>? headers = ()) returns Response|ClientError;

# The get() function can be used to send HTTP GET requests to HTTP endpoints.
remote isolated function get( string path, map<string|string[]>? headers = (), TargetType targetType = <>)
        returns  targetType|ClientError;

# The options() function can be used to send HTTP OPTIONS requests to HTTP endpoints.
remote isolated function options( string path, map<string|string[]>? headers = (), TargetType targetType = <>)
        returns  targetType|ClientError;
```

#### 2.2.3 Resource methods

In addition to the above remote method actions, SAP client supports executing standard HTTP methods through resource 
methods. The following are the definitions of those resource methods :

```ballerina
# Defines the path parameter types.
public type PathParamType boolean|int|float|decimal|string;

# The post resource method can be used to send HTTP POST requests to HTTP endpoints.
resource function post [PathParamType ...path](RequestMessage message, map<string|string[]>? headers = (), string? mediaType = (),
            TargetType targetType = <>, *QueryParams params) returns targetType|ClientError;

# The put resource method can be used to send HTTP PUT requests to HTTP endpoints.            
resource function put [PathParamType ...path](RequestMessage message, map<string|string[]>? headers = (), string? mediaType = (),
            TargetType targetType = <>, *QueryParams params) returns targetType|ClientError;

# The patch resource method can be used to send HTTP PATCH requests to HTTP endpoints.              
resource function patch [PathParamType ...path](RequestMessage message, map<string|string[]>? headers = (), string? mediaType = (),
            TargetType targetType = <>, *QueryParams params) returns targetType|ClientError;

# The delete resource method can be used to send HTTP DELETE requests to HTTP endpoints.              
resource function delete [PathParamType ...path](RequestMessage message = (), map<string|string[]>? headers = (), string? mediaType = (),
            TargetType targetType = <>, *QueryParams params) returns targetType|ClientError;

# The head resource method can be used to send HTTP HEAD requests to HTTP endpoints.              
resource function head [PathParamType ...path](map<string|string[]>? headers = (), *QueryParams params)
            returns Response|ClientError; 

# The get resource method can be used to send HTTP GET requests to HTTP endpoints.              
resource function get [PathParamType ...path](map<string|string[]>? headers = (), TargetType targetType = <>,
            *QueryParams params) returns targetType|ClientError;

# The options resource method can be used to send HTTP OPTIONS requests to HTTP endpoints.              
resource function options [PathParamType ...path](map<string|string[]>? headers = (), TargetType targetType = <>,
            *QueryParams params) returns targetType|ClientError;                                               
```

* Path parameter

Path parameters can be specified in the resource invocation along with the type.
The supported types are `string`, `int`, `float`, `boolean`, and `decimal`.

```ballerina
// Making a GET request
string salesOrder = "1";
sap:Client sapClient = check new (string `https://${hostname}/sap/opu/odata/sap/API_SALES_ORDER_SRV`, {
    auth: {
        username,
        password
    }
});

json salesOrder = check sapClient->/A_SalesOrder/${salesOrder}();

// Same as the following :
json salesOrder = check sapClient->get(string `/A_SalesOrder/${salesOrder}`);
```

* Query parameter

A query parameter is passed as a key-value pair in the resource method call.
The supported types are `string`, `int`, `float`, `boolean`, `decimal`, and the `array` types of the aforementioned types.
The query param type can be nil as well.
```ballerina
// Making a GET request
json salesOrder = check sapClient->/A_SalesOrder/${salesOrder}(limit = 2);

// Same as the following :
json salesOrder = check sapClient->get(string `/A_SalesOrder/${salesOrder}?limit=2`);
```

### 2.3. Client action return types

The SAP client remote method supports the contextually expected return types. The client operation is able to 
infer the expected payload type from the LHS variable type. This is called as client payload binding support where the 
inbound response payload is accessed and parse to the expected type in the method signature. It is easy to access the
payload directly rather manipulation `http:Response` using its support methods such as `getTextPayload()`, ..etc.

Client data binding support is same as [`http` module](https://github.com/ballerina-platform/module-ballerina-http/blob/master/docs/spec/spec.md#243-client-action-return-types).
