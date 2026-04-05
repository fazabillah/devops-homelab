package com.homelab.screening.controller;

import com.homelab.screening.model.Screening;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ScreeningController {

    private static final Logger log = LoggerFactory.getLogger(ScreeningController.class);
    private final JdbcTemplate jdbc;

    public ScreeningController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/screenings")
    public ResponseEntity<?> getScreenings() {
        try {
            List<Screening> results = jdbc.query(
                "SELECT id, reference, status, TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') AS created_at FROM screenings ORDER BY id DESC",
                (rs, rowNum) -> new Screening(
                    rs.getLong("id"),
                    rs.getString("reference"),
                    rs.getString("status"),
                    rs.getString("created_at")
                )
            );
            log.info("GET /api/screenings - {} results returned", results.size());
            return ResponseEntity.ok(results);
        } catch (DataAccessException e) {
            // Return a degraded response rather than a 500 when the DB is unreachable.
            // This lets the pod stay in a Running/Ready state even if Oracle is starting up.
            log.warn("Database unavailable: {}", e.getMessage());
            return ResponseEntity.ok(Map.of(
                "status", "degraded",
                "reason", "database unavailable",
                "data", List.of()
            ));
        }
    }
}