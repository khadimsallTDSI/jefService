package com.jef.sn.service;

import com.jef.sn.config.ApplicationProperties;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

@Service
public class SmsService {

    private static final Logger LOG = LoggerFactory.getLogger(SmsService.class);

    private final RestTemplate restTemplate;
    private final ApplicationProperties applicationProperties;

    public SmsService(RestTemplateBuilder restTemplateBuilder, ApplicationProperties applicationProperties) {
        this.restTemplate = restTemplateBuilder.setConnectTimeout(Duration.ofSeconds(10)).setReadTimeout(Duration.ofSeconds(10)).build();
        this.applicationProperties = applicationProperties;
    }

    public void sendOtp(String phoneNumber, String otp) {
        sendMessage(phoneNumber, "Votre OTP est : " + otp);
    }

    public void sendMessage(String phoneNumber, String messageBody) {
        ApplicationProperties.Sms.LafricaMobile config = applicationProperties.getSms().getLafricaMobile();

        if (!config.isEnabled()) {
            LOG.warn("Tentative d'envoi SMS alors que LafricaMobile est désactivé.");
            throw new IllegalStateException("LafricaMobile est désactivé dans la configuration.");
        }

        if (isBlank(config.getAccountId()) || isBlank(config.getPassword())) {
            throw new IllegalStateException("Les identifiants LafricaMobile sont manquants.");
        }

        if (isBlank(config.getBaseUrl())) {
            throw new IllegalStateException("L'URL LafricaMobile est manquante.");
        }

        String normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
        String endpoint = normalizeEndpoint(config.getBaseUrl(), config.getPath());
        Map<String, Object> payload = new HashMap<>();
        payload.put("accountid", config.getAccountId());
        payload.put("password", config.getPassword());
        payload.put("sender", config.getSender());
        payload.put("text", messageBody);
        payload.put("phone", normalizedPhoneNumber);
        payload.put("to", normalizedPhoneNumber);
        payload.put("type", "text");

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        try {
            ResponseEntity<String> response = restTemplate.exchange(
                endpoint,
                HttpMethod.POST,
                new HttpEntity<>(payload, headers),
                String.class
            );

            if (!response.getStatusCode().is2xxSuccessful()) {
                throw new IllegalStateException("Envoi SMS échoué: code HTTP " + response.getStatusCode().value());
            }
            LOG.info("SMS envoyé à {}", normalizedPhoneNumber);
        } catch (RestClientException ex) {
            throw new IllegalStateException("Impossible d'atteindre LafricaMobile", ex);
        }
    }

    private String normalizePhoneNumber(String phoneNumber) {
        String normalizedPhoneNumber = phoneNumber.trim();
        if (normalizedPhoneNumber.startsWith("+")) {
            return normalizedPhoneNumber;
        }
        return "+221" + normalizedPhoneNumber;
    }

    private String normalizeEndpoint(String baseUrl, String path) {
        String normalizedBase = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        if (isBlank(path)) {
            return normalizedBase;
        }
        String normalizedPath = path.startsWith("/") ? path : "/" + path;
        return normalizedBase + normalizedPath;
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
