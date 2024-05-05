/**
*  Publish
*  Copyright (c) John Sundell 2019
*  MIT license, see LICENSE file for details
*/

import Foundation
import Files
import ShellOut

internal struct WebsiteRunner {
    let folder: Folder
    var portNumber: Int
    let liveReloadPath: String?

    func run() throws {
        let generator = WebsiteGenerator(folder: folder)
        try generator.generate()

        let outputFolder = try resolveOutputFolder()

        let serverQueue = DispatchQueue(label: "Publish.WebServer")
        let serverProcess = Process()

        print("""
        🌍 Starting web server at http://localhost:\(portNumber)

        Press ENTER to stop the server and exit
        """)

        serverQueue.async {
            do {
                _ = try shellOut(
                    to: "python3 -m http.server \(self.portNumber)",
                    at: outputFolder.path,
                    process: serverProcess
                )
            } catch let error as ShellOutError {
                self.outputServerErrorMessage(error.message)
            } catch {
                self.outputServerErrorMessage(error.localizedDescription)
            }

            serverProcess.terminate()
            exit(1)
        }

        var liveReloadTask: Task<Void, Error>?
        if let liveReloadPath {
            let liveReloadFolder = try resolveLiveReloadFolder(liveReloadPath)
            liveReloadTask = liveReload(in: liveReloadFolder, generator: generator)
        }

        _ = readLine()
        liveReloadTask?.cancel()
        serverProcess.terminate()
    }
}

private extension WebsiteRunner {
    func liveReload(in folder: Folder, generator: WebsiteGenerator) -> Task<Void, Error> {
        Task.detached {
            var maybePreviousChecksum: String?
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)

                try Task.checkCancellation()

                do {
                    let checksum = try shellOut(to: "tar -cf - \(folder.path) | md5sum")
                    if let previousChecksum = maybePreviousChecksum, checksum != previousChecksum {
                        maybePreviousChecksum = checksum
                        try generator.generate()
                    } else {
                        maybePreviousChecksum = checksum
                    }
                } catch let error as ShellOutError {
                    self.outputLiveReloadingErrorMessage(error.message)
                } catch {
                    self.outputLiveReloadingErrorMessage(error.localizedDescription)
                }
            }
        }
    }
}

private extension WebsiteRunner {
    func resolveOutputFolder() throws -> Folder {
        do { return try folder.subfolder(named: "Output") }
        catch { throw CLIError.outputFolderNotFound }
    }

    func resolveLiveReloadFolder(_ path: String) throws -> Folder {
        do { return try folder.subfolder(at: path) }
        catch { throw CLIError.liveReloadFolderNotFound(path) }
    }

    func outputServerErrorMessage(_ message: String) {
        var message = message

        if message.hasPrefix("Traceback"),
           message.contains("Address already in use") {
            message = """
            A localhost server is already running on port number \(portNumber).
            - Perhaps another 'publish run' session is running?
            - Publish uses Python's simple HTTP server, so to find any
              running processes, you can use either Activity Monitor
              or the 'ps' command and search for 'python'. You can then
              terminate any previous process in order to start a new one.
            """
        }

        fputs("\n❌ Failed to start local web server:\n\(message)\n", stderr)
    }

    func outputLiveReloadingErrorMessage(_ message: String) {
        fputs("\n❌ Failed live reloading website:\n\(message)\n", stderr)
    }
}
