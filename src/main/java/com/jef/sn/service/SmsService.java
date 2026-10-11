package com.jef.sn.service;

import com.twilio.Twilio;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class SmsService {

    private static final Logger LOG = LoggerFactory.getLogger(SmsService.class);

    @Value("${twilio.account-sid:}")
    private String accountSid;

    @Value("${twilio.auth-token:}")
    private String authToken;

    @Value("${twilio.from-number:}")
    private String fromNumber;

    private boolean configured;

    @PostConstruct
    void init() {
        if (accountSid.isBlank() || authToken.isBlank() || fromNumber.isBlank()) {
            LOG.warn("Twilio credentials are not configured; SMS delivery is disabled.");
            return;
        }
        Twilio.init(accountSid, authToken);
        configured = true;
    }

    public void sendOtp(String phoneNumber, String otp) {
        sendMessage(phoneNumber, "Votre OTP est : " + otp);
    }

    public void sendMessage(String phoneNumber, String messageBody) {
        if (!configured) {
            throw new IllegalStateException("Twilio is not configured");
        }

        // Assure-toi que le numéro client est en format international
        if (!phoneNumber.startsWith("+")) {
            phoneNumber = "+221" + phoneNumber; // Sénégal
        }

        Message message = Message.creator(
            new PhoneNumber(phoneNumber), // To
            new PhoneNumber(fromNumber), // From (ton Twilio validé)
            messageBody
        ).create();

        System.out.println("SMS envoyé à " + phoneNumber + " : " + message.getSid());
    }
}
