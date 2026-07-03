package com.speakit.tts.controller;
import com.speakit.contact.repository.ContactSubmissionRepository;
import com.speakit.contact.entity.ContactSubmission;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.speakit.contact.dto.ContactRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class ContactControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private com.speakit.contact.repository.ContactSubmissionRepository contactSubmissionRepository;

    @org.junit.jupiter.api.BeforeEach
    public void setup() {
        contactSubmissionRepository.deleteAll();
    }

    @Test
    public void testContactSubmissionSupport() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("support");
        request.setMessage("This is a valid support message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        java.util.List<com.speakit.contact.entity.ContactSubmission> submissions = contactSubmissionRepository.findAll();
        org.junit.jupiter.api.Assertions.assertEquals(1, submissions.size());
        org.junit.jupiter.api.Assertions.assertEquals("Technical Support", submissions.get(0).getTopic());
    }

    @Test
    public void testContactSubmissionBilling() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("billing");
        request.setMessage("This is a valid billing message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        java.util.List<com.speakit.contact.entity.ContactSubmission> submissions = contactSubmissionRepository.findAll();
        org.junit.jupiter.api.Assertions.assertEquals(1, submissions.size());
        org.junit.jupiter.api.Assertions.assertEquals("Billing", submissions.get(0).getTopic());
    }

    @Test
    public void testContactSubmissionEnterprise() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("enterprise");
        request.setMessage("This is a valid enterprise message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        java.util.List<com.speakit.contact.entity.ContactSubmission> submissions = contactSubmissionRepository.findAll();
        org.junit.jupiter.api.Assertions.assertEquals(1, submissions.size());
        org.junit.jupiter.api.Assertions.assertEquals("Enterprise Sales", submissions.get(0).getTopic());
    }

    @Test
    public void testContactSubmissionSupportLabel() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("Technical Support");
        request.setMessage("This is a valid support message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    public void testContactSubmissionBillingLabel() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("Billing");
        request.setMessage("This is a valid billing message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    public void testContactSubmissionFeedbackLabel() throws Exception {
        ContactRequest request = new ContactRequest();
        request.setFirstName("John");
        request.setLastName("Doe");
        request.setEmail("john.doe@example.com");
        request.setTopic("Product Feedback");
        request.setMessage("This is a valid feedback message with more than 10 characters.");
        
        mockMvc.perform(post("/api/contact")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }
}
