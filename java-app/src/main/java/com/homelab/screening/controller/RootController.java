package com.homelab.screening.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class RootController {

    @Value("${app.version:unknown}")
    private String appVersion;

    @Value("${app.environment:development}")
    private String environment;

    @GetMapping("/")
    public ResponseEntity<Map<String, String>> root() {
        return ResponseEntity.ok(Map.of(
            "service", "java-screening",
            "version", appVersion,
            "environment", environment,
            "status", "running"
        ));
    }
}