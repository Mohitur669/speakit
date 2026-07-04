package com.speakit.user.service;

import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public User getUserById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    public User getReferenceById(Long id) {
        return userRepository.getReferenceById(id);
    }
}
