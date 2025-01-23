/*
 * Copyright (c) 2024, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package io.ballerina.lib.sap;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.concurrent.StrandMetadata;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import static io.ballerina.runtime.observability.ObservabilityConstants.KEY_OBSERVER_CONTEXT;
import static io.ballerina.lib.sap.HttpConstants.AND_SIGN;
import static io.ballerina.lib.sap.HttpConstants.CURRENT_TRANSACTION_CONTEXT_PROPERTY;
import static io.ballerina.lib.sap.HttpConstants.EMPTY;
import static io.ballerina.lib.sap.HttpConstants.EQUAL_SIGN;
import static io.ballerina.lib.sap.HttpConstants.MAIN_STRAND;
import static io.ballerina.lib.sap.HttpConstants.ORIGIN_HOST;
import static io.ballerina.lib.sap.HttpConstants.POOLED_BYTE_BUFFER_FACTORY;
import static io.ballerina.lib.sap.HttpConstants.QUESTION_MARK;
import static io.ballerina.lib.sap.HttpConstants.QUOTATION_MARK;
import static io.ballerina.lib.sap.HttpConstants.REMOTE_ADDRESS;
import static io.ballerina.lib.sap.HttpConstants.SINGLE_SLASH;
import static io.ballerina.lib.sap.HttpConstants.SRC_HANDLER;

public class ClientAction {

    private ClientAction() {
    }

    public static Object postResource(Environment env, BObject client, BArray path, Object message, Object headers,
                                      Object mediaType, BTypedesc targetType, BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), message, mediaType, headers,
                targetType, "processPost");
    }

    public static Object post(Environment env, BObject client, BString path, Object message, Object headers,
                              Object mediaType, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, message, mediaType, headers, targetType, "processPost");
    }

    public static Object putResource(Environment env, BObject client, BArray path, Object message, Object headers,
                                     Object mediaType, BTypedesc targetType, BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), message, mediaType, headers,
                targetType, "processPut");
    }

    public static Object put(Environment env, BObject client, BString path, Object message, Object headers,
                             Object mediaType, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, message, mediaType, headers, targetType, "processPut");
    }

    public static Object patchResource(Environment env, BObject client, BArray path, Object message, Object headers,
                                       Object mediaType, BTypedesc targetType, BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), message, mediaType, headers,
                targetType, "processPatch");
    }

    public static Object patch(Environment env, BObject client, BString path, Object message, Object headers,
                               Object mediaType, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, message, mediaType, headers, targetType, "processPatch");
    }

    public static Object deleteResource(Environment env, BObject client, BArray path, Object message, Object headers,
                                        Object mediaType, BTypedesc targetType, BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), message, mediaType, headers,
                targetType, "processDelete");
    }

    public static Object delete(Environment env, BObject client, BString path, Object message, Object headers,
                                Object mediaType, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, message, mediaType, headers, targetType, "processDelete");
    }

    public static Object getResource(Environment env, BObject client, BArray path, Object headers, BTypedesc targetType,
                                     BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), headers, targetType, "processGet");
    }

    public static Object get(Environment env, BObject client, BString path, Object headers, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, headers, targetType, "processGet");
    }

    public static Object headResource(Environment env, BObject client, BArray path, Object headers, BMap params) {
        Object[] paramFeed = new Object[2];
        paramFeed[0] = constructRequestPath(path, params);
        paramFeed[1] = headers;
        return invokeClientMethod(env, client, "head", paramFeed);
    }

    public static Object optionsResource(Environment env, BObject client, BArray path, Object headers,
                                         BTypedesc targetType, BMap params) {
        return invokeClientMethod(env, client, constructRequestPath(path, params), headers, targetType,
                "processOptions");
    }

    public static Object options(Environment env, BObject client, BString path, Object headers, BTypedesc targetType) {
        return invokeClientMethod(env, client, path, headers, targetType, "processOptions");
    }

    private static Object invokeClientMethod(Environment env, BObject client, BString path, Object message,
                                             BTypedesc targetType, String methodName) {
        Object[] paramFeed = new Object[3];
        paramFeed[0] = path;
        paramFeed[1] = message;
        paramFeed[2] = targetType;
        return invokeClientMethod(env, client, methodName, paramFeed);
    }

    private static Object invokeClientMethod(Environment env, BObject client, BString path, Object message,
                                             Object mediaType, Object headers, BTypedesc targetType,
                                             String methodName) {
        Object[] paramFeed = new Object[5];
        paramFeed[0] = path;
        paramFeed[1] = message;
        paramFeed[2] = targetType;
        paramFeed[3] = mediaType;
        paramFeed[4] = headers;
        return invokeClientMethod(env, client, methodName, paramFeed);
    }

    private static Object invokeClientMethod(Environment env, BObject client, String methodName, Object[] paramFeed) {
        return env.yieldAndRun(() -> {
            try {
                Map<String, Object> propertyMap = getPropertiesToPropagate(env);
                StrandMetadata strandMetadata = new StrandMetadata(false, propertyMap);
                return env.getRuntime().callMethod(client, methodName, strandMetadata, paramFeed);
            } catch (BError bError) {
                return HttpUtil.createHttpError("client method invocation failed: " + bError.getErrorMessage(),
                        HttpErrorType.CLIENT_ERROR, bError);
            }
        });
    }

    private static Map<String, Object> getPropertiesToPropagate(Environment env) {
        String[] keys = {CURRENT_TRANSACTION_CONTEXT_PROPERTY, KEY_OBSERVER_CONTEXT, SRC_HANDLER, MAIN_STRAND,
                POOLED_BYTE_BUFFER_FACTORY, REMOTE_ADDRESS, ORIGIN_HOST};
        Map<String, Object> subMap = new HashMap<>();
        for (String key : keys) {
            Object value = env.getStrandLocal(key);
            if (value != null) {
                subMap.put(key, value);
            }
        }
        String strandParentFunctionName = Objects.isNull(env.getStrandName()) ? null :
                env.getStrandName();
        if (Objects.nonNull(strandParentFunctionName) && strandParentFunctionName.equals("onMessage")) {
            subMap.put(MAIN_STRAND, true);
        }
        return subMap;
    }

    private static BString constructRequestPath(BArray pathArray, BMap params) {
        String joinedPath = SINGLE_SLASH + String.join(SINGLE_SLASH, getPathStringArray(pathArray));
        String queryParams = constructQueryString(params);
        if (queryParams.isEmpty()) {
            return StringUtils.fromString(joinedPath);
        } else {
            return StringUtils.fromString(joinedPath + QUESTION_MARK + queryParams);
        }
    }

    private static String[] getPathStringArray(BArray pathArray) {
        int tag = pathArray.getElementType().getTag();
        switch (tag) {
            case TypeTags.STRING_TAG:
                return Arrays.stream(pathArray.getStringArray()).map(String::valueOf).toArray(String[]::new);
            case TypeTags.INT_TAG:
                return Arrays.stream(pathArray.getIntArray()).mapToObj(String::valueOf).toArray(String[]::new);
            case TypeTags.FLOAT_TAG:
                return Arrays.stream(pathArray.getFloatArray()).mapToObj(String::valueOf).toArray(String[]::new);
            case TypeTags.BOOLEAN_TAG:
                boolean[] booleanArray = pathArray.getBooleanArray();
                String[] booleanStringArray = new String[booleanArray.length];
                for (int i = 0; i < booleanArray.length; i++) {
                    booleanStringArray[i] = String.valueOf(booleanArray[i]);
                }
                return booleanStringArray;
            default:
                return Arrays.stream(pathArray.getValues()).filter(Objects::nonNull).map(String::valueOf)
                        .toArray(String[]::new);
        }
    }

    private static String constructQueryString(BMap params) {
        List<String> queryParams = new ArrayList<>();
        BString[] keys = (BString[]) params.getKeys();
        if (keys.length == 0) {
            return "";
        }
        for (BString key : keys) {
            Object value = params.get(key);
            String valueString = value.toString();
            if (value instanceof BArray) {
                valueString = valueString.substring(1, valueString.length() - 1);
                valueString = valueString.replace(QUOTATION_MARK, EMPTY);
            }
            queryParams.add(key.getValue() + EQUAL_SIGN + valueString);
        }
        return String.join(AND_SIGN, queryParams);
    }
}
