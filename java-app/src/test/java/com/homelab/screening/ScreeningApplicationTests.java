package com.homelab.screening;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ScreeningApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void contextLoads() {
        // If the application context fails to start, this test fails.
        // Common causes: misconfigured beans, missing properties, classpath conflicts.
    }

    @Test
    void rootEndpointReturns200() throws Exception {
        mockMvc.perform(get("/"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.service").value("java-screening"))
            .andExpect(jsonPath("$.status").value("running"));
    }

    @Test
    void healthEndpointReturns200() throws Exception {
        mockMvc.perform(get("/actuator/health"))
            .andExpect(status().isOk());
    }

    @Test
    void screeningsEndpointReturnsWithoutDatabase() throws Exception {
        // No database is configured in the test context.
        // The endpoint must return 200 with a degraded status — not a 500.
        mockMvc.perform(get("/api/screenings"))
            .andExpect(status().isOk());
    }
}