#!/usr/bin/env swift

import AppKit
import UniformTypeIdentifiers

// Helpers
struct ScriptFilter: Codable {
  let preselect: String?
  let items: [Item]

  struct Item: Codable {
    static let imageFormats: Array = NSImage.imageUnfilteredTypes
    let variables: [String: String]
    let uid: String
    let title: String
    let subtitle: String
    let type: String
    let icon: FileIcon
    let mods: [String: [String: String]]
    let arg: String

    // Helper for icon
    struct FileIcon: Codable {
      let path: String
      let type: String?
    }

    // Main initializer to use on existing files
    init(_ fileURL: URL) {
      let fileString = fileURL.path
      let fileBasename = fileURL.lastPathComponent
      let currentFolder = fileURL.deletingLastPathComponent()
      let parentFolder = currentFolder.deletingLastPathComponent()
      let currentFolderString = currentFolder.path
      let parentFolderString = parentFolder.path

      self.variables = ["current": currentFolderString, "parent": parentFolderString]
      self.uid = fileString
      self.title = fileBasename
      self.subtitle = "⇧↩ Up · \((currentFolderString as NSString).abbreviatingWithTildeInPath)"
      self.type = "file:skipcheck"
      self.mods = ["ctrl": ["subtitle": fileBasename]]
      self.arg = fileString

      // Use file as the icon if path can be viewed in Alfred, otherwise use the file type icon
      self.icon = {
        guard
          let fileFormat = try? fileURL.resourceValues(forKeys: [.contentTypeKey])
            .contentType?.identifier,
          ScriptFilter.Item.imageFormats.contains(fileFormat)
        else { return FileIcon(path: fileString, type: "fileicon") }

        return FileIcon(path: fileString, type: nil)
      }()
    }

    // Special initializer to create dummy to allow navigating up on empty folders
    init(navigateUpFrom currentFolder: URL) {
      let currentFolderString = currentFolder.path
      let parentFolderString = currentFolder.deletingLastPathComponent().path

      self.variables = ["current": currentFolderString, "parent": parentFolderString]
      self.uid = "Navigate Up"
      self.title = "Navigate to parent folder"
      self.subtitle = "Current folder is empty"
      self.type = "default"
      self.icon = FileIcon(path: "images/navup.png", type: nil)
      self.mods = ["ctrl": ["subtitle": currentFolder.lastPathComponent]]
      self.arg = parentFolderString
    }
  }
}

func sortByAdded(_ paths: [URL]) -> [URL] {
  return paths.sorted {
    guard let a = try? $0.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate else { return false }
    guard let b = try? $1.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate else { return true }

    return a > b
  }
}

// Grab folder contents
let currentFolder = ProcessInfo.processInfo.environment["current"]
let targetFolders = Array(CommandLine.arguments.dropFirst()).map { URL(fileURLWithPath: $0) }

let folderContents = targetFolders.flatMap { folder -> [URL] in
  guard let contents = try? FileManager.default.contentsOfDirectory(
    at: folder,
    includingPropertiesForKeys: [.addedToDirectoryDateKey, .isDirectoryKey],
    options: .skipsHiddenFiles)
  else { fatalError("Could not get folder contents: \(folder.path)") }

  return contents
}

// If folder has no items, provide an item to navigate to parent
guard folderContents.count > 0 else {
  let navigateUp = ScriptFilter.Item(navigateUpFrom: targetFolders[0])
  let sfFull = ScriptFilter(preselect: currentFolder, items: [navigateUp])
  let jsonData = try JSONEncoder().encode(sfFull)
  print(String(data: jsonData, encoding: .utf8)!)
  exit(EXIT_SUCCESS)
}

// Sort
let sortedPaths = {
  // Sort alphabetically or by added
  let generalSort = ProcessInfo.processInfo.environment["sort_order"] == "by_added" ?
    sortByAdded(folderContents) :
    folderContents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

  // Sort folders to top
  guard ProcessInfo.processInfo.environment["folders_at_top"] == "1" else { return generalSort }

  return generalSort.sorted {
    guard let a = try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else { return false }
    guard let b = try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else { return true }

    if a && !b { return true }
    if !a && b { return false }
    return false
  }
}()

// Generate Items
let sfItems = sortedPaths.map { ScriptFilter.Item($0) }

// Output JSON
let sfFull = ScriptFilter(preselect: currentFolder, items: sfItems)
let jsonData = try JSONEncoder().encode(sfFull)
print(String(data: jsonData, encoding: .utf8)!)
