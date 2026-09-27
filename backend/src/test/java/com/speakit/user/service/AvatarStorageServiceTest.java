package com.speakit.user.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;

class AvatarStorageServiceTest {

    private AvatarStorageService avatarStorageService;

    @BeforeEach
    void setUp() {
        avatarStorageService = new AvatarStorageService();
        avatarStorageService.init();
    }

    @Test
    @DisplayName("Should throw IllegalArgumentException when file is empty")
    void shouldThrowWhenFileIsEmpty() {
        MockMultipartFile emptyFile = new MockMultipartFile("file", "empty.jpg", "image/jpeg", new byte[0]);
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                avatarStorageService.storeAvatar(1L, emptyFile)
        );
        assertTrue(ex.getMessage().contains("must not be empty"));
    }

    @Test
    @DisplayName("Should throw IllegalArgumentException when file exceeds 2MB limit")
    void shouldThrowWhenFileExceedsLimit() {
        byte[] largeData = new byte[3 * 1024 * 1024]; // 3MB
        MockMultipartFile largeFile = new MockMultipartFile("file", "large.png", "image/png", largeData);
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                avatarStorageService.storeAvatar(1L, largeFile)
        );
        assertTrue(ex.getMessage().contains("exceeds the 2MB limit"));
    }

    @Test
    @DisplayName("Should throw IllegalArgumentException on unsupported MIME type")
    void shouldThrowOnUnsupportedMimeType() {
        MockMultipartFile invalidFile = new MockMultipartFile("file", "doc.pdf", "application/pdf", new byte[]{1, 2, 3});
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                avatarStorageService.storeAvatar(1L, invalidFile)
        );
        assertTrue(ex.getMessage().contains("Invalid image format"));
    }

    @Test
    @DisplayName("Should successfully store valid avatar and return StoredAvatar record")
    void shouldStoreValidAvatar() throws IOException {
        byte[] dummyImage = new byte[]{ (byte) 0xFF, (byte) 0xD8, (byte) 0xFF }; // JPEG magic bytes
        MockMultipartFile validFile = new MockMultipartFile("file", "avatar.jpg", "image/jpeg", dummyImage);

        AvatarStorageService.StoredAvatar stored = avatarStorageService.storeAvatar(42L, validFile);
        assertNotNull(stored);
        assertNotNull(stored.url());
        assertTrue(stored.url().contains("u_42_"));
        assertTrue(stored.url().endsWith(".jpg"));
        assertNotNull(stored.storageKey());
        assertTrue(stored.storageKey().startsWith("avatars/u_42_"));

        // Clean up test file
        avatarStorageService.deleteAvatar(stored.storageKey(), stored.url());
    }
}
