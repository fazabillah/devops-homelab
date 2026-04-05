package com.homelab.screening.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Screening {
    private Long id;
    private String reference;
    private String status;
    private String createdAt;
}