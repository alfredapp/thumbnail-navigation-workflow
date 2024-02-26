#!/usr/bin/env swift

import Foundation

let inputFile = URL(fileURLWithPath: CommandLine.arguments[1])

guard
  let isDir = try? inputFile.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true,
  let isPkg = try? inputFile.resourceValues(forKeys: [.isPackageKey]).isPackage == true
else {
  print("file")
  exit(EXIT_SUCCESS)
}

if isDir && !isPkg {
  print("true")
  exit(EXIT_SUCCESS)
}

print("false")
exit(EXIT_SUCCESS)
