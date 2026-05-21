package com.tts.controller;

import com.razorpay.RazorpayException;
import com.tts.dto.PaymentOrderRequest;
import com.tts.dto.PaymentOrderResponse;
import com.tts.dto.PaymentVerificationRequest;
import com.tts.entity.User;
import com.tts.repository.UserRepository;
import com.tts.service.RazorpayService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final RazorpayService razorpayService;
    private final UserRepository userRepository;

    @PostMapping("/create-order")
    public ResponseEntity<PaymentOrderResponse> createOrder(
            @RequestBody PaymentOrderRequest request,
            HttpServletRequest httpRequest) throws RazorpayException {
        
        Long userId = (Long) httpRequest.getAttribute("userId");
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        PaymentOrderResponse response = razorpayService.createOrder(request, user);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/verify")
    public ResponseEntity<String> verifyPayment(
            @RequestBody PaymentVerificationRequest request,
            HttpServletRequest httpRequest) {

        Long userId = (Long) httpRequest.getAttribute("userId");
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        boolean isValid = razorpayService.verifyPayment(request, user);
        if (isValid) {
            return ResponseEntity.ok("Payment verified and subscription activated");
        } else {
            return ResponseEntity.badRequest().body("Invalid payment signature");
        }
    }
}
