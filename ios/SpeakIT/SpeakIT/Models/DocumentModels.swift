//
//  DocumentModels.swift
//  SpeakIT
//
//  Data transfer models for PDF document analysis and long-form audiobook synthesis jobs.
//

import Foundation

public struct DocumentAnalysisResponse: Codable, Sendable {
    public let documentToken: String
    public let fileName: String
    public let fileSizeBytes: Int64
    public let pageCount: Int
    public let wordCount: Int
    public let characterCount: Int
    public let estimatedDurationSeconds: Int
    public let estimatedDurationFormatted: String
    public let validationStatus: String
    public let warnings: [String]?
    
    public init(
        documentToken: String,
        fileName: String,
        fileSizeBytes: Int64,
        pageCount: Int,
        wordCount: Int,
        characterCount: Int,
        estimatedDurationSeconds: Int,
        estimatedDurationFormatted: String,
        validationStatus: String,
        warnings: [String]? = nil
    ) {
        self.documentToken = documentToken
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.pageCount = pageCount
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.estimatedDurationFormatted = estimatedDurationFormatted
        self.validationStatus = validationStatus
        self.warnings = warnings
    }
}

public struct LongFormJobStatus: Codable, Sendable {
    public let jobId: String
    public let userId: Int64?
    public let status: String // QUEUED, PROCESSING, COMPLETED, FAILED
    public let progressPercent: Int
    public let totalChunks: Int
    public let completedChunks: Int
    public let audioUrl: String?
    public let textSnippet: String?
    public let totalCharacters: Int?
    public let voiceId: String?
    public let sourceFileName: String?
    public let title: String?
    public let estimatedDurationSeconds: Int?
    public let errorMessage: String?
    public let createdAt: String?
    public let completedAt: String?
    
    public var isComplete: Bool {
        status.uppercased() == "COMPLETED"
    }
    
    public var isFailed: Bool {
        status.uppercased() == "FAILED"
    }
    
    public var isProcessing: Bool {
        status.uppercased() == "PROCESSING" || status.uppercased() == "QUEUED"
    }
    
    public init(
        jobId: String,
        userId: Int64? = nil,
        status: String,
        progressPercent: Int,
        totalChunks: Int,
        completedChunks: Int,
        audioUrl: String? = nil,
        textSnippet: String? = nil,
        totalCharacters: Int? = nil,
        voiceId: String? = nil,
        sourceFileName: String? = nil,
        title: String? = nil,
        estimatedDurationSeconds: Int? = nil,
        errorMessage: String? = nil,
        createdAt: String? = nil,
        completedAt: String? = nil
    ) {
        self.jobId = jobId
        self.userId = userId
        self.status = status
        self.progressPercent = progressPercent
        self.totalChunks = totalChunks
        self.completedChunks = completedChunks
        self.audioUrl = audioUrl
        self.textSnippet = textSnippet
        self.totalCharacters = totalCharacters
        self.voiceId = voiceId
        self.sourceFileName = sourceFileName
        self.title = title
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public struct SubmitTtsJobRequest: Codable {
    public let documentToken: String?
    public let text: String?
    public let voiceId: String
    public let outputFormat: String
    public let title: String?
    public let sourceFileName: String?
    public let isElevenLabs: Bool
    public let isSarvam: Bool
    public let languageCode: String?
    public let voiceStyle: String?
    
    public init(
        documentToken: String? = nil,
        text: String? = nil,
        voiceId: String,
        outputFormat: String = "mp3",
        title: String? = nil,
        sourceFileName: String? = nil,
        isElevenLabs: Bool = false,
        isSarvam: Bool = false,
        languageCode: String? = nil,
        voiceStyle: String? = nil
    ) {
        self.documentToken = documentToken
        self.text = text
        self.voiceId = voiceId
        self.outputFormat = outputFormat
        self.title = title
        self.sourceFileName = sourceFileName
        self.isElevenLabs = isElevenLabs
        self.isSarvam = isSarvam
        self.languageCode = languageCode
        self.voiceStyle = voiceStyle
    }
}
