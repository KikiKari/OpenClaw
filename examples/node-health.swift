import Foundation

// OpenClaw Node Health Check (Swift)
func checkNode(_ urlString: String, timeout: TimeInterval = 5) -> String {
    guard let url = URL(string: urlString + "/health") else {
        return "FAIL \(urlString): invalid URL"
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout

    let semaphore = DispatchSemaphore(value: 0)
    var result = "FAIL \(urlString): no response"

    let task = URLSession.shared.dataTask(with: request) { _, response, error in
        if let error = error {
            result = "FAIL \(urlString): \(error.localizedDescription)"
        } else if let http = response as? HTTPURLResponse {
            result = "OK   \(urlString): \(http.statusCode)"
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    return result
}

let nodes = CommandLine.arguments.count > 1
    ? Array(CommandLine.arguments.dropFirst())
    : ["http://localhost:8080", "http://localhost:8081"]

for node in nodes {
    print(checkNode(node))
}
