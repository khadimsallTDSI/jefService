package com.jef.sn.service;

import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.jef.sn.config.ApplicationProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.autoconfigure.web.client.RestClientTest;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.client.MockRestServiceServer;

@RestClientTest(SmsService.class)
@EnableConfigurationProperties(ApplicationProperties.class)
@TestPropertySource(
    properties = {
        "application.sms.lafrica-mobile.enabled=true",
        "application.sms.lafrica-mobile.base-url=https://lamsms.lafricamobile.com",
        "application.sms.lafrica-mobile.path=/api",
        "application.sms.lafrica-mobile.account-id=SYNAPSYS_CONSEILS_01",
        "application.sms.lafrica-mobile.password=test-password",
        "application.sms.lafrica-mobile.sender=LAM TEST",
    }
)
class SmsServiceTest {

    @Autowired
    private SmsService smsService;

    @Autowired
    private MockRestServiceServer server;

    @Test
    void sendMessagePostsLafricaMobilePayloadWithLamTestSender() {
        server
            .expect(once(), requestTo("https://lamsms.lafricamobile.com/api"))
            .andExpect(method(HttpMethod.POST))
            .andExpect(content().contentType(MediaType.APPLICATION_JSON))
            .andExpect(
                content()
                    .json(
                        """
                        {
                          "accountid": "SYNAPSYS_CONSEILS_01",
                          "password": "test-password",
                          "sender": "LAM TEST",
                          "text": "Bonjour",
                          "phone": "+221771234567",
                          "to": "+221771234567",
                          "type": "text"
                        }
                        """
                    )
            )
            .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        smsService.sendMessage("771234567", "Bonjour");

        server.verify();
    }
}
