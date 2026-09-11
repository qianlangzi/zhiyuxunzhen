package com.zhiyu.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * AI 中台底层 HTTP 收发原语（阶段3 Phase A 抽取）。
 *
 * 封装 POST/GET 请求、data 解析、strict 透传、Bearer 鉴权与 SSE 流式转发。
 * 不承载任何业务含义；具体能力分发见 6 个分组门面与 {@link AiPlatformClient}。
 * 安全：请求体只打键名清单（info），具体值降级到 debug，防止敏感字段明文泄露。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiHttpClient {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${zhiyu.ai.base-url}")
    private String baseUrl;

    @Value("${zhiyu.ai.internal-token}")
    private String internalToken;

    /** 全程链路 trace 头：与 AI 中台 RequestContextMiddleware 约定，跨系统按同一 trace 关联日志。 */
    private static final String TRACE_HEADER = "X-Trace-Id";

    /** trace 入 MDC 的键（与 TraceIdInterceptor 一致），出站时透传同名头。 */
    private static final String MDC_TRACE_KEY = "traceId";

    /** 把当前请求的 traceId（来自 TraceIdInterceptor 写入的 MDC）附加到出站 AI 请求头；无则跳过。 */
    private void fillTraceHeader(HttpHeaders headers) {
        String traceId = MDC.get(MDC_TRACE_KEY);
        if (traceId != null && !traceId.isBlank()) {
            headers.set(TRACE_HEADER, traceId);
        }
    }

    /** 暴露 base-url 供门面直连（如图片流式下载）。 */
    public String getBaseUrl() {
        return baseUrl;
    }

    /** 暴露内部鉴权 token 供门面直连复用。 */
    public String getInternalToken() {
        return internalToken;
    }

    /**
     * 构建统一 Agent 网关信封：``{action, task, options}``（阶段3 Phase B）。
     * task 为复用 endpoint 的请求体，options.stream 标记是否流式（网关据此保持 SSE 契约）。
     */
    public static Map<String, Object> agentEnvelope(String action, Map<String, Object> task, boolean stream) {
        Map<String, Object> envelope = new HashMap<>();
        envelope.put("action", action);
        envelope.put("task", task == null ? Map.of() : task);
        Map<String, Object> options = new HashMap<>();
        options.put("stream", stream);
        envelope.put("options", options);
        return envelope;
    }

    /**
     * 统一的 POST 请求封装；服务异常抛 {@link BizException#AI_SERVICE_ERROR}。
     */
    public String post(String path, Map<String, Object> body) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("X-Internal-Token", internalToken);
            fillTraceHeader(headers);
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

            if (body != null) {
                log.info("调用AI中台: POST {} bodyKeys={}", url, body.keySet());
                if (log.isDebugEnabled()) {
                    log.debug("调用AI中台: POST {} body={}", url, body);
                }
            } else {
                log.info("调用AI中台: POST {}", url);
            }
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            log.info("AI中台响应: {} status={}", url, resp.getStatusCode());
            return resp.getBody();
        } catch (HttpStatusCodeException e) {
            // 显式打印 AI 返回的状态码与响应体：默认的 RestClientException 消息只给出
            // "401 Unauthorized: [no body]" 这类信息，看不到 AI 的 detail
            // （如「缺少登录凭证」vs「登录凭证无效或已过期」），排查读图降级时曾因此绕远路。
            log.error("调用AI中台失败(HTTP): POST {} status={} body={}",
                    url, e.getStatusCode(), e.getResponseBodyAsString());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常: " + e.getMessage());
        } catch (RestClientException e) {
            log.error("调用AI中台失败: POST {} error={}", url, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常: " + e.getMessage());
        } catch (Exception e) {
            log.error("调用AI中台未知异常: POST {} error={}", url, e.getMessage(), e);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常");
        }
    }

    /**
     * POST 并解析 data 字段；AI 不可用或返回异常时返回 null（优雅降级，不抛异常）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> postData(String path, Map<String, Object> body) {
        try {
            String json = post(path, body);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI中台响应中无data字段: {} resp={}", path, json);
            return null;
        } catch (Exception e) {
            log.warn("AI中台调用失败，返回null: {} error={}", path, e.getMessage());
            return null;
        }
    }

    /**
     * 严格的 POST 并解析 data：AI 返回错误码或无 data 时抛携带其真实 message 的 BizException
     * （而非静默返回 null），供调用方透传诊断。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> postDataStrict(String path, Map<String, Object> body) {
        String json = post(path, body); // 网络/HTTP/授权层异常已由 post() 抛 BizException
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            JsonNode msg = root.get("message");
            String realMsg = msg != null && msg.isTextual() && !msg.asText().isBlank()
                    ? msg.asText() : "AI 返回数据异常";
            log.warn("AI中台返回错误: {} resp={}", path, json);
            // 区分「AI 输出不合规（可重试）」与「AI 服务不可用」：AI 中台对 schema 校验失败
            // 返回业务码 422，此处映射为 AI_OUTPUT_INVALID，其余错误保持 AI_SERVICE_ERROR，
            // 供调用方按语义分别处理（重试提示 vs 降级兜底）。
            ResultCode code = (root.get("code") != null && root.get("code").asInt() == 422)
                    ? ResultCode.AI_OUTPUT_INVALID : ResultCode.AI_SERVICE_ERROR;
            throw new BizException(code, realMsg);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI中台响应解析失败，返回异常: {} error={}", path, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务响应解析异常");
        }
    }

    /**
     * 携带移动端 JWT（Authorization: Bearer）的 POST；失败返回 null（优雅降级）。
     */
    public String postWithBearer(String path, Map<String, Object> body, String bearer) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            fillTraceHeader(headers);
            if (bearer != null && !bearer.isBlank()) {
                headers.set(HttpHeaders.AUTHORIZATION, bearer.startsWith("Bearer ") ? bearer : "Bearer " + bearer);
            } else {
                // 之前静默：header 缺失时看不出「根本没带凭证」还是「凭证被拒」
                log.warn("调用AI中台(Bearer)但未携带 Authorization 头: POST {}", url);
            }
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            return resp.getBody();
        } catch (HttpStatusCodeException e) {
            log.error("调用AI中台失败(HTTP): POST {} status={} body={}",
                    url, e.getStatusCode(), e.getResponseBodyAsString());
            return null;
        } catch (RestClientException e) {
            log.error("调用AI中台失败: POST {} error={}", url, e.getMessage());
            return null;
        } catch (Exception e) {
            log.error("调用AI中台未知异常: POST {} error={}", url, e.getMessage(), e);
            return null;
        }
    }

    /**
     * 携带移动端 JWT 的 POST 并解析 data；失败返回 null（优雅降级）。
     *
     * 兼容两种 AI 响应形态：
     * 1) R 信封 `{"code":0,"data":{...}}` —— 优先取 data；
     * 2) 裸业务对象 —— 如 `/v1/ai/vision/analyze` 按契约（ai/tests/contract/
     *    test_api_contracts.py::TestVisionAnalyze）直接返回 VisionAnalysisResult，
     *    没有 data 字段。旧实现遇到无 data 一律 return null，后端于是丢弃「读图成功」
     *    的结果、统一降级成「读图服务暂不可用」，表现为问诊发图永远读不出内容
     *    （2026-09-11 定位并修复）。
     * 错误信封（含 code 但无 data）仍返回 null 走降级。
     */
    public Map<String, Object> postDataWithBearer(String path, Map<String, Object> body, String bearer) {
        String json = postWithBearer(path, body, bearer);
        if (json == null) return null;
        return parseDataOrBare(path, json);
    }

    /**
     * 内部鉴权（X-Internal-Token）POST 并解析 data；失败返回 null（优雅降级）。
     *
     * 与 {@link #postData} 的区别：同样容忍「裸业务对象」响应。
     * AI 中台内部端点的响应形态与公网端点一致（response_model 直出），
     * 例如 /internal/vision/analyze 返回 VisionAnalysisResult，没有 {code,data} 信封。
     */
    public Map<String, Object> postDataInternal(String path, Map<String, Object> body) {
        try {
            String json = post(path, body);
            if (json == null) return null;
            return parseDataOrBare(path, json);
        } catch (Exception e) {
            log.warn("AI中台内部调用失败，返回null: {} error={}", path, e.getMessage());
            return null;
        }
    }

    /**
     * 解析 AI 响应：优先取 `data`；无 data 时把裸业务对象原样透传（见上文契约说明）。
     * 返回 null 表示响应不可用（错误信封 / 空对象 / 解析失败），调用方走降级。
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> parseDataOrBare(String path, String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            if (root.isObject() && !root.has("code")) {
                Map<String, Object> bare = objectMapper.convertValue(root, Map.class);
                if (!bare.isEmpty()) {
                    log.debug("AI中台返回裸业务对象，按原样透传: {} keys={}", path, bare.keySet());
                    return bare;
                }
            }
            log.warn("AI中台响应中无data字段: {} resp={}", path, json);
            return null;
        } catch (Exception e) {
            log.warn("AI中台响应解析失败，返回null: {} error={}", path, e.getMessage());
            return null;
        }
    }

    /**
     * 解析 AI 中台 R 包装响应的 data 字段为 Map；解析失败返回 null（调用方降级）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> parseData(String json) {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            return null;
        } catch (Exception e) {
            log.warn("解析 AI data 失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 内部 GET 并解析 data；AI 不可用返回 null（优雅降级）。校验 code==0。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getData(String path) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-Internal-Token", internalToken);
            fillTraceHeader(headers);
            HttpEntity<Void> entity = new HttpEntity<>(headers);
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
            JsonNode root = objectMapper.readTree(resp.getBody());
            if (root.get("code") != null && root.get("code").asInt() != 0) {
                log.warn("AI中台配置接口返回错误: {} resp={}", url, resp.getBody());
                return null;
            }
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI中台配置接口响应中无data字段: {} resp={}", url, resp.getBody());
            return null;
        } catch (Exception e) {
            log.warn("AI中台配置接口调用失败，返回null: {} error={}", url, e.getMessage());
            return null;
        }
    }

    /**
     * 流式 SSE 转发：在 RestTemplate 的 ResponseExtractor 回调内读取 AI 中台 SSE 流并逐行
     * 转发给 SseEmitter。重要：必须在回调内读取，回调返回后连接/流会被关闭（"stream is closed"）。
     */
    public void postSse(String path, Map<String, Object> body, SseEmitter emitter, String failSuffix) {
        String url = baseUrl + path;
        try {
            String json = objectMapper.writeValueAsString(body);
            restTemplate.execute(url, HttpMethod.POST,
                    request -> {
                        request.getHeaders().setContentType(MediaType.APPLICATION_JSON);
                        request.getHeaders().set("X-Internal-Token", internalToken);
                        fillTraceHeader(request.getHeaders());
                        request.getHeaders().set("Cache-Control", "no-cache");
                        request.getHeaders().set("Accept", "text/event-stream");
                        request.getBody().write(json.getBytes(StandardCharsets.UTF_8));
                    },
                    response -> {
                        if (response.getStatusCode().value() != 200) {
                            throw new BizException(ResultCode.AI_SERVICE_ERROR,
                                    "AI流式服务异常: HTTP " + response.getStatusCode().value());
                        }
                        // 在回调内读取，流尚未被 RestTemplate 关闭
                        forwardSseToEmitter(response.getBody(), emitter);
                        return null;
                    });
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("调用AI流式失败: POST {} error={}", url, e.getMessage(), e);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, failSuffix + ": " + e.getMessage());
        }
    }

    /**
     * 把 AI 中台返回的 SSE 原始字节流按行解析后转发到客户端 SseEmitter。
     * 事件格式：``event: <name>\ndata: <json>\n\n``。
     */
    static void forwardSseToEmitter(InputStream upstream, SseEmitter emitter) throws IOException {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(upstream, StandardCharsets.UTF_8))) {
            String line;
            String event = null;
            while ((line = reader.readLine()) != null) {
                if (line.isBlank()) {
                    // SSE 事件以空行结束；下一事件若无 event: 前缀则按默认消息类型处理
                    event = null;
                    continue;
                }
                if (line.startsWith("event:")) {
                    event = line.substring("event:".length()).trim();
                } else if (line.startsWith("data:")) {
                    // 无 event: 前缀的 data 行 = SSE 标准默认 message 事件。
                    // 若因 event==null 直接丢弃会导致打字机悄悄丢词，这里统一按 message 转发，
                    // 保证任何只发 data: 的下游接口也不会丢包（有事件名的流程行为保持不变）。
                    String name = (event == null || event.isBlank()) ? "message" : event;
                    String data = line.substring("data:".length()).trim();
                    try {
                        if ("done".equals(name)) {
                            emitter.send(SseEmitter.event().name(name).data(data));
                            emitter.complete();
                            return;
                        }
                        emitter.send(SseEmitter.event().name(name).data(data));
                    } catch (Exception ex) {
                        log.debug("SSE send 中断（前端可能已离开）: {}", ex.getMessage());
                        emitter.complete();
                        return;
                    }
                }
            }
            emitter.complete();
        }
    }
}