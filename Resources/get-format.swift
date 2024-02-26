#!/usr/bin/env swift

import AppKit
import UniformTypeIdentifiers

// Quick exit function
func sendType(_ fileType: String) {
  print(fileType, terminator: "")
  exit(EXIT_SUCCESS)
}

// Parse file
let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let fileType = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
  print("unknown")
  exit(EXIT_FAILURE)
}

// Check if PDF
if fileType.conforms(to: .pdf) { sendType("pdf") }

// Check if plain text
if fileType.conforms(to: .plainText) { sendType("text") }

// Check if previeweable image
// Keep after PDF check, since those would also return true
if NSImage.imageUnfilteredTypes.contains(fileType.identifier) { sendType("image") }

// If we reach here, not a previeweable format
sendType("other")
