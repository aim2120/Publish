/**
 *  Publish
 *  Copyright (c) John Sundell 2019
 *  MIT license, see LICENSE file for details
 */

import Files
import Foundation
import ShellOut

public struct CLI {
    private let arguments: [String]
    private let publishRepositoryURL: URL
    private let publishVersion: String

    enum Error: Swift.Error {
        case invalidOptionUsage
    }

    public init(arguments: [String] = CommandLine.arguments,
                publishRepositoryURL: URL,
                publishVersion: String) {
        self.arguments = arguments
        self.publishRepositoryURL = publishRepositoryURL
        self.publishVersion = publishVersion
    }

    public func run(in folder: Folder = .current) throws {
        guard arguments.count > 1 else {
            return outputHelpText()
        }

        do {
            switch arguments[1] {
            case "new":
                let generator = ProjectGenerator(
                    folder: folder,
                    publishRepositoryURL: publishRepositoryURL,
                    publishVersion: publishVersion,
                    kind: resolveProjectKind(from: arguments)
                )

                try generator.generate()
            case "generate":
                let generator = WebsiteGenerator(folder: folder)
                try generator.generate()
            case "deploy":
                let deployer = WebsiteDeployer(folder: folder)
                try deployer.deploy()
            case "run":
                let portNumber = extractPortNumber(from: arguments)
                let runner = WebsiteRunner(folder: folder, portNumber: portNumber, liveReloadPath: try optionValue("--live-reload"))
                try runner.run()
            default:
                outputHelpText()
            }
        } catch {
            return outputHelpText()
        }
    }

}

private extension CLI {
    func outputHelpText() {
        print("""
        Publish Command Line Interface
        ------------------------------
        Interact with the Publish static site generator from
        the command line, to create new websites, or to generate
        and deploy existing ones.

        Available commands:

        - new: Set up a new website in the current folder.
        - generate: Generate the website in the current folder.
        - run: Generate and run a localhost server on default port 8000
               for the website in the current folder. Use the "-p"
               or "--port" option for customizing the default port.
               Use the "--live-reload <path>" option with a source directory
               path to live reload your site upon source files changes.
        - deploy: Generate and deploy the website in the current
               folder, according to its deployment method.
        """)
    }

    private func extractPortNumber(from arguments: [String]) -> Int {
        if arguments.count > 3 {
            switch arguments[2] {
            case "-p", "--port":
                guard let portNumber = Int(arguments[3]) else {
                    break
                }
                return portNumber
            default:
                return 8000 // default portNumber
            }
        }
        return 8000 // default portNumber
    }

    private func resolveProjectKind(from arguments: [String]) -> ProjectKind {
        guard arguments.count > 2 else {
            return .website
        }

        return ProjectKind(rawValue: arguments[2]) ?? .website
    }

    private func optionValue(_ option: String) throws -> String? {
        guard let optionIndex = arguments.firstIndex(of: option) else {
            return nil
        }
        guard optionIndex < arguments.endIndex else {
            throw Error.invalidOptionUsage
        }
        let valueIndex = arguments.index(after: optionIndex)
        return arguments[valueIndex]
    }
}
